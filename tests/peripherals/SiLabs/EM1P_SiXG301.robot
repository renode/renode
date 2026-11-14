*** Settings ***
Test Setup                      Create Machine

*** Comments ***
EM1P coverage for the SiXG301 EMU and its RISC-V radio sequencer.

The behavior matches the xG24 suite (EM1P_xG24.robot): the radio requests EM1P through RAC EM1PCSR
while its sequencer runs, or while software has taken EM1P control, and the request drops once
the sequencer is in WFI with the radio state machine idle. On SiXG301 the sequencer is released
from CPUWAIT by RAC CTRL.CPUWAITDIS, starting at the RVCFG1 boot address. It is not a Cortex-M
core, so its WFI never selects the system energy mode, but it takes part in the EM2 quiescence
handshake: the RISC-V subsystem accepts the request while the core waits in WFI. EM2 powers the
sequencer down, and it boots again from the retained boot address when EM2 exits.

The Host EM1P clock domain (bus, LDMA, EUSART0, ...) stops in EM2 and in EM1P unless
MCUEM1PMODE asks for it. The HostAll domain, which holds the timers and SysTick, only runs in
EM0 and EM1. EUSART0 is the EM2 capable instance and requests EM1P and the bus clock for its
DMA wake-ups. The watchdog follows EM2RUN in EM1P.

The design book lists EM1P and EM2 as not officially supported on this device. The model
follows the same handshake as the other Series 2 radios.

*** Variables ***
${PLATFORM_FILE}                platforms/boards/silabs/brd4407a.repl

${EMU_STATUS}                   0xA3008084
${EMU_STATUS_EM1P}              0x800

${RAC_CTRL}                     0xA0220014
${RAC_STATUS}                   0xA022000C
${RAC_STATUS_SEQSLEEPING}       0x400000
${RAC_EM1PCSR}                  0xA022008C
${RAC_CPUWAITDIS}               0x04000000
${RAC_EM1P_SWCTRL}              0x1
${RAC_EM1P_MCU_SWCTRL}          0x10
${RAC_EM1P_MCU_DISSWREQ}        0x20
${RAC_EM1P_REQ}                 0x10000
${RAC_EM1P_ACK}                 0x20000
${RAC_EM1P_HWREQ}               0x40000
${RVCFG1_BOOTADDR}              0xA0248024

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
${SPIN_LOOP}                    movs r1, #1; 1: subs r0, #1; b 1b

# RISC-V sequencer image in sequencer RAM. SEQ_SPIN spins, and the sleep entry
# is "wfi" followed by the same loop.
${SEQ_SPIN}                     0xA0000100
${SEQ_SLEEP}                    0xA0000200
${RV_SPIN_LOOP}                 1: addi t0, t0, 1; j 1b

${RUN_TIME}                     0.0001
${QUANTUM}                      0.00001

# WDOG0, same programming model as the xG24 suite.
${WDOG0_EN}                     0x4
${WDOG0_CFG}                    0x8
${WDOG0_IF}                     0x18
${WDOG_CFG_EM1RUN}              0x00030102
${WDOG_CFG_EM2RUN}              0x00030104
${WDOG_PAST_TIMEOUT}            0.004

${TIMER0_CMD}                   0xC
${TIMER0_CNT}                   0x28
${TIMER0_EN}                    0x30

# EUSART0, the EM2 capable instance.
${EUSART0_ENABLE}               0x4
${EUSART0_CFG1}                 0xC
${EUSART0_CMD}                  0x38
${EUSART0_RXDATA}               0x3C
${EUSART0_RXDATA_ADDRESS}       0x4020803C
${EUSART_CMD_RXEN}              0x1
${EUSART_CMD_TXEN}              0x4
${EUSART_CMD_TXDIS}             0x8
${EUSART_CMD_CLEARTX}           0x100
${EUSART_CFG1_TXDMAWU}          0x200
${EUSART_CFG1_RXDMAWU}          0x400
${EUSART_CFG1_RXDMAWU_RXFIW_1}  0x08000400
${EUSART_FRAME}                 0x41

# LDMA channel 0. REQSEL picks EUSART0 (source 0x9) receive FIFO level (signal 0).
${LDMA_BASE}                    0x40814000
${LDMAXBAR_BASE}                0x40844000
${LDMA_CHEN}                    0x28
${LDMA_SWREQ}                   0x40
${LDMA_IF}                      0x54
${LDMA_IEN}                     0x58
${LDMA_CH0_CTRL}                0x78
${LDMA_CH0_SRC}                 0x7C
${LDMA_CH0_DST}                 0x80
${LDMAXBAR_CH0_REQSEL}          0x4
${LDMA_REQSEL_EUSART0_RXFL}     0x00090000
${LDMA_CTRL_WORD_COPY}          0x08300000
${LDMA_CTRL_BYTE_FROM_FIXED}    0x03300000
${LDMA_SOURCE}                  0x20002000
${LDMA_TARGET}                  0x20002100
${LDMA_PATTERN}                 0xA5A5A5A5

${SYST_CSR}                     0x10
${SYST_RVR}                     0x14
${SYST_CVR}                     0x18
${SYST_CSR_ENABLE_CORECLK}      0x5
${SYST_CSR_COUNTFLAG}           0x10000
${SYST_RELOAD}                  1000000
${SYST_PAST_RELOAD}             0.04

*** Keywords ***
Create Machine
    Renode Test Setup
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescription @${PLATFORM_FILE}
    Execute Command             emulation SetQuantum "${QUANTUM}"
    # Run the host core and the radio sequencer in a fixed order within each quantum
    Execute Command             emulation SetGlobalSerialExecution true
    Execute Command             sysbus.cpu IsHalted true
    Execute Command             sysbus.cpu VectorTableOffset 0x20000000
    Execute Command             sysbus WriteDoubleWord 0x20000000 ${HOST_STACK}
    Execute Command             sysbus WriteDoubleWord 0x20000004 ${{${HOST_CODE} | 1}}
    Execute Command             sysbus WriteDoubleWord 0x20000040 ${{${HOST_IRQ0} | 1}}
    Execute Command             cpu AssembleBlock ${HOST_CODE} "wfi; ${SPIN_LOOP}"
    Execute Command             cpu AssembleBlock ${HOST_IRQ0} "${SPIN_LOOP}"
    Execute Command             sysbus.nvic WriteDoubleWord ${NVIC_ISER} 0x1
    # The radio connects to the EMU on its first EM1PCSR update. Toggle the software request so
    # that happens, then leave the request clear.
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
    Execute Command             sysbus.seqcpu AssembleBlock ${SEQ_SPIN} "${RV_SPIN_LOOP}"
    Execute Command             sysbus.seqcpu AssembleBlock ${SEQ_SLEEP} "wfi; ${RV_SPIN_LOOP}"
    Execute Command             sysbus WriteDoubleWord ${RVCFG1_BOOTADDR} ${SEQ_SPIN}
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

Energy Mode Should Be
    [Arguments]                 ${expected}
    # Reading the property prints the current value followed by the accepted values.
    ${mode}=                    Execute Command  sysbus.emu CurrentEnergyMode
    Should Start With           ${mode}  ${expected}\n

Sequencer Should Be Running
    Bit Should Be               sysbus  ${RAC_EM1PCSR}  ${RAC_EM1P_HWREQ}  True

Sequencer Sleeping Should Be
    [Arguments]                 ${expected}
    Bit Should Be               sysbus  ${RAC_STATUS}  ${RAC_STATUS_SEQSLEEPING}  ${expected}

EM1P Status Should Be
    [Arguments]                 ${expected}
    Bit Should Be               sysbus  ${EMU_STATUS}  ${EMU_STATUS_EM1P}  ${expected}

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

Timer Should Be Frozen In EM1P
    [Arguments]                 ${host_clock_request}
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

Configure WDOG
    [Arguments]                 ${em2run}
    Execute Command             sysbus.wdog0 WriteDoubleWord ${WDOG0_CFG} ${{${WDOG_CFG_EM2RUN} if ${em2run} else ${WDOG_CFG_EM1RUN}}}
    Execute Command             sysbus.wdog0 WriteDoubleWord ${WDOG0_EN} 0x1

WDOG Timeout Should Be
    [Arguments]                 ${expected}
    Bit Should Be               sysbus.wdog0  ${WDOG0_IF}  0x1  ${expected}

*** Test Cases ***
Should Enter EM2 In Deep Sleep Until Software Requests EM1P
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
    Host Clocks Should Be       False
    HostAll Clocks Should Be    False
    EM1PCSR Should Be           ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_REQ} | ${RAC_EM1P_ACK}}}

    Write EM1PCSR               0x0
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False

    Wake Host
    Energy Mode Should Be       EM0
    Host Clocks Should Be       True
    HostAll Clocks Should Be    True

Should Hold EM1P While The Sequencer Runs
    # CPUWAIT holds the sequencer, and SEQSLEEPING stays clear until it executes WFI.
    Sequencer Sleeping Should Be  False
    Release Sequencer
    Sequencer Sleeping Should Be  False
    # The host is halted, so a sequencer request on its own leaves the system in EM0.
    Energy Mode Should Be       EM0
    EM1PCSR Should Be           ${{${RAC_EM1P_REQ} | ${RAC_EM1P_ACK} | ${RAC_EM1P_HWREQ}}}

    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    EM1P Status Should Be       True
    Host Clocks Should Be       False

    # The sequencer goes to WFI with the radio idle, which clears the hardware request. The
    # RISC-V subsystem accepts the quiescence request while the core waits in WFI.
    Put Sequencer To Sleep
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    EM1PCSR Should Be           0x0
    # EM2 powers the sequencer down, so it is no longer in WFI.
    Sequencer Sleeping Should Be  False

    Wake Host
    Energy Mode Should Be       EM0

Should Enter EM2 And Reset The Sequencer When It Sleeps
    Release Sequencer
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P

    # The sequencer goes to WFI with the radio idle, which clears the hardware request. WFI alone lets the
    # RISC-V subsystem accept the EM2 request.
    Put Sequencer To Sleep
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    EM1PCSR Should Be           0x0
    # EM2 powers the sequencer down, so it is no longer in WFI.
    Sequencer Sleeping Should Be  False

    # Leaving EM2 powers the sequencer up again from the retained boot address.
    Wake Host
    Energy Mode Should Be       EM0
    Sequencer Should Be Running
    Sequencer Sleeping Should Be  False

Should Restart The Sequencer When EM2 Exits To EM1P
    Release Sequencer
    Enter Host Sleep            True
    Put Sequencer To Sleep
    Energy Mode Should Be       EM2
    EM1PCSR Should Be           0x0

    # Software takes EM1P control while the host stays in deep sleep. The powered up sequencer
    # starts again and requests EM1P on its own.
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Energy Mode Should Be       EM1P
    Sequencer Should Be Running
    Write EM1PCSR               0x0
    Energy Mode Should Be       EM1P
    Sequencer Sleeping Should Be  False

Should Stay In EM1 Without Deep Sleep
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            False
    Energy Mode Should Be       EM1
    EM1P Status Should Be       False
    Host Clocks Should Be       True
    HostAll Clocks Should Be    True

    Wake Host
    Energy Mode Should Be       EM0

Should Enable Host Clocks In EM1P With MCUEM1PMODE
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False

    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL}}}
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       True
    HostAll Clocks Should Be    False

    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL} | ${RAC_EM1P_MCU_DISSWREQ}}}
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False

    Wake Host
    Energy Mode Should Be       EM0
    Host Clocks Should Be       True

Should Freeze WDOG In EM1P With EM2RUN Clear
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

Should Run WDOG In EM1P With EM2RUN Set
    Configure WDOG              True
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Execute Command             emulation RunFor "${WDOG_PAST_TIMEOUT}"
    Energy Mode Should Be       EM1P
    WDOG Timeout Should Be      True

Should Stop Timers In EM1P Without Host Clock Request
    Timer Should Be Frozen In EM1P  False

Should Stop Timers In EM1P With MCUEM1PMODE
    Timer Should Be Frozen In EM1P  True

Should Stop Timers In EM2
    Start TIMER0
    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    ${before}=                  Read TIMER0 Count
    Execute Command             emulation RunFor "${RUN_TIME}"
    ${after}=                   Read TIMER0 Count
    Should Be Equal As Integers  ${after}  ${before}

Should Run Timers In EM1
    Start TIMER0
    Enter Host Sleep            False
    Energy Mode Should Be       EM1
    ${before}=                  Read TIMER0 Count
    Execute Command             emulation RunFor "${RUN_TIME}"
    ${after}=                   Read TIMER0 Count
    Should Not Be Equal As Integers  ${after}  ${before}

Should Stop SysTick In EM1P
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

Should Hold EM1P On EUSART0 RX DMA Wakeup Until The Frame Is Read
    Configure EUSART0           ${EUSART_CFG1_RXDMAWU}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

    Receive EUSART0 Frame
    Energy Mode Should Be       EM1P
    EM1P Status Should Be       True
    Host Clocks Should Be       True
    HostAll Clocks Should Be    False

    Read EUSART0 Frame
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    Host Clocks Should Be       False

Should Stay In EM2 On EUSART0 Frame Without RXDMAWU
    Configure EUSART0           0x0
    Enter Host Sleep            True
    Energy Mode Should Be       EM2

    Receive EUSART0 Frame
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

Should Wait For RXFIW Frames Before EUSART0 RX DMA Wakeup
    Configure EUSART0           ${EUSART_CFG1_RXDMAWU_RXFIW_1}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2

    Receive EUSART0 Frame
    Energy Mode Should Be       EM2
    Receive EUSART0 Frame
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       True

    Read EUSART0 Frame
    Energy Mode Should Be       EM2

Should Hold EM1P On EUSART0 TX DMA Wakeup While Enabled
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

Should Request EM1P Only From EUSART0
    Execute Command             sysbus.eusart1 WriteDoubleWord ${EUSART0_ENABLE} 0x1
    Execute Command             sysbus.eusart1 WriteDoubleWord ${EUSART0_CFG1} ${EUSART_CFG1_TXDMAWU}
    Execute Command             sysbus.eusart1 WriteDoubleWord ${EUSART0_CMD} ${EUSART_CMD_TXEN}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2

Should Hold LDMA Request Until Host Clocks Run In EM1P
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False
    Prepare LDMA Word Copy

    Request LDMA Word Copy
    LDMA Target Should Be       0x0
    LDMA Done Flag Should Be    False

    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL}}}
    Host Clocks Should Be       True
    LDMA Target Should Be       ${LDMA_PATTERN}
    LDMA Done Flag Should Be    True

Should Hold LDMA Request Until Host Clocks Run In EM2
    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    Prepare LDMA Word Copy

    Request LDMA Word Copy
    LDMA Target Should Be       0x0

    Wake Host
    Energy Mode Should Be       EM0
    LDMA Target Should Be       ${LDMA_PATTERN}
    LDMA Done Flag Should Be    True

Should Run LDMA Immediately While The Host Clocks Run
    Enter Host Sleep            False
    Energy Mode Should Be       EM1
    Prepare LDMA Word Copy

    Request LDMA Word Copy
    LDMA Target Should Be       ${LDMA_PATTERN}

Should Move EUSART0 Data With LDMA In EM1P While The Host Sleeps
    Configure EUSART0           ${EUSART_CFG1_RXDMAWU}
    Write LDMA Register         ${LDMAXBAR_BASE}  ${LDMAXBAR_CH0_REQSEL}  ${LDMA_REQSEL_EUSART0_RXFL}
    Prepare LDMA Channel 0      ${LDMA_CTRL_BYTE_FROM_FIXED}  ${EUSART0_RXDATA_ADDRESS}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2

    Receive EUSART0 Frame
    LDMA Target Should Be       ${EUSART_FRAME}
    LDMA Done Flag Should Be    True
    Energy Mode Should Be       EM2
    EM1P Status Should Be       False
    Host Clocks Should Be       False
