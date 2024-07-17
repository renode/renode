*** Variables ***
${CPU_COUNT}                        4
${INIT_PERIPHBASE_ADDRESS}          0xAE000000
${INIT_PERIPHBASE}                  0x57000
${NEW_PERIPHBASE_ADDRESS}           0x80000000
${NEW_PERIPHBASE}                   0x40000
${SIGNALS_UNIT}                     signalsUnit

${GIC_MODEL}                        Antmicro.Renode.Peripherals.IRQControllers.ARM_GenericInterruptController
${PRIVATE_TIMER_MODEL}              Antmicro.Renode.Peripherals.Timers.ARM_PrivateTimer
${SCU_MODEL}                        Antmicro.Renode.Peripherals.Miscellaneous.ArmSnoopControlUnit

*** Keywords ***
Verify Command Output As Integer
    [Arguments]  ${expected}  ${command}

    ${output}=  Execute Command      ${command}
    Should Be Equal As Integers      ${expected}  ${output}  base=16

Verify Command Output
    [Arguments]  ${expected}  ${command}

    ${output}=  Execute Command      ${command}
    Should Be Equal                  ${expected}  ${output}  strip_spaces=True

Verify PERIPHBASE Init Value
    Verify Command Output As Integer         ${INIT_PERIPHBASE_ADDRESS}  ${SIGNALS_UNIT} GetAddress "PERIPHBASE"

Verify Peripherals Registered At
    [Arguments]  ${address}

    FOR  ${i}  IN RANGE  ${CPU_COUNT}
        Verify Command Output
        ...    ${SCU_MODEL}    sysbus WhatPeripheralIsAt ${address} cpu${i}
        Verify Command Output
        ...    ${GIC_MODEL}    sysbus WhatPeripheralIsAt ${${address} + 0x100} cpu${i}  # CPU interface
        Verify Command Output
        ...    ${GIC_MODEL}    sysbus WhatPeripheralIsAt ${${address} + 0x1000} cpu${i}  # distributor
        Verify Command Output
        ...    ${PRIVATE_TIMER_MODEL}    sysbus WhatPeripheralIsAt ${${address} + 0x600} cpu${i}
    END

Verify PCs
    [Arguments]  ${cpu0_pc_expected}  ${cpu1_pc_expected}

    Verify Command Output As Integer  ${cpu0_pc_expected}  cpu0 PC
    Verify Command Output As Integer  ${cpu1_pc_expected}  cpu1 PC

*** Test Cases ***
Create Machine
    Execute Command    using sysbus
    Execute Command    mach create
    Execute Command    machine LoadPlatformDescription @platforms/cpus/cortex-r8_smp.repl

    Provides           created-machine

Should Gracefully Handle Invalid Signal
    Requires                      created-machine

    # All available signals should be printed with both names when the given signal can't be found.
    # Let's just check if two example signals are included: INITRAM and PERIPHBASE.
    Run Keyword And Expect Error  *No such signal: ''\nAvailable signals are:*INITRAM (InitializeInstructionTCM)*
    ...    Execute Command    ${SIGNALS_UNIT} GetSignal ""
    Run Keyword And Expect Error  *No such signal: 'INVALID'\nAvailable signals are:*PERIPHBASE (PeripheralsBase)*
    ...    Execute Command    ${SIGNALS_UNIT} GetSignal "INVALID"

Should Handle Addresses
    Requires                      created-machine

    Verify PERIPHBASE Init Value

    Execute Command                          ${SIGNALS_UNIT} SetSignalFromAddress "PERIPHBASE" ${NEW_PERIPHBASE_ADDRESS}
    Verify Command Output As Integer         ${NEW_PERIPHBASE_ADDRESS}  ${SIGNALS_UNIT} GetAddress "PERIPHBASE"

    # When set from address, the signal is set to a value based on address' top bits.
    Verify Command Output As Integer         ${NEW_PERIPHBASE}  ${SIGNALS_UNIT} GetSignal "PERIPHBASE"

Should Modify Peripheral Registration
    Requires                                 created-machine

    Verify Command Output As Integer         0x0                 cpu0 GetSystemRegisterValue "CBAR"
    Verify Command Output As Integer         ${INIT_PERIPHBASE}  ${SIGNALS_UNIT} GetSignal "PERIPHBASE"

    Verify Peripherals Registered At         ${INIT_PERIPHBASE_ADDRESS}

    Execute Command                          emulation RunFor '0.0001'
    FOR  ${i}  IN RANGE  ${CPU_COUNT}
        # SCU address is based on PERIPHBASE with zero offset.
        Verify Command Output As Integer
        ...    ${INIT_PERIPHBASE_ADDRESS}    cpu${i} GetSystemRegisterValue "CBAR"
    END

    Execute Command                          ${SIGNALS_UNIT} SetSignalFromAddress "PERIPHBASE" ${NEW_PERIPHBASE_ADDRESS}

    # Nothing changes before exitting from reset.
    Verify Command Output    ${SCU_MODEL}    sysbus WhatPeripheralIsAt ${INIT_PERIPHBASE_ADDRESS}
    Verify Command Output As Integer
        ...    ${INIT_PERIPHBASE_ADDRESS}    cpu1 GetSystemRegisterValue "CBAR"

    # Let's make sure the behavior is preserved across serialization.
    ${f}=                                    Allocate Temporary File
    Execute Command                          Save @${f}
    Execute Command                          Clear
    Execute Command                          Load @${f}
    Execute Command                          mach set 0

    FOR  ${i}  IN RANGE  ${CPU_COUNT}
        Execute Command    cpu${i} Reset
    END
    Execute Command                          emulation RunFor '0.0001'

    FOR  ${i}  IN RANGE  ${CPU_COUNT}
        Verify Command Output As Integer     ${NEW_PERIPHBASE_ADDRESS}  cpu${i} GetSystemRegisterValue "CBAR"
    END

    Verify Peripherals Registered At         ${NEW_PERIPHBASE_ADDRESS}

Should Set PC For Cores With INITRAM And VINITHI High
    Requires           created-machine

    Execute Command    cpu0 ExecutionMode SingleStep
    Execute Command    cpu1 ExecutionMode SingleStep

    # Both signals will be high only for cpu0.
    Execute Command    ${SIGNALS_UNIT} SetSignalStateForCPU "INITRAM" true cpu0
    Execute Command    ${SIGNALS_UNIT} SetSignalStateForCPU "INITRAM" true cpu1
    Execute Command    ${SIGNALS_UNIT} SetSignalStateForCPU "VINITHI" true cpu0
    Execute Command    ${SIGNALS_UNIT} SetSignalStateForCPU "VINITHI" false cpu1

    Verify PCs         0x0  0x0

    Start Emulation
    Verify PCs         0xFFFF0000  0x0

    Execute Command    cpu0 PC 0x12345678
    Execute Command    cpu1 PC 0x90ABCDE0

    # PCs are set immediately because machine is started right after Reset if it was started before.
    Execute Command    machine Reset
    Verify PCs         0xFFFF0000  0x0

    # Now both signals will be high only for cpu1.
    # Setting signals shouldn't influence PCs before starting-after-reset.
    Execute Command    ${SIGNALS_UNIT} SetSignalStateForCPU "VINITHI" false cpu0
    Execute Command    ${SIGNALS_UNIT} SetSignalStateForCPU "VINITHI" true cpu1
    Verify PCs         0xFFFF0000  0x0

    Execute Command    cpu0 Reset
    Execute Command    cpu1 Reset
    Verify PCs         0x0  0x0

    Execute Command    cpu0 Start
    Execute Command    cpu1 Start
    Verify PCs         0x0  0xFFFF0000

Verify PERIPHBASE Init Value With CPU-specific SCU Registrations
    Execute Command               using sysbus
    Execute Command               mach create

    ${PLATFORM}=  Catenate     SEPARATOR=\n
    ...  signalsUnit: Miscellaneous.ArmSignalsUnit @ sysbus
    ...  
    ...  cpu0: CPU.ARMv7R @ sysbus
    ...  ${SPACE*4}cpuType: "cortex-r8"
    ...  ${SPACE*4}cpuId: 0
    ...  ${SPACE*4}signalsUnit: signalsUnit
    ...  
    ...  cpu1: CPU.ARMv7R @ sysbus
    ...  ${SPACE*4}cpuType: "cortex-r8"
    ...  ${SPACE*4}cpuId: 1
    ...  ${SPACE*4}signalsUnit: signalsUnit
    ...
    ...  scu: Miscellaneous.ArmSnoopControlUnit @ {
    ...  ${SPACE*4}sysbus new Bus.BusPointRegistration { address: 0xae000000; cpu: cpu0 };
    ...  ${SPACE*4}sysbus new Bus.BusPointRegistration { address: 0xae000000; cpu: cpu1 }
    ...  }
    Execute Command               machine LoadPlatformDescriptionFromString """${PLATFORM}"""

    Verify PERIPHBASE Init Value