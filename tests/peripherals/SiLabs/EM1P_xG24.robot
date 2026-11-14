*** Comments ***
EM1P coverage for the xG24 EMU and its radio sequencer. The xG26 shares the same models
and register map, so every test runs on both: each test is a template with one row per
platform.

EM1P is the energy mode where the host is in deep sleep but an EM1P requester keeps the
PD1 domain powered. On xG24 the requester is the radio: RAC EM1PCSR reports a request while
the sequencer is running, or while software has taken EM1P control, and the request drops
once the sequencer is in WFI with the radio state machine idle. The sequencer's own WFI
must not select the system energy mode, because that core sleeps with SLEEPDEEP clear.
EM2 shuts the sequencer down: it is held in CPUWAIT and reset, and it stays there until
software sets CPUWAITDIS again.

Host clocks are two gates. The Host EM1P domain (bus, LDMA, GPIO, EUSART0, ...) runs in EM0
and EM1, stops in EM2 with PD1, and in EM1P stops unless RAC EM1PCSR.MCUEM1PMODE is in
software control with MCUEM1PDISSWREQ clear. The HostAll domain is the whole HCLK tree and
holds the general-purpose timers, USART and SysTick. It runs in EM0 and EM1 only, so those
stay stopped in EM1P even when MCUEM1PMODE turns the Host EM1P domain on.
The watchdog has no EM1P run bit: in EM1P it follows EM2RUN, the same as in EM2.

Besides the radio, EUSART0 is an EM1P requester. With RXDMAWU set it asks for EM1P, and
for the bus clock, while received frames are waiting. With TXDMAWU set it asks while the
transmitter is enabled, and drops that request on TXDIS, CLEARTX or when EN is cleared. The LDMA is a bus master on the Host EM1P domain: it
holds a request while that domain is gated and runs it once the clocks start.

The host executes a real "wfi" out of SRAM. IRQ0 is enabled up front and pended to leave
the energy mode; its handler is a short counting loop so the core stays awake there
instead of running off the end of the image. A branch to itself is not usable for that,
because this CPU model reports one as WFI.

*** Variables ***
${XG24_PLATFORM}                platforms/boards/silabs/brd4186c.repl
${XG26_PLATFORM}                platforms/boards/silabs/brd4116a.repl

${EMU_STATUS}                   0x40004084
${EMU_STATUS_EM1P}              0x800

${RAC_CTRL}                     0xA8020014
${RAC_EM1PCSR}                  0xA8020060
${RAC_CPUWAITDIS}               0x04000000
${RAC_EM1P_SWCTRL}              0x1
${RAC_EM1P_MCU_SWCTRL}          0x10
${RAC_EM1P_MCU_DISSWREQ}        0x20
${RAC_EM1P_REQ}                 0x10000
${RAC_EM1P_ACK}                 0x20000
${RAC_EM1P_HWREQ}               0x40000

${NVIC_ISER}                    0x100
${NVIC_ISPR}                    0x200
${NVIC_SCR}                     0xD10
${SCR_SLEEPDEEP}                0x4

# Host image in SRAM. The vector table needs the stack pointer, the reset vector and IRQ0.
${HOST_STACK}                   0x20010000
${HOST_CODE}                    0x20000100
${HOST_IRQ0}                    0x20000200
# The CPU model reports a branch-to-self as WFI, so an idle loop has to do some
# work or leaving WFI puts the core straight back to sleep.
# Issued a PR to fix it: https://github.com/antmicro/tlib/pull/69
${SPIN_LOOP}                    movs r1, #1; 1: subs r0, #1; b 1b

# Sequencer image in sequencer RAM. CPUWAITDIS loads SP and PC from this vector table.
${SEQ_RAM}                      0xB0000000
${SEQ_STACK}                    0xB0003F00
${SEQ_SPIN}                     0xB0000100
${SEQ_SLEEP}                    0xB0000200

# Short enough to stay cheap, long enough for both cores to be scheduled.
${RUN_TIME}                     0.0001
${QUANTUM}                      0.00001

# WDOG0. PERSEL=3 is a 65-cycle timeout, about 2 ms at the 32768 Hz LFRCO the
# reset clock select uses. 0.004 s is past that timeout. The EM2RUN-clear configuration
# sets EM1RUN instead, so the result shows that EM1P follows EM2RUN, not EM1RUN. WDOGRSTDIS stops
# the timeout from resetting the machine before the flag can be checked.
${WDOG0_EN}                     0x4
${WDOG0_CFG}                    0x8
${WDOG0_IF}                     0x18
${WDOG_CFG_EM1RUN}              0x00030102
${WDOG_CFG_EM2RUN}              0x00030104
${WDOG_PAST_TIMEOUT}            0.004

# TIMER0 counts at the core clock, so it advances visibly within one RUN_TIME without wrapping.
${TIMER0_CMD}                   0xC
${TIMER0_CNT}                   0x24
${TIMER0_EN}                    0x30

# USART0 time compare counter, which runs at the baud rate. CLKDIV 0x1770 (DIV 750, a divisor of 1 + 6000/256) gives about 100 kbaud
# from the 39 MHz clock, so 255 bit times take roughly 2.6 ms. The counter starts at the end
# of the first transmitted frame.
${USART0_ENABLE}                0x4
${USART0_CMD}                   0x14
${USART0_CLKCTRL}               0x1C
${USART0_TXDATA}                0x3C
${USART0_IF}                    0x48
${USART0_TIMECMP0}              0x60
${USART_CMD_TXEN}               0x4
${USART_CLKCTRL_DIV_6000}       0x1770
${USART_TIMECMP0_TXEOF_255}     0x000100FF
${USART_IF_TCMP0}               0x4000
${USART_PAST_COMPARE}           0.004

# EUSART0, the EM2 capable instance. RXDMAWU and TXDMAWU are in CFG1, and RXFIW sets how many
# received frames raise the DMA request (RXFIW + 1).
${EUSART0_ENABLE}               0x4
${EUSART0_CFG1}                 0xC
${EUSART0_CMD}                  0x38
${EUSART0_RXDATA}               0x3C
${EUSART0_RXDATA_ADDRESS}       0x4B01003C
${EUSART_CMD_RXEN}              0x1
${EUSART_CMD_TXEN}              0x4
${EUSART_CMD_TXDIS}             0x8
${EUSART_CMD_CLEARTX}           0x100
${EUSART_CFG1_TXDMAWU}          0x200
${EUSART_CFG1_RXDMAWU}          0x400
${EUSART_CFG1_RXDMAWU_RXFIW_1}  0x08000400
${EUSART_FRAME}                 0x41

# LDMA channel 0. REQSEL picks EUSART0 (source 0xF) receive FIFO level (signal 0). The
# descriptor control words are: one word with both addresses incrementing, and one byte
# from a fixed source into an incrementing destination. Both use REQMODE ALL and DONEIEN.
${LDMA_BASE}                    0x40040000
${LDMAXBAR_BASE}                0x40044000
${LDMA_CHEN}                    0x24
${LDMA_SWREQ}                   0x3C
${LDMA_IF}                      0x50
${LDMA_IEN}                     0x54
${LDMA_CH0_CTRL}                0x64
${LDMA_CH0_SRC}                 0x68
${LDMA_CH0_DST}                 0x6C
${LDMAXBAR_CH0_REQSEL}          0x4
${LDMA_REQSEL_EUSART0_RXFL}     0x000F0000
${LDMA_CTRL_WORD_COPY}          0x08300000
${LDMA_CTRL_BYTE_FROM_FIXED}    0x03300000
${LDMA_SOURCE}                  0x20002000
${LDMA_TARGET}                  0x20002100
${LDMA_PATTERN}                 0xA5A5A5A5

# SysTick counts 1000000 core clocks, 25.6 ms at 39 MHz. COUNTFLAG is cleared by reading CSR.
${SYST_CSR}                     0x10
${SYST_RVR}                     0x14
${SYST_CVR}                     0x18
${SYST_CSR_ENABLE_CORECLK}      0x5
${SYST_CSR_COUNTFLAG}           0x10000
${SYST_RELOAD}                  1000000
${SYST_PAST_RELOAD}             0.04

*** Keywords ***
Create Machine
    [Arguments]                 ${platform}
    # Each test runs its template once per platform, so start every row from scratch.
    Reset Emulation
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescription @${platform}
    Execute Command             emulation SetQuantum "${QUANTUM}"
    # Run the host core and the radio sequencer in a fixed order within each quantum
    Execute Command             emulation SetGlobalSerialExecution true
    Execute Command             sysbus.cpu IsHalted true
    Execute Command             sysbus.cpu VectorTableOffset 0x20000000
    Execute Command             sysbus WriteDoubleWord 0x20000000 ${HOST_STACK}
    Execute Command             sysbus WriteDoubleWord 0x20000004 ${{${HOST_CODE} | 1}}
    Execute Command             sysbus WriteDoubleWord 0x20000040 ${{${HOST_IRQ0} | 1}}
    # "wfi" followed by the same loop, so the core sleeps on the wfi and stays awake
    # if it is resumed past it.
    Execute Command             cpu AssembleBlock ${HOST_CODE} "wfi; ${SPIN_LOOP}"
    Execute Command             cpu AssembleBlock ${HOST_IRQ0} "${SPIN_LOOP}"
    Execute Command             sysbus.nvic WriteDoubleWord ${NVIC_ISER} 0x1
    # The radio connects to the EMU from the EM1PCSR write callback, and that callback
    # only runs when the value changes. Toggle the software request so the host WFI
    # hook is installed, then leave the request clear.
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Write EM1PCSR               0x0

Enter Host Sleep
    [Arguments]                 ${deep}
    Execute Command             sysbus.nvic WriteDoubleWord ${NVIC_SCR} ${{${SCR_SLEEPDEEP} if ${deep} else 0}}
    Execute Command             sysbus.cpu PC ${HOST_CODE}
    Execute Command             sysbus.cpu SP ${HOST_STACK}
    Execute Command             sysbus.cpu IsHalted false
    Execute Command             emulation RunFor "${RUN_TIME}"

Wake Host
    Execute Command             sysbus.nvic WriteDoubleWord ${NVIC_ISPR} 0x1
    Execute Command             emulation RunFor "${RUN_TIME}"

Wake Host With Interrupt Line
    # The NVIC resumes SysTick on exiting deep sleep only for a wake-up by an external
    # interrupt line, not for a software pend, so SysTick needs this wake-up.
    Execute Command             sysbus.nvic OnGPIO 0 true
    Execute Command             emulation RunFor "${RUN_TIME}"

Release Sequencer
    # The sequencer is a Cortex-M0+, which the assembler has no model for, so the host CPU
    # assembles its Thumb image into the shared sequencer RAM.
    Execute Command             sysbus WriteDoubleWord ${SEQ_RAM} ${SEQ_STACK}
    Execute Command             sysbus WriteDoubleWord 0xB0000004 ${{${SEQ_SPIN} | 1}}
    Execute Command             cpu AssembleBlock ${SEQ_SPIN} "${SPIN_LOOP}"
    Execute Command             cpu AssembleBlock ${SEQ_SLEEP} "wfi; ${SPIN_LOOP}"
    Execute Command             sysbus WriteDoubleWord ${RAC_CTRL} ${RAC_CPUWAITDIS}
    Execute Command             emulation RunFor "${RUN_TIME}"

Put Sequencer To Sleep
    Execute Command             sysbus.seqcpu PC ${SEQ_SLEEP}
    Execute Command             emulation RunFor "${RUN_TIME}"

Write EM1PCSR
    [Arguments]                 ${value}
    Execute Command             sysbus WriteDoubleWord ${RAC_EM1PCSR} ${value}

EM1PCSR Should Be
    [Arguments]                 ${expected}
    ${em1pcsr}=                 Execute Command  sysbus ReadDoubleWord ${RAC_EM1PCSR}
    Should Be Equal As Integers  ${em1pcsr}  ${expected}

Bit Should Be
    [Arguments]                 ${peripheral}  ${offset}  ${mask}  ${expected}
    ${value}=                   Execute Command  ${peripheral} ReadDoubleWord ${offset}
    Should Be Equal As Strings  ${{bool(int($value, 16) & ${mask})}}  ${expected}

Hardware Request Should Be
    [Arguments]                 ${expected}
    Bit Should Be               sysbus  ${RAC_EM1PCSR}  ${RAC_EM1P_HWREQ}  ${expected}

EM1P Status Should Be
    [Arguments]                 ${expected}
    Bit Should Be               sysbus  ${EMU_STATUS}  ${EMU_STATUS_EM1P}  ${expected}

Energy Mode Should Be
    [Arguments]                 ${expected}
    # Reading the property prints the current value followed by the accepted values.
    ${mode}=                    Execute Command  sysbus.emu CurrentEnergyMode
    Should Start With           ${mode}  ${expected}\n

Host Clocks Should Be
    [Arguments]                 ${expected}
    ${enabled}=                 Execute Command  sysbus.emu HostClocksEnabled
    Should Start With           ${enabled}  ${expected}

HostAll Clocks Should Be
    [Arguments]                 ${expected}
    ${enabled}=                 Execute Command  sysbus.emu HostAllClocksEnabled
    Should Start With           ${enabled}  ${expected}

Start TIMER0
    Execute Command             sysbus.timer0 WriteDoubleWord ${TIMER0_EN} 0x1
    Execute Command             sysbus.timer0 WriteDoubleWord ${TIMER0_CMD} 0x1

Read TIMER0 Count
    ${value}=                   Execute Command  sysbus.timer0 ReadDoubleWord ${TIMER0_CNT}
    RETURN                      ${value}

Start USART0 Compare Timer
    Execute Command             sysbus.usart0 WriteDoubleWord ${USART0_ENABLE} 0x1
    Execute Command             sysbus.usart0 WriteDoubleWord ${USART0_CLKCTRL} ${USART_CLKCTRL_DIV_6000}
    Execute Command             sysbus.usart0 WriteDoubleWord ${USART0_TIMECMP0} ${USART_TIMECMP0_TXEOF_255}
    Execute Command             sysbus.usart0 WriteDoubleWord ${USART0_CMD} ${USART_CMD_TXEN}
    Execute Command             sysbus.usart0 WriteDoubleWord ${USART0_TXDATA} 0x41

USART0 Compare Should Be
    [Arguments]                 ${expected}
    Bit Should Be               sysbus.usart0  ${USART0_IF}  ${USART_IF_TCMP0}  ${expected}

SysTick Should Have Counted
    [Arguments]                 ${expected}
    Bit Should Be               sysbus.nvic  ${SYST_CSR}  ${SYST_CSR_COUNTFLAG}  ${expected}

Configure EUSART0
    [Arguments]                 ${cfg1}
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_ENABLE} 0x1
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_CFG1} ${cfg1}
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_CMD} ${EUSART_CMD_RXEN}

Receive EUSART0 Frame
    Execute Command             sysbus.eusart0 WriteChar ${EUSART_FRAME}

Read EUSART0 Frame
    Execute Command             sysbus.eusart0 ReadDoubleWord ${EUSART0_RXDATA}

Write LDMA Register
    [Arguments]                 ${base}  ${offset}  ${value}
    Execute Command             sysbus WriteDoubleWord ${{${base} + ${offset}}} ${value}

Prepare LDMA Channel 0
    [Arguments]                 ${ctrl}  ${source}
    Execute Command             sysbus WriteDoubleWord ${LDMA_TARGET} 0x0
    Write LDMA Register         ${LDMA_BASE}  ${LDMA_CH0_CTRL}  ${ctrl}
    Write LDMA Register         ${LDMA_BASE}  ${LDMA_CH0_SRC}  ${source}
    Write LDMA Register         ${LDMA_BASE}  ${LDMA_CH0_DST}  ${LDMA_TARGET}
    Write LDMA Register         ${LDMA_BASE}  ${LDMA_IEN}  0x1
    Write LDMA Register         ${LDMA_BASE}  ${LDMA_CHEN}  0x1

Prepare LDMA Word Copy
    Execute Command             sysbus WriteDoubleWord ${LDMA_SOURCE} ${LDMA_PATTERN}
    Prepare LDMA Channel 0      ${LDMA_CTRL_WORD_COPY}  ${LDMA_SOURCE}

Request LDMA Word Copy
    Write LDMA Register         ${LDMA_BASE}  ${LDMA_SWREQ}  0x1

LDMA Target Should Be
    [Arguments]                 ${expected}
    ${value}=                   Execute Command  sysbus ReadDoubleWord ${LDMA_TARGET}
    Should Be Equal As Integers  ${value}  ${expected}

LDMA Done Flag Should Be
    [Arguments]                 ${expected}
    Bit Should Be               sysbus  ${{${LDMA_BASE} + ${LDMA_IF}}}  0x1  ${expected}

Configure WDOG
    [Arguments]                 ${em2run}
    Execute Command             sysbus.wdog0 WriteDoubleWord ${WDOG0_CFG} ${{${WDOG_CFG_EM2RUN} if ${em2run} else ${WDOG_CFG_EM1RUN}}}
    Execute Command             sysbus.wdog0 WriteDoubleWord ${WDOG0_EN} 0x1

WDOG Timeout Should Be
    [Arguments]                 ${expected}
    Bit Should Be               sysbus.wdog0  ${WDOG0_IF}  0x1  ${expected}

# Test bodies. Each one takes the platform as its first argument and is run once per
# platform by the [Template] rows in the test cases.

Deep Sleep Is EM2 Until Software Requests EM1P
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Energy Mode Should Be       EM0
    EM1P Status Should Be       False

    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    Host Clocks Should Be       False
    HostAll Clocks Should Be    False
    EM1PCSR Should Be           0x0

    # Software control with the request enabled. The ack follows the request at once.
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Energy Mode Should Be       EM1P
    EM1P Status Should Be       True
    # A radio request powers PD1 but does not turn the host clock domain on.
    Host Clocks Should Be       False
    HostAll Clocks Should Be    False
    EM1PCSR Should Be           ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_REQ} | ${RAC_EM1P_ACK}}}

    # Dropping the request while the host stays in deep sleep returns to EM2.
    Write EM1PCSR               0x0
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False

    Wake Host
    Energy Mode Should Be       EM0
    EM1P Status Should Be       False
    Host Clocks Should Be       True
    HostAll Clocks Should Be    True

Running Sequencer Holds EM1P Until It Sleeps
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Release Sequencer
    # The host is halted, so a sequencer request on its own leaves the system in EM0.
    Energy Mode Should Be       EM0
    EM1PCSR Should Be           ${{${RAC_EM1P_REQ} | ${RAC_EM1P_ACK} | ${RAC_EM1P_HWREQ}}}

    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    EM1P Status Should Be       True
    Host Clocks Should Be       False

    # The sequencer goes to WFI with the radio idle, which clears the hardware request.
    Put Sequencer To Sleep
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    EM1PCSR Should Be           0x0

    Wake Host
    Energy Mode Should Be       EM0

EM2 Shuts The Sequencer Down Until CPUWAITDIS
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Release Sequencer
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P

    Put Sequencer To Sleep
    Energy Mode Should Be       EM2
    Hardware Request Should Be  False

    # Waking the host powers the sequencer back up, but it stays in CPUWAIT.
    Wake Host
    Energy Mode Should Be       EM0
    Hardware Request Should Be  False

    # Leaving EM2 for EM1P does not release it either.
    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Energy Mode Should Be       EM1P
    Hardware Request Should Be  False
    Write EM1PCSR               0x0
    Energy Mode Should Be       EM2

    # The host is still in deep sleep. Setting CPUWAITDIS is what releases the core,
    # and a running sequencer brings the system back to EM1P.
    Execute Command             sysbus WriteDoubleWord ${RAC_CTRL} ${RAC_CPUWAITDIS}
    Execute Command             emulation RunFor "${RUN_TIME}"
    Energy Mode Should Be       EM1P
    Hardware Request Should Be  True

Sleep Without Deep Sleep Stays EM1
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            False
    Energy Mode Should Be       EM1
    EM1P Status Should Be       False
    Host Clocks Should Be       True
    HostAll Clocks Should Be    True

    Wake Host
    Energy Mode Should Be       EM0
    Host Clocks Should Be       True
    HostAll Clocks Should Be    True

MCUEM1PMODE Enables Host Clocks In EM1P
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False

    # Software control with the disable bit clear forces the host clocks on.
    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL}}}
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       True
    # MCUEM1PMODE opens the Host EM1P domain only. The rest of the HCLK tree stays off.
    HostAll Clocks Should Be    False

    # MODE and DISSWREQ both set is the disabled combination.
    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL} | ${RAC_EM1P_MCU_DISSWREQ}}}
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False

    Wake Host
    Energy Mode Should Be       EM0
    Host Clocks Should Be       True

EM2RUN Clear Freezes WDOG In EM1P
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Configure WDOG              False
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Execute Command             emulation RunFor "${WDOG_PAST_TIMEOUT}"
    Energy Mode Should Be       EM1P
    WDOG Timeout Should Be      False
    Wake Host
    Energy Mode Should Be       EM0
    Execute Command             emulation RunFor "${WDOG_PAST_TIMEOUT}"
    WDOG Timeout Should Be      True

EM2RUN Set Lets WDOG Run In EM1P
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Configure WDOG              True
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Execute Command             emulation RunFor "${WDOG_PAST_TIMEOUT}"
    Energy Mode Should Be       EM1P
    WDOG Timeout Should Be      True

Timer Should Be Frozen In EM1P
    [Arguments]                 ${platform}  ${host_clock_request}
    Create Machine              ${platform}
    Start TIMER0
    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | (${RAC_EM1P_MCU_SWCTRL} if ${host_clock_request} else 0)}}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    HostAll Clocks Should Be    False
    ${before}=                  Read TIMER0 Count
    Execute Command             emulation RunFor "${RUN_TIME}"
    ${after}=                   Read TIMER0 Count
    Should Be Equal As Integers  ${after}  ${before}

    Wake Host
    Energy Mode Should Be       EM0
    HostAll Clocks Should Be    True
    ${resumed}=                 Read TIMER0 Count
    Should Not Be Equal As Integers  ${resumed}  ${after}

Timer Should Count In
    [Arguments]                 ${platform}  ${energy_mode}  ${deep}  ${counting}
    Create Machine              ${platform}
    Start TIMER0
    Enter Host Sleep            ${deep}
    Energy Mode Should Be       ${energy_mode}
    ${before}=                  Read TIMER0 Count
    Execute Command             emulation RunFor "${RUN_TIME}"
    ${after}=                   Read TIMER0 Count
    IF  ${counting}
        Should Not Be Equal As Integers  ${after}  ${before}
    ELSE
        Should Be Equal As Integers  ${after}  ${before}
    END

USART Compare Timer Is Stopped In EM1P
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Start USART0 Compare Timer
    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL}}}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Execute Command             emulation RunFor "${USART_PAST_COMPARE}"
    Energy Mode Should Be       EM1P
    USART0 Compare Should Be    False

    Wake Host
    Energy Mode Should Be       EM0
    Execute Command             emulation RunFor "${USART_PAST_COMPARE}"
    USART0 Compare Should Be    True

USART Compare Timer Runs In EM1
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Start USART0 Compare Timer
    Enter Host Sleep            False
    Energy Mode Should Be       EM1
    Execute Command             emulation RunFor "${USART_PAST_COMPARE}"
    USART0 Compare Should Be    True

SysTick Is Stopped In EM1P
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Execute Command             sysbus.nvic WriteDoubleWord ${SYST_RVR} ${SYST_RELOAD}
    # Any write to CVR loads the reload value, otherwise the first period is the 24-bit maximum.
    Execute Command             sysbus.nvic WriteDoubleWord ${SYST_CVR} 0x0
    Execute Command             sysbus.nvic WriteDoubleWord ${SYST_CSR} ${SYST_CSR_ENABLE_CORECLK}
    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL}}}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Execute Command             emulation RunFor "${SYST_PAST_RELOAD}"
    Energy Mode Should Be       EM1P
    SysTick Should Have Counted  False

    Wake Host With Interrupt Line
    Energy Mode Should Be       EM0
    Execute Command             emulation RunFor "${SYST_PAST_RELOAD}"
    SysTick Should Have Counted  True

EUSART0 RX DMA Wakeup Holds EM1P Until The Frame Is Read
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Configure EUSART0           ${EUSART_CFG1_RXDMAWU}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

    Receive EUSART0 Frame
    Energy Mode Should Be       EM1P
    EM1P Status Should Be       True
    # The request carries the bus clock, but not the rest of the HCLK tree.
    Host Clocks Should Be       True
    HostAll Clocks Should Be    False

    Read EUSART0 Frame
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    Host Clocks Should Be       False

EUSART0 Frame Without RXDMAWU Leaves The Host In EM2
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Configure EUSART0           0x0
    Enter Host Sleep            True
    Energy Mode Should Be       EM2

    Receive EUSART0 Frame
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    Host Clocks Should Be       False

EUSART0 RX DMA Wakeup Waits For RXFIW Frames
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Configure EUSART0           ${EUSART_CFG1_RXDMAWU_RXFIW_1}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2

    # RXFIW is 1, so the DMA request needs two frames.
    Receive EUSART0 Frame
    Energy Mode Should Be       EM2
    Receive EUSART0 Frame
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       True

    Read EUSART0 Frame
    Energy Mode Should Be       EM2

EUSART0 TX DMA Wakeup Holds EM1P While Enabled
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Configure EUSART0           ${EUSART_CFG1_TXDMAWU}
    Enter Host Sleep            True
    # TXDMAWU alone does not wake. The transmitter has to be enabled.
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_CMD} ${EUSART_CMD_TXEN}
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       True
    HostAll Clocks Should Be    False

    # CLEARTX drops the wake-up until the next TXEN. TXDIS and clearing EN drop it too.
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_CMD} ${EUSART_CMD_CLEARTX}
    Energy Mode Should Be       EM2
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_CMD} ${EUSART_CMD_TXEN}
    Energy Mode Should Be       EM1P

    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_CMD} ${EUSART_CMD_TXDIS}
    Energy Mode Should Be       EM2
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_CMD} ${EUSART_CMD_TXEN}
    Energy Mode Should Be       EM1P

    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_ENABLE} 0x0
    Energy Mode Should Be       EM2
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_ENABLE} 0x1
    Energy Mode Should Be       EM1P

    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUSART0_CFG1} 0x0
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

LDMA Request Waits For Host Clocks In EM1P
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False
    Prepare LDMA Word Copy

    Request LDMA Word Copy
    LDMA Target Should Be       0x0
    LDMA Done Flag Should Be    False

    # MCUEM1PMODE starts the bus clock, which releases the held request.
    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL}}}
    Host Clocks Should Be       True
    LDMA Target Should Be       ${LDMA_PATTERN}
    LDMA Done Flag Should Be    True

LDMA Request Waits For Host Clocks In EM2
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    Prepare LDMA Word Copy

    Request LDMA Word Copy
    LDMA Target Should Be       0x0

    Wake Host
    Energy Mode Should Be       EM0
    LDMA Target Should Be       ${LDMA_PATTERN}
    LDMA Done Flag Should Be    True

LDMA Runs Immediately While The Host Clocks Run
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Enter Host Sleep            False
    Energy Mode Should Be       EM1
    Prepare LDMA Word Copy

    Request LDMA Word Copy
    LDMA Target Should Be       ${LDMA_PATTERN}

LDMA Moves EUSART0 Data In EM1P While The Host Sleeps
    [Arguments]                 ${platform}
    Create Machine              ${platform}
    Configure EUSART0           ${EUSART_CFG1_RXDMAWU}
    Write LDMA Register         ${LDMAXBAR_BASE}  ${LDMAXBAR_CH0_REQSEL}  ${LDMA_REQSEL_EUSART0_RXFL}
    Prepare LDMA Channel 0      ${LDMA_CTRL_BYTE_FROM_FIXED}  ${EUSART0_RXDATA_ADDRESS}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2

    # The frame wakes the system to EM1P, the LDMA reads it into RAM, and the request
    # drops once the receive FIFO is empty, so the system returns to EM2 by itself.
    Receive EUSART0 Frame
    LDMA Target Should Be       ${EUSART_FRAME}
    LDMA Done Flag Should Be    True
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    Host Clocks Should Be       False

*** Test Cases ***
Should Enter EM2 In Deep Sleep Until Software Requests EM1P
    [Template]                  Deep Sleep Is EM2 Until Software Requests EM1P
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Hold EM1P While The Sequencer Runs
    [Template]                  Running Sequencer Holds EM1P Until It Sleeps
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Keep The Sequencer Down After EM2 Until CPUWAITDIS
    [Template]                  EM2 Shuts The Sequencer Down Until CPUWAITDIS
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Stay In EM1 Without Deep Sleep
    [Template]                  Sleep Without Deep Sleep Stays EM1
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Enable Host Clocks In EM1P With MCUEM1PMODE
    [Template]                  MCUEM1PMODE Enables Host Clocks In EM1P
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Freeze WDOG In EM1P With EM2RUN Clear
    [Template]                  EM2RUN Clear Freezes WDOG In EM1P
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Run WDOG In EM1P With EM2RUN Set
    [Template]                  EM2RUN Set Lets WDOG Run In EM1P
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Stop Timers In EM1P
    [Template]                  Timer Should Be Frozen In EM1P
    # platform                  MCUEM1PMODE host clock request
    ${XG24_PLATFORM}            False
    ${XG24_PLATFORM}            True
    ${XG26_PLATFORM}            False
    ${XG26_PLATFORM}            True

Should Stop Timers In EM2 And Run Them In EM1
    [Template]                  Timer Should Count In
    # platform                  mode  deep sleep  counting
    ${XG24_PLATFORM}            EM2   True        False
    ${XG24_PLATFORM}            EM1   False       True
    ${XG26_PLATFORM}            EM2   True        False
    ${XG26_PLATFORM}            EM1   False       True

Should Stop USART Compare Timer In EM1P
    [Template]                  USART Compare Timer Is Stopped In EM1P
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Run USART Compare Timer In EM1
    [Template]                  USART Compare Timer Runs In EM1
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Stop SysTick In EM1P
    [Template]                  SysTick Is Stopped In EM1P
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Hold EM1P On EUSART0 RX DMA Wakeup Until The Frame Is Read
    [Template]                  EUSART0 RX DMA Wakeup Holds EM1P Until The Frame Is Read
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Stay In EM2 On EUSART0 Frame Without RXDMAWU
    [Template]                  EUSART0 Frame Without RXDMAWU Leaves The Host In EM2
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Wait For RXFIW Frames Before EUSART0 RX DMA Wakeup
    [Template]                  EUSART0 RX DMA Wakeup Waits For RXFIW Frames
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Hold EM1P On EUSART0 TX DMA Wakeup While Enabled
    [Template]                  EUSART0 TX DMA Wakeup Holds EM1P While Enabled
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Hold LDMA Request Until Host Clocks Run In EM1P
    [Template]                  LDMA Request Waits For Host Clocks In EM1P
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Hold LDMA Request Until Host Clocks Run In EM2
    [Template]                  LDMA Request Waits For Host Clocks In EM2
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Run LDMA Immediately While The Host Clocks Run
    [Template]                  LDMA Runs Immediately While The Host Clocks Run
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}

Should Move EUSART0 Data With LDMA In EM1P While The Host Sleeps
    [Template]                  LDMA Moves EUSART0 Data In EM1P While The Host Sleeps
    ${XG24_PLATFORM}
    ${XG26_PLATFORM}
