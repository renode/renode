*** Settings ***
Test Setup                      Create Machine

*** Comments ***
EM1P coverage for the xG22 EMU and its radio sequencer.

EM1P is the energy mode where the host is in deep sleep but an EM1P requester keeps the
PD1 domain powered. On xG22 the requester is the radio: RAC EM1PCSR reports a request while
the sequencer is running, or while software has taken EM1P control, and the request drops
once the sequencer is in WFI with the radio state machine idle. The sequencer's own WFI
must not select the system energy mode, because that core sleeps with SLEEPDEEP clear.
EM2 shuts the sequencer down: it is held in CPUWAIT and reset, and it stays there until
software sets CPUWAITDIS again.

xG22 has no EMU STATUS.EM1P bit, so the tests read the energy mode from the EMU model.
Host clocks run in EM0 and EM1, stop in EM2, and in EM1P stop unless RAC EM1PCSR.MCUEM1PMODE
is in software control with MCUEM1PDISSWREQ clear.

The host executes a real "wfi" out of SRAM. IRQ0 is enabled up front and pended to leave
the energy mode; its handler is a short counting loop so the core stays awake there
instead of running off the end of the image. A branch to itself is not usable for that,
because this CPU model reports one as WFI.

*** Variables ***
${PLATFORM_FILE}                platforms/boards/silabs/brd4182a.repl

${RAC_CTRL}                     0xA8020014
${RAC_EM1PCSR}                  0xA802005C
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

# Host image in the 32 KB SRAM. The vector table needs the stack pointer, the reset vector and IRQ0.
${HOST_STACK}                   0x20007000
${HOST_CODE}                    0x20000100
${HOST_IRQ0}                    0x20000200
# The CPU model reports a branch-to-self as WFI, so an idle loop has to do some work.
# Issued a PR to fix it: https://github.com/antmicro/tlib/pull/69
${SPIN_LOOP}                    movs r1, #1; 1: subs r0, #1; b 1b

${SEQ_RAM}                      0xB0000000
${SEQ_STACK}                    0xB0003F00
${SEQ_SPIN}                     0xB0000100
${SEQ_SLEEP}                    0xB0000200

${RUN_TIME}                     0.0001
${QUANTUM}                      0.00001

${TIMER0_CMD}                   0xC
${TIMER0_CNT}                   0x24

# EUART0 is the EM2 capable UART. RXDMAWU is CFG1 bit 10. RXDATA is at offset 0x34.
${EUART0_ENABLE}                0x4
${EUART0_CFG1}                  0xC
${EUART0_CMD}                   0x30
${EUART0_RXDATA}                0x34
${EUART0_RXDATA_ADDRESS}        0x4A030034
${EUART_CMD_RXEN}               0x1
${EUART_CMD_TXEN}               0x4
${EUART_CMD_TXDIS}              0x8
${EUART_CMD_CLEARTX}            0x100
${EUART_CFG1_RXDMAWU}           0x400
${EUART_CFG1_TXDMAWU}           0x200
${EUART_FRAME}                  0x41

# LDMA channel 0. REQSEL picks EUART0 (source 0x10) receive FIFO level (signal 0).
${LDMA_BASE}                    0x40040000
${LDMAXBAR_BASE}                0x40044000
${LDMA_CHEN}                    0x24
${LDMA_SWREQ}                   0x3C
${LDMA_IEN}                     0x54
${LDMA_CH0_CTRL}                0x64
${LDMA_CH0_SRC}                 0x68
${LDMA_CH0_DST}                 0x6C
${LDMAXBAR_CH0_REQSEL}          0x0
${LDMA_REQSEL_EUART0_RXFL}      0x00100000
${LDMA_CTRL_WORD_COPY}          0x08300000
${LDMA_CTRL_BYTE_FROM_FIXED}    0x03300000
${LDMA_SOURCE}                  0x20002000
${LDMA_TARGET}                  0x20002100
${LDMA_PATTERN}                 0xA5A5A5A5

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

Hardware Request Should Be
    [Arguments]                 ${expected}
    ${em1pcsr}=                 Execute Command  sysbus ReadDoubleWord ${RAC_EM1PCSR}
    Should Be Equal As Strings  ${{bool(int($em1pcsr, 16) & ${RAC_EM1P_HWREQ})}}  ${expected}

Energy Mode Should Be
    [Arguments]                 ${expected}
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

Read TIMER0 Count
    ${value}=                   Execute Command  sysbus.timer0 ReadDoubleWord ${TIMER0_CNT}
    RETURN                      ${value}

Configure EUART0
    [Arguments]                 ${cfg1}
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_ENABLE} 0x1
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_CFG1} ${cfg1}
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_CMD} ${EUART_CMD_RXEN}

Receive EUART0 Frame
    Execute Command             sysbus.eusart0 WriteChar ${EUART_FRAME}

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

LDMA Target Should Be
    [Arguments]                 ${expected}
    ${value}=                   Execute Command  sysbus ReadDoubleWord ${LDMA_TARGET}
    Should Be Equal As Integers  ${value}  ${expected}

*** Test Cases ***
Should Enter EM2 In Deep Sleep Until Software Requests EM1P
    Energy Mode Should Be       EM0

    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False
    EM1PCSR Should Be           0x0

    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False
    EM1PCSR Should Be           ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_REQ} | ${RAC_EM1P_ACK}}}

    Write EM1PCSR               0x0
    Energy Mode Should Be       EM2

    Wake Host
    Energy Mode Should Be       EM0
    Host Clocks Should Be       True

Should Hold EM1P While The Sequencer Runs
    Release Sequencer
    Energy Mode Should Be       EM0
    EM1PCSR Should Be           ${{${RAC_EM1P_REQ} | ${RAC_EM1P_ACK} | ${RAC_EM1P_HWREQ}}}

    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False

    Put Sequencer To Sleep
    Energy Mode Should Be       EM2
    EM1PCSR Should Be           0x0

    Wake Host
    Energy Mode Should Be       EM0

Should Keep The Sequencer Down After EM2 Until CPUWAITDIS
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

Should Stay In EM1 Without Deep Sleep
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            False
    Energy Mode Should Be       EM1
    Host Clocks Should Be       True

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

    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL} | ${RAC_EM1P_MCU_DISSWREQ}}}
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False

    Wake Host
    Energy Mode Should Be       EM0
    Host Clocks Should Be       True

Should Stop Timers In EM1P With MCUEM1PMODE
    Execute Command             sysbus.timer0 WriteDoubleWord ${TIMER0_CMD} 0x1
    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL}}}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       True
    HostAll Clocks Should Be    False
    ${before}=                  Read TIMER0 Count
    Execute Command             emulation RunFor "${RUN_TIME}"
    ${after}=                   Read TIMER0 Count
    Should Be Equal As Integers  ${after}  ${before}

    Wake Host
    Energy Mode Should Be       EM0
    ${resumed}=                 Read TIMER0 Count
    Should Not Be Equal As Integers  ${resumed}  ${after}

Should Run Timers In EM1
    Execute Command             sysbus.timer0 WriteDoubleWord ${TIMER0_CMD} 0x1
    Enter Host Sleep            False
    Energy Mode Should Be       EM1
    ${before}=                  Read TIMER0 Count
    Execute Command             emulation RunFor "${RUN_TIME}"
    ${after}=                   Read TIMER0 Count
    Should Not Be Equal As Integers  ${after}  ${before}

Should Hold EM1P On EUART0 RX DMA Wakeup Until The Frame Is Read
    Configure EUART0            ${EUART_CFG1_RXDMAWU}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2

    Receive EUART0 Frame
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       True
    HostAll Clocks Should Be    False

    Execute Command             sysbus.eusart0 ReadDoubleWord ${EUART0_RXDATA}
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

Should Hold EM1P On EUART0 TX DMA Wakeup While Enabled
    Configure EUART0            ${EUART_CFG1_TXDMAWU}
    Enter Host Sleep            True
    # TXDMAWU alone does not wake. The transmitter has to be enabled.
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_CMD} ${EUART_CMD_TXEN}
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       True
    HostAll Clocks Should Be    False

    # CLEARTX drops the wake-up until the next TXEN. TXDIS and clearing EN drop it too.
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_CMD} ${EUART_CMD_CLEARTX}
    Energy Mode Should Be       EM2
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_CMD} ${EUART_CMD_TXEN}
    Energy Mode Should Be       EM1P

    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_CMD} ${EUART_CMD_TXDIS}
    Energy Mode Should Be       EM2
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_CMD} ${EUART_CMD_TXEN}
    Energy Mode Should Be       EM1P

    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_ENABLE} 0x0
    Energy Mode Should Be       EM2
    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_ENABLE} 0x1
    Energy Mode Should Be       EM1P

    Execute Command             sysbus.eusart0 WriteDoubleWord ${EUART0_CFG1} 0x0
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

Should Stay In EM2 On EUART0 Frame Without RXDMAWU
    Configure EUART0            0x0
    Enter Host Sleep            True
    Receive EUART0 Frame
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False

Should Hold LDMA Request Until Host Clocks Run In EM1P
    Write EM1PCSR               ${RAC_EM1P_SWCTRL}
    Enter Host Sleep            True
    Energy Mode Should Be       EM1P
    Host Clocks Should Be       False
    Execute Command             sysbus WriteDoubleWord ${LDMA_SOURCE} ${LDMA_PATTERN}
    Prepare LDMA Channel 0      ${LDMA_CTRL_WORD_COPY}  ${LDMA_SOURCE}
    Write LDMA Register         ${LDMA_BASE}  ${LDMA_SWREQ}  0x1
    LDMA Target Should Be       0x0

    Write EM1PCSR               ${{${RAC_EM1P_SWCTRL} | ${RAC_EM1P_MCU_SWCTRL}}}
    Host Clocks Should Be       True
    LDMA Target Should Be       ${LDMA_PATTERN}

Should Move EUART0 Data With LDMA In EM1P While The Host Sleeps
    Configure EUART0            ${EUART_CFG1_RXDMAWU}
    Write LDMA Register         ${LDMAXBAR_BASE}  ${LDMAXBAR_CH0_REQSEL}  ${LDMA_REQSEL_EUART0_RXFL}
    Prepare LDMA Channel 0      ${LDMA_CTRL_BYTE_FROM_FIXED}  ${EUART0_RXDATA_ADDRESS}
    Enter Host Sleep            True
    Energy Mode Should Be       EM2
    Receive EUART0 Frame
    LDMA Target Should Be       ${EUART_FRAME}
    Energy Mode Should Be       EM2
    Host Clocks Should Be       False
