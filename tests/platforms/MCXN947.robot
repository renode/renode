*** Settings ***
Test Setup                      Create Machine

*** Variables ***
${PLATFORM}                     platforms/boards/frdm_mcxn947.repl

${GPIO_PSOR}                    0x44
${GPIO_PCOR}                    0x48
${GPIO_PDIR}                    0x50
${GPIO_PDDR}                    0x54
${GPIO_ICR_BASE}                0x80
${GPIO_ISF0}                    0x120
${GPIO_ISF1}                    0x124

${FLEXCOMM_PSELID}              0xFF8
${FLEXCOMM_STAT}                0xFF4
${LPSPI_CR}                     0x10
${LPSPI_IER}                    0x18
${LPSPI_SR}                     0x14
${LPSPI_CFGR1}                  0x24
${LPSPI_TCR}                    0x60
${LPSPI_TDR}                    0x64
${LPI2C_MCR}                    0x810
${LPI2C_MIER}                   0x818
${LPI2C_MTDR}                   0x860
${LPI2C_MRDR}                   0x870

${WWDT_MOD}                     0x0
${WWDT_TC}                      0x4
${WWDT_FEED}                    0x8
${WWDT_WARNINT}                 0x14

*** Keywords ***
Create Machine
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescription @${PLATFORM}
    Execute Command             macro reset "cpu0 IsHalted true; cpu1 IsHalted true"
    Create Log Tester           timeout=1  defaultPauseEmulation=True

Connect LED To GPIO Pin
    [Arguments]                 ${pin}
    Execute Command             machine LoadPlatformDescriptionFromString "gpio0: { ${pin} -> testLed${pin}@0 }; testLed${pin}: Miscellaneous.LED @ gpio0 ${pin}"

Connect Button To GPIO Pin
    [Arguments]                 ${pin}
    Execute Command             machine LoadPlatformDescriptionFromString "button${pin}: Miscellaneous.Button @ gpio0 ${pin} { -> gpio0@${pin} }"

Halt CPUs
    Run Keyword And Ignore Error    Execute Command  cpu0 IsHalted true
    Run Keyword And Ignore Error    Execute Command  cpu1 IsHalted true

GPIO Interrupt Control Offset
    [Arguments]                 ${pin}
    ${offset}=                  Evaluate  ${GPIO_ICR_BASE} + (4 * ${pin})
    [Return]                    ${offset}

GPIO Should Have Bit Set
    [Arguments]                 ${value}  ${bit}
    ${mask}=                    Evaluate  1 << ${bit}
    ${masked}=                  Evaluate  int(${value}) & ${mask}
    Should Not Be Equal As Integers  ${masked}  0

GPIO Should Have Bit Cleared
    [Arguments]                 ${value}  ${bit}
    ${mask}=                    Evaluate  1 << ${bit}
    ${masked}=                  Evaluate  int(${value}) & ${mask}
    Should Be Equal As Integers     ${masked}  0

Signal Should Be
    [Arguments]                 ${signal_path}  ${expected}
    ${state}=                   Execute Command  ${signal_path} IsSet
    Should Be Equal             ${state.strip()}  ${expected}

Configure Rising Edge IRQ
    [Arguments]                 ${pin}  ${route_to_irq1}=False
    ${offset}=                  GPIO Interrupt Control Offset  ${pin}
    ${value}=                   Set Variable  0x00090000
    IF  ${route_to_irq1}
        ${value}=               Set Variable  0x00190000
    END
    Execute Command             gpio0 WriteDoubleWordToGPIO ${offset} ${value}

Set Flexcomm Mode
    [Arguments]                 ${instance}  ${mode}
    Execute Command             ${instance} WriteDoubleWord ${FLEXCOMM_PSELID} ${mode}

Configure WWDT Warning Window
    [Arguments]                 ${instance}
    Execute Command             ${instance} WriteDoubleWord ${WWDT_TC} 0x20
    Execute Command             ${instance} WriteDoubleWord ${WWDT_WARNINT} 0x10

Feed WWDT
    [Arguments]                 ${instance}
    Execute Command             ${instance} WriteDoubleWord ${WWDT_FEED} 0xAA
    Execute Command             ${instance} WriteDoubleWord ${WWDT_FEED} 0x55

Enable WWDT
    [Arguments]                 ${instance}  ${with_reset}=False
    ${mod}=                     Set Variable  0x1
    IF  ${with_reset}
        ${mod}=                 Set Variable  0x3
    END
    Execute Command             ${instance} WriteDoubleWord ${WWDT_MOD} ${mod}

*** Test Cases ***
Should Restore GPIO Defaults When Reset Pin Is Asserted
    Halt CPUs
    Execute Command             gpio0 WriteDoubleWordToGPIO ${GPIO_PDDR} 0x1
    ${before_reset}=            Execute Command  gpio0 ReadDoubleWordFromGPIO ${GPIO_PDDR}
    Should Be Equal As Integers  ${before_reset.strip()}  0x1

    Execute Command             sysbus.gpio0.resetPin OnGPIO 0 false
    Execute Command             emulation RunFor "0.001"

    ${after_reset}=             Execute Command  gpio0 ReadDoubleWordFromGPIO ${GPIO_PDDR}
    Should Be Equal As Integers  ${after_reset.strip()}  0x0

Should Drive GPIO Outputs And Sample GPIO Inputs
    Execute Command             emulation Mode SynchronizedTimers
    Connect LED To GPIO Pin     0
    Connect Button To GPIO Pin  1
    ${led}=                     Create LED Tester  sysbus.gpio0.testLed0  defaultTimeout=0

    Execute Command             gpio0 WriteDoubleWordToGPIO ${GPIO_PDDR} 0x1
    Execute Command             gpio0 WriteDoubleWordToGPIO ${GPIO_PSOR} 0x1
    Assert LED State            true  testerId=${led}
    Execute Command             gpio0 WriteDoubleWordToGPIO ${GPIO_PCOR} 0x1
    Assert LED State            false  testerId=${led}

    Execute Command             sysbus.gpio0.button1 Press
    ${pdir_high}=               Execute Command  gpio0 ReadDoubleWordFromGPIO ${GPIO_PDIR}
    GPIO Should Have Bit Set    ${pdir_high.strip()}  1
    Execute Command             sysbus.gpio0.button1 Release
    ${pdir_low}=                Execute Command  gpio0 ReadDoubleWordFromGPIO ${GPIO_PDIR}
    GPIO Should Have Bit Cleared  ${pdir_low.strip()}  1

Should Route GPIO Interrupts To Both IRQ Outputs And Clear Their Flags
    Configure Rising Edge IRQ   2
    Configure Rising Edge IRQ   3  route_to_irq1=${True}

    Execute Command             gpio0 OnGPIO 2 true
    Signal Should Be            gpio0 IRQ0  True
    Signal Should Be            gpio0 IRQ1  False
    ${irq0_flags}=              Execute Command  gpio0 ReadDoubleWordFromGPIO ${GPIO_ISF0}
    GPIO Should Have Bit Set    ${irq0_flags.strip()}  2

    Execute Command             gpio0 OnGPIO 3 true
    Signal Should Be            gpio0 IRQ1  True
    ${irq1_flags}=              Execute Command  gpio0 ReadDoubleWordFromGPIO ${GPIO_ISF1}
    GPIO Should Have Bit Set    ${irq1_flags.strip()}  3

    Execute Command             gpio0 WriteDoubleWordToGPIO ${GPIO_ISF0} 0x4
    Execute Command             gpio0 WriteDoubleWordToGPIO ${GPIO_ISF1} 0x8
    Signal Should Be            gpio0 IRQ0  False
    Signal Should Be            gpio0 IRQ1  False

Should Transfer A Byte Over LPSPI To Dummy Slave
    Execute Command             machine LoadPlatformDescriptionFromString "dummySlave: Mocks.DummySPISlave @ flexcomm0 0"
    Execute Command             logLevel 0 sysbus.flexcomm0.flexcomm0_spi.dummySlave

    Set Flexcomm Mode           flexcomm0  0x2
    Execute Command             flexcomm0 WriteDoubleWord ${LPSPI_CFGR1} 0x1
    Execute Command             flexcomm0 WriteDoubleWord ${LPSPI_CR} 0x1
    Execute Command             flexcomm0 WriteDoubleWord ${LPSPI_IER} 0x400
    Execute Command             flexcomm0 WriteDoubleWord ${LPSPI_TCR} 0x7
    Execute Command             flexcomm0 WriteDoubleWord ${LPSPI_TDR} 0xA5

    Wait For Log Entry          Data received: 0xA5
    Signal Should Be            flexcomm0 IRQ  True
    ${status}=                  Execute Command  flexcomm0 ReadDoubleWord ${FLEXCOMM_STAT}
    GPIO Should Have Bit Set    ${status.strip()}  2
    Execute Command             flexcomm0 WriteDoubleWord ${LPSPI_SR} 0x400
    Signal Should Be            flexcomm0 IRQ  False

Should Transfer Data Over I2C To Echo Device
    Execute Command             machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ flexcomm1 0x55"

    Set Flexcomm Mode           flexcomm1  0x3
    Execute Command             flexcomm1 WriteDoubleWord ${LPI2C_MCR} 0x1
    Execute Command             flexcomm1 WriteDoubleWord ${LPI2C_MIER} 0x1
    Signal Should Be            flexcomm1 IRQ  True
    ${status}=                  Execute Command  flexcomm1 ReadDoubleWord ${FLEXCOMM_STAT}
    GPIO Should Have Bit Set    ${status.strip()}  4
    Execute Command             flexcomm1 WriteDoubleWord ${LPI2C_MIER} 0x0
    Signal Should Be            flexcomm1 IRQ  False
    Execute Command             flexcomm1 WriteDoubleWord ${LPI2C_MTDR} 0x4AA
    Execute Command             flexcomm1 WriteDoubleWord ${LPI2C_MTDR} 0x23
    Execute Command             flexcomm1 WriteDoubleWord ${LPI2C_MTDR} 0x200
    Execute Command             flexcomm1 WriteDoubleWord ${LPI2C_MTDR} 0x4AB
    Execute Command             flexcomm1 WriteDoubleWord ${LPI2C_MTDR} 0x100

    ${readback}=                Execute Command  flexcomm1 ReadDoubleWord ${LPI2C_MRDR}
    ${data}=                    Evaluate  int(${readback}) & 0xFF
    Should Be Equal As Integers  ${data}  0x23

Should Raise WWDT Warning IRQ And Clear It After A Valid Feed
    Halt CPUs
    Configure WWDT Warning Window  wwdt0
    Enable WWDT                 wwdt0

    Execute Command             emulation RunFor "1"
    Signal Should Be            wwdt0 IRQ  True

    Feed WWDT                   wwdt0
    Execute Command             wwdt0 WriteDoubleWord ${WWDT_MOD} 0x8
    Signal Should Be            wwdt0 IRQ  False

Should Reset The Machine When WWDT Expires With Reset Enabled
    Halt CPUs
    Execute Command             gpio0 WriteDoubleWordToGPIO ${GPIO_PDDR} 0x1
    Configure WWDT Warning Window  wwdt1
    Enable WWDT                 wwdt1  with_reset=${True}

    Execute Command             emulation RunFor "2"

    ${pddr_after_reset}=        Execute Command  gpio0 ReadDoubleWordFromGPIO ${GPIO_PDDR}
    Should Be Equal As Integers  ${pddr_after_reset.strip()}  0x0

Should Raise CDOG Fault Injection IRQs And Reset On Configured Timeout Fault
    Halt CPUs
    # CONTROL: unlocked, timeout->reset, miscompare->IRQ, sequence->IRQ.
    Execute Command             cdog0 WriteDoubleWord 0x0 0x246
    Execute Command             cdog0 InjectMiscompareFault
    Signal Should Be            cdog0 IRQ  True
    Execute Command             cdog0 WriteDoubleWord 0x18 0x2
    Signal Should Be            cdog0 IRQ  False

    Execute Command             cdog0 InjectIllegalSequenceFault
    Signal Should Be            cdog0 IRQ  True
    Execute Command             cdog0 WriteDoubleWord 0x18 0x4
    Signal Should Be            cdog0 IRQ  False

    Execute Command             gpio0 WriteDoubleWordToGPIO ${GPIO_PDDR} 0x1
    Execute Command             cdog0 InjectTimeoutFault
    Execute Command             emulation RunFor "0.001"
    ${after_fault_reset}=       Execute Command  gpio0 ReadDoubleWordFromGPIO ${GPIO_PDDR}
    Should Be Equal As Integers  ${after_fault_reset.strip()}  0x0
    ${flags_after_reset}=       Execute Command  cdog0 ReadDoubleWord 0x18
    GPIO Should Have Bit Set    ${flags_after_reset.strip()}  0
    Signal Should Be            cdog0 IRQ  False
