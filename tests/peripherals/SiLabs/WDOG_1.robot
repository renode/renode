*** Settings ***
Test Setup                      Create Machine

*** Variables ***
# Clock the WDOG model uses internally. Matches the hard-coded default.
${WDOG_FREQUENCY}               32768
# WDOG configuration used by the tests:
#   PERSEL  = 15 -> timeout period = 2^(3 + 15) + 1 = 262145 cycles
#   WARNSEL = 3  -> warning at  75% of the timeout    = 196609 cycles
#   WINSEL  = 2  -> window  at  25% of the timeout    =  65537 cycles
${TIMEOUT_CYCLES}               262145
${WARNING_CYCLES}               196609
${WINDOW_CYCLES}                65537
# The energy-mode tests run an actual CPU, so they use a much shorter period to
# keep the amount of emulated virtual time (and executed instructions) small:
#   PERSEL  = 8 -> timeout period = 2^(3 + 8) + 1 = 2049 cycles
#   WARNSEL = 3 -> warning at 75% of the timeout  = 1537 cycles
${SLEEP_PERSEL}                 8
${SLEEP_TIMEOUT_CYCLES}         2049
${SLEEP_WARNING_CYCLES}         1537
# Cycles counted before the CPU is put to sleep. Chosen so that the remaining
# time to the warning threshold is still comfortably larger than the margins
# used when asserting that a frozen counter resumed instead of restarting.
${PRE_SLEEP_CYCLES}             500
${MARGIN_CYCLES}                200

# Register offsets (taken from SiLabs_WDOG_1.Generated.cs)
${IPVERSION}                    0x00
${EN}                           0x04
${CFG}                          0x08
${CMD}                          0x0C
${STATUS}                       0x14
${IF}                           0x18
${IEN}                          0x1C
${LOCK}                         0x20

# Bit positions of the IF/IEN register
${TOUT}                         0x1
${WARN}                         0x2
${WIN}                          0x4
# CFG fields
${EM1RUN}                       0x2
${EM2RUN}                       0x4

${PLATFORM}                     SEPARATOR=\n
...  """
...  code: Memory.MappedMemory @ sysbus 0x0
...  ${SPACE*4}size: 0x1000
...  wdog: Miscellaneous.SiLabs.SiLabs_WDOG_1 @ sysbus <0x4000, +0x4000>
...  ${SPACE*4}instance: 0
...  emu: Miscellaneous.SiLabs.SiLabs_EMU_3 @ sysbus <0x8000, +0x4000>
...  nvic: IRQControllers.NVIC @ sysbus 0xE000E000
...  cpu: CPU.CortexM @ sysbus
...  ${SPACE*4}nvic: nvic
...  ${SPACE*4}cpuType: "cortex-m33"
...  ${SPACE*4}cpuId: 0
...  """

*** Keywords ***
Create Machine
    Renode Test Setup
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${PLATFORM}
    # Code image used by the energy-mode tests. The vector table only needs the
    # initial stack pointer, the reset vector and the IRQ0 entry.
    # Vector entries have the Thumb bit set.
    Execute Command             sysbus WriteDoubleWord 0x0 0x1000
    Execute Command             sysbus WriteDoubleWord 0x4 0x101
    Execute Command             sysbus WriteDoubleWord 0x40 0x201
    Execute Command             cpu AssembleBlock 0x100 "wfi; b ."
    # A branch to itself, so the handler parks the CPU instead of running off the
    # end of the image.
    Execute Command             cpu AssembleBlock 0x200 "b .; b ."
    # IRQ0 is the only wake-up source these tests need. It is enabled up front
    # and pended by "Wake CPU" when the test wants to leave the energy mode.
    Execute Command             nvic WriteDoubleWord 0x100 0x1
    # Keep the CPU out of the way until the test asks for an energy mode, so it
    # cannot enter WFI while the watchdog is supposed to be counting.
    Execute Command             cpu IsHalted true
    Execute Command             logLevel 1 sysbus.wdog

# Configure CFG with the chosen PERSEL/WARNSEL/WINSEL and pre-set WDOGRSTDIS so
# a timeout does not actually request a machine reset (which would tear down the
# emulation state mid-test). Must be called before enabling the WDOG, since CFG
# is WSTATIC.
Configure WDOG
    [Arguments]                 ${persel}=15  ${flags}=0
    Execute Command             wdog WriteDoubleWord ${CFG} ${{ (${persel} << 16) | (3 << 24) | (2 << 28) | 0x100 | ${flags} }}

Start WDOG
    [Arguments]                 ${persel}=15  ${flags}=0
    Configure WDOG              ${persel}  ${flags}
    Execute Command             wdog WriteDoubleWord ${EN} 0x1

# RunFor a duration given in WDOG clock cycles. We format the time using a
# fixed-point decimal representation (without scientific notation), because
# Renode's TimeInterval parser does not understand strings like "5.1e-05" --
# it would treat the leading "5" as whole seconds, advancing the emulation by
# several seconds instead of microseconds.
Run For Cycles
    [Arguments]                 ${cycles}
    Execute Command             emulation RunFor "${{ '{:.12f}'.format(${cycles} / ${WDOG_FREQUENCY}) }}"

Flags Should Be
    [Arguments]                 ${expected}  ${mask}=0xFFFFFFFF
    ${flags}=                   Execute Command  wdog ReadDoubleWord ${IF}
    Should Be Equal As Integers  ${{ int($flags, 16) & ${mask} }}  ${expected}

Field Should Be
    [Arguments]                 ${register}  ${shift}  ${expected}
    ${value}=                   Execute Command  wdog ReadDoubleWord ${register}
    Should Be Equal As Integers  ${{ (int($value, 16) >> ${shift}) & 0x1 }}  ${expected}

Enabled Should Be
    [Arguments]                 ${expected}
    Field Should Be             ${EN}  0  ${expected}

Locked Should Be
    [Arguments]                 ${expected}
    Field Should Be             ${STATUS}  31  ${expected}

IRQ Should Be
    [Arguments]                 ${state}
    ${irq}=                     Execute Command  wdog IRQ
    Should Contain              ${irq}  GPIO: ${state}

# EM1 is a WFI with SLEEPDEEP clear, EM2 a WFI with SLEEPDEEP set. The CPU only
# reaches the "wfi" once the next "Run For Cycles" advances the emulation, and
# stays there for the rest of that window since nothing is pending yet.
Enter Energy Mode
    [Arguments]                 ${sleepDeep}
    Execute Command             nvic WriteDoubleWord 0xD10 ${{ 0x4 if ${sleepDeep} else 0x0 }}
    Execute Command             cpu PC 0x100
    Execute Command             cpu SP 0x1000
    Execute Command             cpu IsHalted false

# Pending IRQ0 takes the CPU out of WFI on the next run, which is what the EMU
# reports as leaving the energy mode.
Wake CPU
    Execute Command             nvic WriteDoubleWord 0x200 0x1

Frozen Counter Should Resume After Wake-Up
    [Arguments]                 ${sleepDeep}  ${flags}
    Start WDOG                  ${SLEEP_PERSEL}  ${flags}
    Run For Cycles              ${PRE_SLEEP_CYCLES}
    Enter Energy Mode           ${sleepDeep}
    # A watchdog still counting would time out within this window.
    Run For Cycles              ${SLEEP_TIMEOUT_CYCLES}
    Flags Should Be             0x0
    Wake CPU
    # Counting resumes from the pre-sleep count instead of restarting, so the
    # warning threshold is just out of reach of this window ...
    Run For Cycles              ${{ ${SLEEP_WARNING_CYCLES} - ${PRE_SLEEP_CYCLES} - ${MARGIN_CYCLES} }}
    Flags Should Be             0x0
    # ... and reached shortly after.
    Run For Cycles              ${{ 2 * ${MARGIN_CYCLES} }}
    Flags Should Be             ${WARN}  mask=${WARN}

Running Counter Should Time Out In Energy Mode
    [Arguments]                 ${sleepDeep}  ${flags}
    Start WDOG                  ${SLEEP_PERSEL}  ${flags}
    Enter Energy Mode           ${sleepDeep}
    Run For Cycles              ${{ ${SLEEP_TIMEOUT_CYCLES} + ${MARGIN_CYCLES} }}
    Flags Should Be             ${TOUT}  mask=${TOUT}

*** Test Cases ***
Should Have Correct Reset State
    IRQ Should Be               unset
    Enabled Should Be           0
    Locked Should Be            0
    # IPVERSION is read-only and resets to 0x1
    ${version}=                 Execute Command  wdog ReadDoubleWord ${IPVERSION}
    Should Be Equal As Integers  ${version}  0x1
    # IF should be zero after reset
    Flags Should Be             0x0

Should Enable And Disable
    Configure WDOG
    Enabled Should Be           0
    Execute Command             wdog WriteDoubleWord ${EN} 0x1
    Enabled Should Be           1
    # No interrupts should fire just by enabling
    IRQ Should Be               unset
    Execute Command             wdog WriteDoubleWord ${EN} 0x0
    Enabled Should Be           0
    IRQ Should Be               unset

Should Fire Timeout Interrupt
    Execute Command             wdog WriteDoubleWord ${IEN} 0x1F
    Start WDOG
    # Run for a bit less than the timeout: nothing should have fired yet beyond
    # the warning interrupt.
    Run For Cycles              ${{ ${TIMEOUT_CYCLES} - 1000 }}
    Flags Should Be             0x0  mask=${TOUT}
    # Now cross the timeout boundary.
    Run For Cycles              2000
    Flags Should Be             ${TOUT}  mask=${TOUT}
    IRQ Should Be               set

Should Fire Warning Before Timeout
    Execute Command             wdog WriteDoubleWord ${IEN} 0x1F
    Start WDOG
    # Run for slightly less than the warning threshold; no flags should be set.
    Run For Cycles              ${{ ${WARNING_CYCLES} - 1000 }}
    Flags Should Be             0x0
    IRQ Should Be               unset
    # Cross the warning threshold without reaching the timeout.
    Run For Cycles              2000
    Flags Should Be             ${WARN}  mask=${{ ${WARN} | ${TOUT} }}
    IRQ Should Be               set

Should Restart Counter On Clear
    Execute Command             wdog WriteDoubleWord ${IEN} 0x1F
    Start WDOG
    # Advance most of the way to the timeout, then clear -- the counter should
    # restart from 0 and no TOUT/WARN flags should remain set.
    Run For Cycles              ${{ ${TIMEOUT_CYCLES} - 1000 }}
    # The warning has already fired by now, so clear the IF first.
    Execute Command             wdog WriteDoubleWord ${IF} 0x0
    Execute Command             wdog WriteDoubleWord ${CMD} 0x1
    IRQ Should Be               unset
    # After clearing, an additional run of less-than-timeout cycles must not
    # trigger TOUT.
    Run For Cycles              ${{ ${TIMEOUT_CYCLES} - 1000 }}
    Flags Should Be             0x0  mask=${TOUT}

Should Flag Clear Before Window
    Execute Command             wdog WriteDoubleWord ${IEN} 0x1F
    Start WDOG
    # Clear well before the window threshold: WIN should be flagged.
    Run For Cycles              ${{ ${WINDOW_CYCLES} - 1000 }}
    Execute Command             wdog WriteDoubleWord ${CMD} 0x1
    Flags Should Be             ${WIN}  mask=${WIN}
    IRQ Should Be               set

Should Not Flag Clear After Window
    Execute Command             wdog WriteDoubleWord ${IEN} 0x1F
    Start WDOG
    # Clear just past the window threshold: WIN must NOT be flagged.
    Run For Cycles              ${{ ${WINDOW_CYCLES} + 1000 }}
    Execute Command             wdog WriteDoubleWord ${CMD} 0x1
    Flags Should Be             0x0  mask=${WIN}

Should Clear Flags On Disable
    Execute Command             wdog WriteDoubleWord ${IEN} 0x1F
    Start WDOG
    # Run past the warning threshold to set IF.WARN.
    Run For Cycles              ${WARNING_CYCLES}
    Run For Cycles              1000
    Flags Should Be             ${WARN}  mask=${WARN}
    # Disabling the WDOG must clear pending interrupt flags.
    Execute Command             wdog WriteDoubleWord ${EN} 0x0
    Flags Should Be             0x0
    IRQ Should Be               unset

Should Gate IRQ With Interrupt Enable
    # Do NOT enable any interrupts in IEN; the IF should still latch but the
    # IRQ line must remain low.
    Start WDOG
    Run For Cycles              ${TIMEOUT_CYCLES}
    Run For Cycles              2000
    Flags Should Be             ${TOUT}  mask=${TOUT}
    IRQ Should Be               unset
    # Now enable the TOUT interrupt and verify the IRQ line is asserted.
    Execute Command             wdog WriteDoubleWord ${IEN} ${TOUT}
    IRQ Should Be               set

Should Ignore Enable While Locked
    Configure WDOG
    Locked Should Be            0
    Execute Command             wdog WriteDoubleWord ${LOCK} 0x0
    Locked Should Be            1
    # Writes to EN must be ignored while the WDOG is locked.
    Execute Command             wdog WriteDoubleWord ${EN} 0x1
    Enabled Should Be           0
    # Unlock and verify the WDOG can be enabled again.
    Execute Command             wdog WriteDoubleWord ${LOCK} 0xABE8
    Locked Should Be            0
    Execute Command             wdog WriteDoubleWord ${EN} 0x1
    Enabled Should Be           1

Should Clear Flags Through Clear Alias
    Execute Command             wdog WriteDoubleWord ${IEN} 0x1F
    Start WDOG
    Run For Cycles              ${TIMEOUT_CYCLES}
    Run For Cycles              2000
    ${flags}=                   Execute Command  wdog ReadDoubleWord ${IF}
    Should Not Be Equal As Integers  ${flags}  0x0
    IRQ Should Be               set
    # The CLR alias at +0x2000 should clear any bits written as 1.
    Execute Command             wdog WriteDoubleWord ${{ ${IF} + 0x2000 }} 0xFFFFFFFF
    Flags Should Be             0x0
    IRQ Should Be               unset

# Setting the other mode's RUN bit instead also shows the two controls act
# independently.
Should Freeze In EM1 Without EM1RUN
    Frozen Counter Should Resume After Wake-Up      sleepDeep=False  flags=${EM2RUN}

Should Run In EM1 With EM1RUN
    Running Counter Should Time Out In Energy Mode  sleepDeep=False  flags=${EM1RUN}

Should Freeze In EM2 Without EM2RUN
    Frozen Counter Should Resume After Wake-Up      sleepDeep=True   flags=${EM1RUN}

Should Run In EM2 With EM2RUN
    Running Counter Should Time Out In Energy Mode  sleepDeep=True   flags=${EM2RUN}
