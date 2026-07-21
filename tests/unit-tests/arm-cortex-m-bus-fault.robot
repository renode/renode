*** Variables ***
${CODE_ADDRESS}                     ${0x200}
${BUSFAULT_HANDLER_ADDRESS}         ${0x300}
${HARDFAULT_HANDLER_ADDRESS}        ${0x340}
${STACK_TOP}                        0x1000
${STACKED_R1_ADDRESS}               0xFE4
${STACKED_R2_ADDRESS}               0xFE8
${STACKED_PC_ADDRESS}               0xFF8
${NESTED_STACKED_PC_ADDRESS}        0xFD8
${FAULTING_PERIPHERAL_ADDRESS}      0x100000
${UNMAPPED_ADDRESS}                 0x200000
${R1_BEFORE_FAULT}                  0x11
${R1_AFTER_FAULT}                   0x22
${R2_BEFORE_FAULT}                  0xA5A5A5A5

${SCB_SHCSR}                        0xE000ED24
${SCB_AIRCR}                        0xE000ED0C
${SCB_CFSR}                         0xE000ED28
${SCB_CFSR_NS}                      0xE002ED28
${SCB_HFSR}                         0xE000ED2C
${SCB_BFAR}                         0xE000ED38
${SCB_BFAR_NS}                      0xE002ED38
${SCB_CCR}                          0xE000ED14
${SHCSR_BUSFAULTENA}                0x00020000
${AIRCR_VECTKEY_BFHFNMINS}          0x05FA2000
${CFSR_PRECISERR_BFARVALID}         0x00008200
${HFSR_FORCED}                      0x40000000
${CCR_BFHFNMIGN}                    0x00000100

${PLATFORM}                         SEPARATOR=\n
...                                 """
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x1000
...
...                                 nvic: IRQControllers.NVIC @ sysbus 0xE000E000
...                                 ${SPACE*4}-> cpu@0
...
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m33"
...                                 ${SPACE*4}nvic: nvic
...
...                                 faultingPeripheral: Mocks.BusFaultingPeripheral @ sysbus ${FAULTING_PERIPHERAL_ADDRESS}
...                                 """

${TRUSTZONE_PLATFORM}               SEPARATOR=\n
...                                 """
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x1000
...
...                                 nvic: IRQControllers.NVIC @ {
...                                 ${SPACE*8}sysbus 0xE000E000;
...                                 ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0xE002E000; size: 0x1000; region: "NonSecure" }
...                                 ${SPACE*4}}
...                                 ${SPACE*4}-> cpu@0
...
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m33"
...                                 ${SPACE*4}nvic: nvic
...                                 ${SPACE*4}enableTrustZone: true
...
...                                 faultingPeripheral: Mocks.BusFaultingPeripheral @ sysbus ${FAULTING_PERIPHERAL_ADDRESS}
...                                 """

${READ_ASSEMBLY}                    SEPARATOR=\n
...                                 """
...                                 ldr r2, [r0]
...                                 movs r1, #${R1_AFTER_FAULT}
...                                 b .
...                                 """

${WRITE_ASSEMBLY}                   SEPARATOR=\n
...                                 """
...                                 str r2, [r0]
...                                 movs r1, #${R1_AFTER_FAULT}
...                                 b .
...                                 """

${E2E_READ_ASSEMBLY}                SEPARATOR=\n
...                                 """
...                                 Vector_Table:
...                                 .word ${STACK_TOP} /* initial SP */
...                                 .word Reset_Handler+1 /* Reset vector */
...                                 .word 0 /* NMI */
...                                 .word 0 /* HardFault */
...                                 .word 0 /* MemManage */
...                                 .word BusFault_Handler+1 /* BusFault vector */
...                                 .align 8
...
...                                 Reset_Handler:
...                                 ldr r1, =${SCB_SHCSR}
...                                 ldr r2, [r1]
...                                 orr r2, r2, #(1 << 17) /* BUSFAULTENA */
...                                 str r2, [r1]
...                                 ldr r0, =${FAULTING_PERIPHERAL_ADDRESS}
...                                 adr r10, fault_instr
...                                 fault_instr:
...                                 ldr r3, [r0]
...                                 mov r10, #0
...                                 1: wfi
...                                 b 1b
...
...                                 BusFault_Handler:
...                                 ldr r11, [sp, #24] /* stacked PC */
...                                 1: wfi
...                                 b 1b
...                                 """

${E2E_WRITE_ASSEMBLY}               SEPARATOR=\n
...                                 """
...                                 Vector_Table:
...                                 .word ${STACK_TOP} /* initial SP */
...                                 .word Reset_Handler+1 /* Reset vector */
...                                 .word 0 /* NMI */
...                                 .word 0 /* HardFault */
...                                 .word 0 /* MemManage */
...                                 .word BusFault_Handler+1 /* BusFault vector */
...                                 .align 8
...
...                                 Reset_Handler:
...                                 ldr r1, =${SCB_SHCSR}
...                                 ldr r2, [r1]
...                                 orr r2, r2, #(1 << 17) /* BUSFAULTENA */
...                                 str r2, [r1]
...                                 ldr r0, =${FAULTING_PERIPHERAL_ADDRESS}
...                                 adr r10, fault_instr
...                                 fault_instr:
...                                 str r3, [r0]
...                                 mov r10, #0
...                                 1: wfi
...                                 b 1b
...
...                                 BusFault_Handler:
...                                 ldr r11, [sp, #24] /* stacked PC */
...                                 1: wfi
...                                 b 1b
...                                 """

*** Keywords ***
Create Bare Machine
    Execute Command                 include "${CURDIR}/BusFaultingPeripheral.cs"
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}

Create Machine
    Create Bare Machine

    # Cortex-M vector 3 is HardFault and vector 5 is BusFault.
    Execute Command                 sysbus WriteDoubleWord 0xC ${{$HARDFAULT_HANDLER_ADDRESS | 1}}  # Thumb bit
    Execute Command                 sysbus WriteDoubleWord 0x14 ${{$BUSFAULT_HANDLER_ADDRESS | 1}}
    Execute Command                 cpu AssembleBlock ${BUSFAULT_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} "b ."

Create TrustZone Machine
    Execute Command                 include "${CURDIR}/BusFaultingPeripheral.cs"
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${TRUSTZONE_PLATFORM}
    Execute Command                 sysbus WriteDoubleWord 0xC ${{$HARDFAULT_HANDLER_ADDRESS | 1}}
    Execute Command                 sysbus WriteDoubleWord 0x14 ${{$BUSFAULT_HANDLER_ADDRESS | 1}}
    Execute Command                 cpu AssembleBlock ${BUSFAULT_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} "b ."

Prepare Faulting Instruction
    [Arguments]                     ${assembly}  ${fault_address}
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} ${assembly}
    Execute Command                 cpu SP ${STACK_TOP}
    Execute Command                 cpu SetRegister "R0" ${fault_address}
    Execute Command                 cpu SetRegister "R1" ${R1_BEFORE_FAULT}
    Execute Command                 cpu SetRegister "R2" ${R2_BEFORE_FAULT}
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}

Enable BusFault
    Execute Command                 sysbus WriteDoubleWord ${SCB_SHCSR} ${SHCSR_BUSFAULTENA} context=cpu

Execute Faulting Instruction
    Execute Command                 cpu Step 1

Fault Should Be Precise
    [Arguments]                     ${handler_address}  ${fault_address}  ${expected_hfsr}=0
    Register Should Be Equal        PC  ${handler_address}

    # Neither the faulting load nor the instruction following the failed
    # access may modify architectural state before the exception is taken.
    Register Should Be Equal        1  ${R1_BEFORE_FAULT}
    Register Should Be Equal        2  ${R2_BEFORE_FAULT}

    ${stacked_r1}=                  Execute Command  sysbus ReadDoubleWord ${STACKED_R1_ADDRESS}
    ${stacked_r2}=                  Execute Command  sysbus ReadDoubleWord ${STACKED_R2_ADDRESS}
    ${stacked_pc}=                  Execute Command  sysbus ReadDoubleWord ${STACKED_PC_ADDRESS}
    Should Be Equal As Integers     ${stacked_r1}  ${R1_BEFORE_FAULT}
    Should Be Equal As Integers     ${stacked_r2}  ${R2_BEFORE_FAULT}
    Should Be Equal As Integers     ${stacked_pc}  ${CODE_ADDRESS}

    ${cfsr}=                        Execute Command  sysbus ReadDoubleWord ${SCB_CFSR} context=cpu
    ${bfar}=                        Execute Command  sysbus ReadDoubleWord ${SCB_BFAR} context=cpu
    ${hfsr}=                        Execute Command  sysbus ReadDoubleWord ${SCB_HFSR} context=cpu
    Should Be Equal As Integers     ${cfsr}  ${CFSR_PRECISERR_BFARVALID}
    Should Be Equal As Integers     ${bfar}  ${fault_address}
    Should Be Equal As Integers     ${hfsr}  ${expected_hfsr}

Run Precise BusFault Test Without Single Step
    [Arguments]                     ${assembly}
    Create Bare Machine
    Execute Command                 cpu AssembleBlock 0x0 ${assembly}
    Execute Command                 cpu VectorTableOffset 0x0
    Execute Command                 cpu Step 100

    ${expected_pc}=                 Execute Command  cpu GetRegister "R10"
    ${stacked_pc}=                  Execute Command  cpu GetRegister "R11"
    Should Not Be Equal As Numbers  ${expected_pc}  0
    ...                             msg=Fault was not taken synchronously: R10 was overwritten to 0
    Should Be Equal As Numbers      ${stacked_pc}  ${expected_pc}
    ...                             msg=Stacked PC (R11=${stacked_pc}) does not match faulting instruction address (R10=${expected_pc})

    ${cfsr}=                        Execute Command  sysbus ReadDoubleWord ${SCB_CFSR} context=cpu
    ${bfar}=                        Execute Command  sysbus ReadDoubleWord ${SCB_BFAR} context=cpu
    Should Be Equal As Integers     ${cfsr}  ${CFSR_PRECISERR_BFARVALID}
    Should Be Equal As Integers     ${bfar}  ${FAULTING_PERIPHERAL_ADDRESS}

*** Test Cases ***
Should Raise Precise BusFault On Peripheral Read
    Create Machine
    Enable BusFault
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}
    Execute Faulting Instruction
    Fault Should Be Precise         ${BUSFAULT_HANDLER_ADDRESS}  ${FAULTING_PERIPHERAL_ADDRESS}

Should Raise Precise BusFault On Peripheral Write
    Create Machine
    Enable BusFault
    Prepare Faulting Instruction    ${WRITE_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}
    Execute Faulting Instruction
    Fault Should Be Precise         ${BUSFAULT_HANDLER_ADDRESS}  ${FAULTING_PERIPHERAL_ADDRESS}

Should Raise Precise BusFault On Unmapped Read When Configured
    Create Machine
    Execute Command                 sysbus UnhandledAccessBehaviour ThrowException
    Enable BusFault
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${UNMAPPED_ADDRESS}
    Execute Faulting Instruction
    Fault Should Be Precise         ${BUSFAULT_HANDLER_ADDRESS}  ${UNMAPPED_ADDRESS}

Should Escalate Disabled BusFault To HardFault
    Create Machine
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}
    Execute Faulting Instruction
    Fault Should Be Precise         ${HARDFAULT_HANDLER_ADDRESS}  ${FAULTING_PERIPHERAL_ADDRESS}  ${HFSR_FORCED}
    Execute Command                 sysbus WriteDoubleWord ${SCB_HFSR} ${HFSR_FORCED} context=cpu
    ${hfsr}=                        Execute Command  sysbus ReadDoubleWord ${SCB_HFSR} context=cpu
    Should Be Equal As Integers     ${hfsr}  0

Should Escalate BusFault That Cannot Preempt Active Handler
    Create Machine
    Enable BusFault
    Execute Command                 cpu AssembleBlock ${BUSFAULT_HANDLER_ADDRESS} ${READ_ASSEMBLY}
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}
    # The BusFault handler itself repeats the access at the same priority.
    # A synchronous fault cannot remain pending, so the single step
    # reaches HardFault through both precise faults.
    Execute Faulting Instruction
    Register Should Be Equal        PC  ${HARDFAULT_HANDLER_ADDRESS}
    Register Should Be Equal        1  ${R1_BEFORE_FAULT}
    Register Should Be Equal        2  ${R2_BEFORE_FAULT}
    ${stacked_pc}=                  Execute Command  sysbus ReadDoubleWord ${NESTED_STACKED_PC_ADDRESS}
    ${cfsr}=                        Execute Command  sysbus ReadDoubleWord ${SCB_CFSR} context=cpu
    ${bfar}=                        Execute Command  sysbus ReadDoubleWord ${SCB_BFAR} context=cpu
    ${hfsr}=                        Execute Command  sysbus ReadDoubleWord ${SCB_HFSR} context=cpu
    Should Be Equal As Integers     ${stacked_pc}  ${BUSFAULT_HANDLER_ADDRESS}
    Should Be Equal As Integers     ${cfsr}  ${CFSR_PRECISERR_BFARVALID}
    Should Be Equal As Integers     ${bfar}  ${FAULTING_PERIPHERAL_ADDRESS}
    Should Be Equal As Integers     ${hfsr}  ${HFSR_FORCED}

Should Ignore Precise BusFault In HardFault When Configured
    Create Machine
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} ${READ_ASSEMBLY}
    Execute Command                 sysbus WriteDoubleWord ${SCB_CCR} ${CCR_BFHFNMIGN} context=cpu
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}

    # E2.1.294 MemA_with_priv_security: the Thread mode access still escalates
    # to HardFault, while the repeated access in its handler records the
    # syndrome, but is ignored, because its requested priority is negative.
    Execute Faulting Instruction
    Register Should Be Equal        1  ${R1_BEFORE_FAULT}
    Execute Command                 cpu Step 1
    Register Should Be Equal        1  ${R1_AFTER_FAULT}
    ${cfsr}=                        Execute Command  sysbus ReadDoubleWord ${SCB_CFSR} context=cpu
    ${bfar}=                        Execute Command  sysbus ReadDoubleWord ${SCB_BFAR} context=cpu
    ${hfsr}=                        Execute Command  sysbus ReadDoubleWord ${SCB_HFSR} context=cpu
    Should Be Equal As Integers     ${cfsr}  ${CFSR_PRECISERR_BFARVALID}
    Should Be Equal As Integers     ${bfar}  ${FAULTING_PERIPHERAL_ADDRESS}
    Should Be Equal As Integers     ${hfsr}  ${HFSR_FORCED}

Should Share BusFault State Across Security States
    Create TrustZone Machine
    Enable BusFault
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}
    Execute Faulting Instruction
    Fault Should Be Precise         ${BUSFAULT_HANDLER_ADDRESS}  ${FAULTING_PERIPHERAL_ADDRESS}

    ${secure_state}=                Execute Command  cpu SecureState
    Should Be Equal                 ${secure_state}  True  strip_spaces=True
    ${cfsr_ns}=                     Execute Command  sysbus ReadDoubleWord ${SCB_CFSR_NS} context=cpu
    ${bfar_ns}=                     Execute Command  sysbus ReadDoubleWord ${SCB_BFAR_NS} context=cpu
    Should Be Equal As Integers     ${cfsr_ns}  0
    Should Be Equal As Integers     ${bfar_ns}  0

    # BFSR and BFAR are not banked. Once BFHFNMINS retargets BusFault to
    # Non-secure, its aliases expose the syndrome captured by the Secure fault.
    Execute Command                 sysbus WriteDoubleWord ${SCB_AIRCR} ${AIRCR_VECTKEY_BFHFNMINS} context=cpu
    ${cfsr_ns}=                     Execute Command  sysbus ReadDoubleWord ${SCB_CFSR_NS} context=cpu
    ${bfar_ns}=                     Execute Command  sysbus ReadDoubleWord ${SCB_BFAR_NS} context=cpu
    Should Be Equal As Integers     ${cfsr_ns}  ${CFSR_PRECISERR_BFARVALID}
    Should Be Equal As Integers     ${bfar_ns}  ${FAULTING_PERIPHERAL_ADDRESS}

Read Access Should Produce Precise Bus Fault Without Single Step
    Run Precise BusFault Test Without Single Step  ${E2E_READ_ASSEMBLY}

Write Access Should Produce Precise Bus Fault Without Single Step
    Run Precise BusFault Test Without Single Step  ${E2E_WRITE_ASSEMBLY}
