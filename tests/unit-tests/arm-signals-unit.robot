*** Variables ***
${CPU_COUNT}                        4
${INIT_PERIPHBASE_ADDRESS}          0xAE000000
${INIT_PERIPHBASE}                  0x57000
${SIGNALS_UNIT}                     cpu0 SignalsUnit  # It doesn't matter through which CPU the unit is accessed.

${GIC_MODEL}                        Antmicro.Renode.Peripherals.IRQControllers.ARM_GenericInterruptController
${PRIVATE_TIMER_MODEL}              Antmicro.Renode.Peripherals.Timers.ARM_PrivateTimer
${SCU_MODEL}                        Antmicro.Renode.Peripherals.Miscellaneous.ArmSnoopControlUnit

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/cortex-r8_smp.repl

Verify Command Output As Integer
    [Arguments]  ${expected}  ${command}

    ${output}=  Execute Command      ${command}
    Should Be Equal As Integers      ${expected}  ${output}

Verify Command Output
    [Arguments]  ${expected}  ${command}

    ${output}=  Execute Command      ${command}
    Should Be Equal                  ${expected}  ${output}  strip_spaces=True

Verify Peripherals Registered At
    [Arguments]  ${address}

    Verify Command Output
    ...    ${SCU_MODEL}    sysbus WhatPeripheralIsAt ${address}
    Verify Command Output
    ...    ${GIC_MODEL}    sysbus WhatPeripheralIsAt ${${address} + 0x100}  # CPU interface
    Verify Command Output
    ...    ${GIC_MODEL}    sysbus WhatPeripheralIsAt ${${address} + 0x1000}  # distributor

    # Each core has its own private timer
    FOR  ${i}  IN RANGE  ${CPU_COUNT}
        Verify Command Output
        ...    ${PRIVATE_TIMER_MODEL}    sysbus WhatPeripheralIsAt ${${address} + 0x600} cpu${i}
    END

Verify PCs
    [Arguments]  ${cpu0_pc_expected}  ${cpu1_pc_expected}

    Verify Command Output As Integer  ${cpu0_pc_expected}  cpu0 PC
    Verify Command Output As Integer  ${cpu1_pc_expected}  cpu1 PC

*** Test Cases ***
Should Set PC For Cores With INITRAM And VINITHI High
    Create Machine

    Execute Command    cpu0 ExecutionMode SingleStepBlocking
    Execute Command    cpu1 ExecutionMode SingleStepBlocking

    # Both signals are high only for cpu0.
    Execute Command    ${SIGNALS_UNIT} SetSignal "INITRAM" 3
    Execute Command    ${SIGNALS_UNIT} SetSignal "VINITHI" 1

    Verify PCs         0x0  0x0

    Start Emulation
    Verify PCs         0xFFFF0000  0x0

    # If paused before the reset, PC gets set after start.
    Execute Command    pause
    Execute Command    machine Reset
    Verify PCs         0x0  0x0

    Start Emulation
    Verify PCs         0xFFFF0000  0x0

    Execute Command    cpu0 PC 0xCAFEBEE0
    Execute Command    cpu1 PC 0xCAFEBEE4
    Verify PCs         0xCAFEBEE0  0xCAFEBEE4

    # Now both signals are high only for cpu1
    Execute Command    ${SIGNALS_UNIT} SetSignal "VINITHI" 2
    Verify PCs         0xCAFEBEE0  0xCAFEBEE4

    # Without pausing the PCs are set right after resetting.
    Execute Command    machine Reset
    Verify PCs         0x0  0xFFFF0000

Should Modify Peripheral Registration
    Create Machine

    Verify Command Output As Integer         0x0                 cpu0 GetSystemRegisterValue "CBAR"
    Verify Command Output As Integer         ${INIT_PERIPHBASE}  ${SIGNALS_UNIT} GetSignal "PERIPHBASE"

    Verify Peripherals Registered At         ${INIT_PERIPHBASE_ADDRESS}

    Execute Command                          emulation RunFor '0.0001'
    FOR  ${i}  IN RANGE  ${CPU_COUNT}
        Execute Command  cpu${i} Resume
        # SCU address is based on PERIPHBASE with zero offset.
        Verify Command Output As Integer
        ...    ${INIT_PERIPHBASE_ADDRESS}    cpu${i} GetSystemRegisterValue "CBAR"
    END

    # These are top 19 bits which translates to the address 0x8000_0000.
    Execute Command                          ${SIGNALS_UNIT} SetSignal "PERIPHBASE" 0x40000

    # Nothing changes before exitting from reset.
    Verify Command Output    ${SCU_MODEL}    sysbus WhatPeripheralIsAt ${INIT_PERIPHBASE_ADDRESS}
    Verify Command Output As Integer
        ...    ${INIT_PERIPHBASE_ADDRESS}    cpu1 GetSystemRegisterValue "CBAR"

    Execute Command                          machine Reset
    Execute Command                          emulation RunFor '0.0001'
    FOR  ${i}  IN RANGE  ${CPU_COUNT}
        Verify Command Output As Integer     0x80000000  cpu${i} GetSystemRegisterValue "CBAR"
    END

    Verify Peripherals Registered At         0x80000000
