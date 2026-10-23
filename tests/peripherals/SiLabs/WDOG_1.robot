*** Variables ***
# Clock the WDOG model uses internally. Matches the hard-coded default.
${WDOG_FREQ}                    32768
# WDOG configuration used by the tests:
#   PERSEL  = 15 -> timeout period = 2^(3 + 15) + 1 = 262145 cycles
#   WARNSEL = 3  -> warning at  75% of the timeout    = 196609 cycles
#   WINSEL  = 2  -> window  at  25% of the timeout    =  65537 cycles
${PERSEL}                       15
${WARN_SEL}                     3
${WIN_SEL}                      2
${TIMEOUT_CYCLES}               262145
${WARN_CYCLES}                  196609
${WIN_CYCLES}                   65537
# The energy-mode tests run an actual CPU, so they use a much shorter period to
# keep the amount of emulated virtual time (and executed instructions) small:
#   PERSEL  = 8 -> timeout period = 2^(3 + 8) + 1 = 2049 cycles
#   WARNSEL = 3 -> warning at 75% of the timeout  = 1537 cycles
${SLEEP_PERSEL}                 8
${SLEEP_TIMEOUT_CYCLES}         2049
${SLEEP_WARN_CYCLES}            1537
# Cycles counted before the CPU is put to sleep. Chosen so that the remaining
# time to the warning threshold is still comfortably larger than the margins
# used when asserting that a frozen counter resumed instead of restarting.
${PRE_SLEEP_CYCLES}             500
${MARGIN_CYCLES}                200

${REPL_STRING}=                 SEPARATOR=
...  """                                                               ${\n}
...  wdog: Miscellaneous.SiLabs.SiLabs_WDOG_1 @ sysbus <0x0, +0x4000>  ${\n}
...  ${SPACE*4}instance: 0                                             ${\n}
...  """

${SLEEP_REPL_STRING}=           SEPARATOR=
...  """                                                                           ${\n}
...  code: Memory.MappedMemory @ sysbus 0x0                                        ${\n}
...  ${SPACE*4}size: 0x1000                                                        ${\n}
...  wdog: Miscellaneous.SiLabs.SiLabs_WDOG_1 @ sysbus <0x4000, +0x4000>           ${\n}
...  ${SPACE*4}instance: 0                                                         ${\n}
...  emu: Miscellaneous.SiLabs.SiLabs_EMU_3 @ sysbus <0x8000, +0x4000>             ${\n}
...  nvic: IRQControllers.NVIC @ sysbus 0xE000E000                                 ${\n}
...  cpu: CPU.CortexM @ sysbus                                                     ${\n}
...  ${SPACE*4}nvic: nvic                                                          ${\n}
...  ${SPACE*4}cpuType: "cortex-m33"                                               ${\n}
...  ${SPACE*4}cpuId: 0                                                            ${\n}
...  """

# Register offsets (taken from SiLabs_WDOG_1.Generated.cs)
${IPVERSION_REG}                0x00
${EN_REG}                       0x04
${CFG_REG}                      0x08
${CMD_REG}                      0x0C
${STATUS_REG}                   0x14
${IF_REG}                       0x18
${IEN_REG}                      0x1C
${LOCK_REG}                     0x20
${SYNCBUSY_REG}                 0x24

# Bit positions of the IF/IEN register
${IF_TOUT_BIT}                  0x01
${IF_WARN_BIT}                  0x02
${IF_WIN_BIT}                   0x04

# CFG fields
${CFG_EM1RUN_BIT}               0x2
${CFG_EM2RUN_BIT}               0x4
${CFG_WDOGRSTDIS_BIT}           0x100

# NVIC registers
${NVIC_ISER_REG}                0x100
${NVIC_ISPR_REG}                0x200
${SCR_REG}                      0xD10
${SCR_SLEEPDEEP_BIT}            0x4

# Code image used by the energy-mode tests. The vector table only needs the
# initial stack pointer, the reset vector and the IRQ0 entry.
${STACK_TOP}                    0x1000
${SLEEP_CODE_ADDR}              0x100
${IRQ0_HANDLER_ADDR}            0x200
# Vector entries have the Thumb bit set.
${SLEEP_CODE_VECTOR}            0x101
${IRQ0_HANDLER_VECTOR}          0x201
# "wfi" (0xBF30) followed by a branch to itself (0xE7FE), little endian.
${SLEEP_CODE}                   0xE7FEBF30
# A branch to itself, so the handler parks the CPU instead of running off the
# end of the image.
${IRQ0_HANDLER_CODE}            0xE7FEE7FE

# LOCK keys
${LOCK_UNLOCK_KEY}              0xABE8
${LOCK_LOCK_KEY}                0x0000

*** Keywords ***
Create Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL_STRING}
    Execute Command             logLevel 1 sysbus.wdog

Create Sleep Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${SLEEP_REPL_STRING}
    Execute Command             sysbus WriteDoubleWord 0x0 ${STACK_TOP}
    Execute Command             sysbus WriteDoubleWord 0x4 ${SLEEP_CODE_VECTOR}
    Execute Command             sysbus WriteDoubleWord 0x40 ${IRQ0_HANDLER_VECTOR}
    Execute Command             sysbus WriteDoubleWord ${SLEEP_CODE_ADDR} ${SLEEP_CODE}
    Execute Command             sysbus WriteDoubleWord ${IRQ0_HANDLER_ADDR} ${IRQ0_HANDLER_CODE}
    # IRQ0 is the only wake-up source these tests need. It is enabled up front
    # and pended by "Wake CPU" when the test wants to leave the energy mode.
    Execute Command             sysbus.nvic WriteDoubleWord ${NVIC_ISER_REG} 0x1
    # Keep the CPU out of the way until the test asks for an energy mode, so it
    # cannot enter WFI while the watchdog is supposed to be counting.
    Execute Command             cpu IsHalted true
    Execute Command             logLevel 1 sysbus.wdog

Write WDOG Register
    [Arguments]                 ${offset}  ${value}
    Execute Command             sysbus.wdog WriteDoubleWord ${offset} ${value}

Read WDOG Register
    [Arguments]                 ${offset}
    ${val}=                     Execute Command  sysbus.wdog ReadDoubleWord ${offset}
    ${val}=                     Convert To Integer  ${val}
    RETURN                      ${val}

# Configure CFG with the chosen PERSEL/WARNSEL/WINSEL and pre-set WDOGRSTDIS so
# a timeout does not actually request a machine reset (which would tear down the
# emulation state mid-test). Must be called before enabling the WDOG, since CFG
# is WSTATIC.
Configure WDOG
    [Arguments]                 ${disable_reset}=True  ${cfg_flags}=0  ${persel}=${PERSEL}
    ${cfg}=                     Evaluate  (${persel} << 16) | (${WARN_SEL} << 24) | (${WIN_SEL} << 28)
    IF  ${disable_reset}
        ${cfg}=                 Evaluate  ${cfg} | ${CFG_WDOGRSTDIS_BIT}
    END
    ${cfg}=                     Evaluate  ${cfg} | ${cfg_flags}
    Write WDOG Register         ${CFG_REG}  ${cfg}

Enable WDOG
    Write WDOG Register         ${EN_REG}  0x1

Disable WDOG
    Write WDOG Register         ${EN_REG}  0x0

Clear WDOG
    Write WDOG Register         ${CMD_REG}  0x1

Enable All Interrupts
    Write WDOG Register         ${IEN_REG}  0x1F

Clear All Interrupt Flags
    Write WDOG Register         ${IF_REG}  0x0

Lock WDOG
    Write WDOG Register         ${LOCK_REG}  ${LOCK_LOCK_KEY}

Unlock WDOG
    Write WDOG Register         ${LOCK_REG}  ${LOCK_UNLOCK_KEY}

Assert IRQ Is Set
    ${irqState}=                Execute Command  sysbus.wdog IRQ
    Should Contain              ${irqState}  GPIO: set

Assert IRQ Is Unset
    ${irqState}=                Execute Command  sysbus.wdog IRQ
    Should Contain              ${irqState}  GPIO: unset

Assert IF Equals
    [Arguments]                 ${expected}
    ${val}=                     Read WDOG Register  ${IF_REG}
    Should Be Equal As Integers  ${val}  ${expected}

Assert IF Bit Set
    [Arguments]                 ${bit}
    ${val}=                     Read WDOG Register  ${IF_REG}
    ${masked}=                  Evaluate  ${val} & ${bit}
    Should Be Equal As Integers  ${masked}  ${bit}

Assert WDOG Enabled
    [Arguments]                 ${enabled}
    ${val}=                     Read WDOG Register  ${EN_REG}
    ${en_bit}=                  Evaluate  ${val} & 0x1
    IF  ${enabled}
        Should Be Equal As Integers  ${en_bit}  0x1
    ELSE
        Should Be Equal As Integers  ${en_bit}  0x0
    END

Assert WDOG Locked
    [Arguments]                 ${locked}
    ${val}=                     Read WDOG Register  ${STATUS_REG}
    ${lock_bit}=                Evaluate  (${val} >> 31) & 0x1
    IF  ${locked}
        Should Be Equal As Integers  ${lock_bit}  0x1
    ELSE
        Should Be Equal As Integers  ${lock_bit}  0x0
    END

# RunFor a duration given in WDOG clock cycles. We format the time using a
# fixed-point decimal representation (without scientific notation), because
# Renode's TimeInterval parser does not understand strings like "5.1e-05" --
# it would treat the leading "5" as whole seconds, advancing the emulation by
# several seconds instead of microseconds.
Run For Cycles
    [Arguments]                 ${cycles}
    ${seconds}=                 Evaluate  "{:.12f}".format(float(${cycles}) / float(${WDOG_FREQ}))
    Execute Command             emulation RunFor "${seconds}"

# EM1 is a WFI with SLEEPDEEP clear, EM2 a WFI with SLEEPDEEP set. The CPU only
# reaches the "wfi" once the next "Run For Cycles" advances the emulation, and
# stays there for the rest of that window since nothing is pending yet.
Enter EM1
    Execute Command             sysbus.nvic WriteDoubleWord ${SCR_REG} 0x0
    Release CPU

Enter EM2
    Execute Command             sysbus.nvic WriteDoubleWord ${SCR_REG} ${SCR_SLEEPDEEP_BIT}
    Release CPU

Release CPU
    Execute Command             cpu PC ${SLEEP_CODE_ADDR}
    Execute Command             cpu SP ${STACK_TOP}
    Execute Command             cpu IsHalted false

# Pending IRQ0 takes the CPU out of WFI on the next run, which is what the EMU
# reports as leaving the energy mode.
Wake CPU
    Execute Command             sysbus.nvic WriteDoubleWord ${NVIC_ISPR_REG} 0x1

*** Test Cases ***
Reset State
    Create Machine
    Assert IRQ Is Unset
    Assert WDOG Enabled         False
    Assert WDOG Locked          False
    # IPVERSION is read-only and resets to 0x1
    ${ipv}=                     Read WDOG Register  ${IPVERSION_REG}
    Should Be Equal As Integers  ${ipv}  0x1
    # IF should be zero after reset
    Assert IF Equals            0x0

Enable And Disable WDOG
    Create Machine
    Configure WDOG
    Assert WDOG Enabled         False
    Enable WDOG
    Assert WDOG Enabled         True
    # No interrupts should fire just by enabling
    Assert IRQ Is Unset
    Disable WDOG
    Assert WDOG Enabled         False
    Assert IRQ Is Unset

Timeout Fires Interrupt
    Create Machine
    Configure WDOG
    Enable All Interrupts
    Enable WDOG
    # Run for a bit less than the timeout: nothing should have fired yet beyond
    # the warning interrupt.
    ${before_timeout}=          Evaluate  ${TIMEOUT_CYCLES} - 1000
    Run For Cycles              ${before_timeout}
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    ${tout}=                    Evaluate  ${if_val} & ${IF_TOUT_BIT}
    Should Be Equal As Integers  ${tout}  0x0
    # Now cross the timeout boundary.
    Run For Cycles              2000
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    ${tout}=                    Evaluate  ${if_val} & ${IF_TOUT_BIT}
    Should Be Equal As Integers  ${tout}  ${IF_TOUT_BIT}
    Assert IRQ Is Set

Warning Fires Before Timeout
    Create Machine
    Configure WDOG
    Enable All Interrupts
    Enable WDOG
    # Run for slightly less than the warning threshold; no flags should be set.
    ${before_warn}=             Evaluate  ${WARN_CYCLES} - 1000
    Run For Cycles              ${before_warn}
    Assert IF Equals            0x0
    Assert IRQ Is Unset
    # Cross the warning threshold without reaching the timeout.
    Run For Cycles              2000
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    ${warn}=                    Evaluate  ${if_val} & ${IF_WARN_BIT}
    Should Be Equal As Integers  ${warn}  ${IF_WARN_BIT}
    ${tout}=                    Evaluate  ${if_val} & ${IF_TOUT_BIT}
    Should Be Equal As Integers  ${tout}  0x0
    Assert IRQ Is Set

Clear Command Prevents Timeout
    Create Machine
    Configure WDOG
    Enable All Interrupts
    Enable WDOG
    # Advance most of the way to the timeout, then clear -- the counter should
    # restart from 0 and no TOUT/WARN flags should remain set.
    ${almost_timeout}=          Evaluate  ${TIMEOUT_CYCLES} - 1000
    Run For Cycles              ${almost_timeout}
    # The warning has already fired by now, so clear the IF first.
    Clear All Interrupt Flags
    Clear WDOG
    Assert IRQ Is Unset
    # After clearing, an additional run of less-than-timeout cycles must not
    # trigger TOUT.
    Run For Cycles              ${almost_timeout}
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    ${tout}=                    Evaluate  ${if_val} & ${IF_TOUT_BIT}
    Should Be Equal As Integers  ${tout}  0x0

Window Violation Sets WIN Flag
    Create Machine
    Configure WDOG
    Enable All Interrupts
    Enable WDOG
    # Clear well before the window threshold: WIN should be flagged.
    ${below_window}=            Evaluate  ${WIN_CYCLES} - 1000
    Run For Cycles              ${below_window}
    Clear WDOG
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    ${win}=                     Evaluate  ${if_val} & ${IF_WIN_BIT}
    Should Be Equal As Integers  ${win}  ${IF_WIN_BIT}
    Assert IRQ Is Set

Window Not Violated When Cleared Past Threshold
    Create Machine
    Configure WDOG
    Enable All Interrupts
    Enable WDOG
    # Clear just past the window threshold: WIN must NOT be flagged.
    ${past_window}=             Evaluate  ${WIN_CYCLES} + 1000
    Run For Cycles              ${past_window}
    Clear WDOG
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    ${win}=                     Evaluate  ${if_val} & ${IF_WIN_BIT}
    Should Be Equal As Integers  ${win}  0x0

Disable Clears Pending Interrupts
    Create Machine
    Configure WDOG
    Enable All Interrupts
    Enable WDOG
    # Run past the warning threshold to set IF.WARN.
    Run For Cycles              ${WARN_CYCLES}
    Run For Cycles              1000
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    ${warn}=                    Evaluate  ${if_val} & ${IF_WARN_BIT}
    Should Be Equal As Integers  ${warn}  ${IF_WARN_BIT}
    # Disabling the WDOG must clear pending interrupt flags.
    Disable WDOG
    Assert IF Equals            0x0
    Assert IRQ Is Unset

Interrupt Enable Mask Gates IRQ
    Create Machine
    Configure WDOG
    # Do NOT enable any interrupts in IEN; the IF should still latch but the
    # IRQ line must remain low.
    Enable WDOG
    Run For Cycles              ${TIMEOUT_CYCLES}
    Run For Cycles              2000
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    ${tout}=                    Evaluate  ${if_val} & ${IF_TOUT_BIT}
    Should Be Equal As Integers  ${tout}  ${IF_TOUT_BIT}
    Assert IRQ Is Unset
    # Now enable the TOUT interrupt and verify the IRQ line is asserted.
    Write WDOG Register         ${IEN_REG}  ${IF_TOUT_BIT}
    Assert IRQ Is Set

Lock Prevents Writes To EN
    Create Machine
    Configure WDOG
    Assert WDOG Locked          False
    Lock WDOG
    Assert WDOG Locked          True
    # Writes to EN must be ignored while the WDOG is locked.
    Enable WDOG
    Assert WDOG Enabled         False
    # Unlock and verify the WDOG can be enabled again.
    Unlock WDOG
    Assert WDOG Locked          False
    Enable WDOG
    Assert WDOG Enabled         True

Write One To Clear Alias Clears IF
    Create Machine
    Configure WDOG
    Enable All Interrupts
    Enable WDOG
    Run For Cycles              ${TIMEOUT_CYCLES}
    Run For Cycles              2000
    ${if_val}=                  Read WDOG Register  ${IF_REG}
    Should Not Be Equal As Integers  ${if_val}  0x0
    Assert IRQ Is Set
    # The Set/Clr/Tgl alias at +0x2000 should clear any bits written as 1.
    ${if_clr_addr}=             Evaluate  ${IF_REG} + 0x2000
    Write WDOG Register         ${if_clr_addr}  0xFFFFFFFF
    Assert IF Equals            0x0
    Assert IRQ Is Unset

EM1RUN Disabled Freezes Watchdog And Preserves Counter
    Create Sleep Machine
    # Setting EM2RUN instead of EM1RUN also shows the two controls act
    # independently.
    Configure WDOG              cfg_flags=${CFG_EM2RUN_BIT}  persel=${SLEEP_PERSEL}
    Enable WDOG
    Run For Cycles              ${PRE_SLEEP_CYCLES}
    Enter EM1
    # A watchdog still counting would time out within this window.
    Run For Cycles              ${SLEEP_TIMEOUT_CYCLES}
    Assert IF Equals            0x0
    Wake CPU
    # Counting resumes from the pre-sleep count instead of restarting, so the
    # warning threshold is just out of reach of this window ...
    ${before_warn}=             Evaluate  ${SLEEP_WARN_CYCLES} - ${PRE_SLEEP_CYCLES} - ${MARGIN_CYCLES}
    Run For Cycles              ${before_warn}
    Assert IF Equals            0x0
    # ... and reached shortly after.
    ${past_warn}=               Evaluate  2 * ${MARGIN_CYCLES}
    Run For Cycles              ${past_warn}
    Assert IF Bit Set           ${IF_WARN_BIT}

EM1RUN Enabled Keeps Watchdog Running
    Create Sleep Machine
    Configure WDOG              cfg_flags=${CFG_EM1RUN_BIT}  persel=${SLEEP_PERSEL}
    Enable WDOG
    Enter EM1
    ${past_timeout}=            Evaluate  ${SLEEP_TIMEOUT_CYCLES} + ${MARGIN_CYCLES}
    Run For Cycles              ${past_timeout}
    Assert IF Bit Set           ${IF_TOUT_BIT}

EM2RUN Disabled Freezes Watchdog And Preserves Counter
    Create Sleep Machine
    # Setting EM1RUN instead of EM2RUN also shows the two controls act
    # independently.
    Configure WDOG              cfg_flags=${CFG_EM1RUN_BIT}  persel=${SLEEP_PERSEL}
    Enable WDOG
    Run For Cycles              ${PRE_SLEEP_CYCLES}
    Enter EM2
    Run For Cycles              ${SLEEP_TIMEOUT_CYCLES}
    Assert IF Equals            0x0
    Wake CPU
    ${before_warn}=             Evaluate  ${SLEEP_WARN_CYCLES} - ${PRE_SLEEP_CYCLES} - ${MARGIN_CYCLES}
    Run For Cycles              ${before_warn}
    Assert IF Equals            0x0
    ${past_warn}=               Evaluate  2 * ${MARGIN_CYCLES}
    Run For Cycles              ${past_warn}
    Assert IF Bit Set           ${IF_WARN_BIT}

EM2RUN Enabled Keeps Watchdog Running
    Create Sleep Machine
    Configure WDOG              cfg_flags=${CFG_EM2RUN_BIT}  persel=${SLEEP_PERSEL}
    Enable WDOG
    Enter EM2
    ${past_timeout}=            Evaluate  ${SLEEP_TIMEOUT_CYCLES} + ${MARGIN_CYCLES}
    Run For Cycles              ${past_timeout}
    Assert IF Bit Set           ${IF_TOUT_BIT}
