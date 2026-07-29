*** Variables ***
${CODE_ADDRESS}                     ${0x200}
${BUSFAULT_HANDLER_ADDRESS}         ${0x300}
${HARDFAULT_HANDLER_ADDRESS}        ${0x340}
${NMI_HANDLER_ADDRESS}              ${0x380}
${EXTERNAL_HANDLER_ADDRESS}         ${0x3C0}
${NS_NMI_HANDLER_ADDRESS}           ${0x10000}
${LOCKUP_PC}                        0xEFFFFFFE
${STACK_TOP}                        0x1000
${STACKED_R1_ADDRESS}               0xFE4
${STACKED_R2_ADDRESS}               0xFE8
${STACKED_PC_ADDRESS}               0xFF8
${NESTED_STACKED_PC_ADDRESS}        0xFD8
${FAULTING_PERIPHERAL_ADDRESS}      0x100000
${FAULTING_HARDFAULT_VECTOR}        0x10000C
${UNMAPPED_ADDRESS}                 0x200000
${R1_BEFORE_FAULT}                  0x11
${R1_AFTER_FAULT}                   0x22
${R2_BEFORE_FAULT}                  0xA5A5A5A5

${SCB_SHCSR}                        0xE000ED24
${SCB_ICSR}                         0xE000ED04
${SCB_AIRCR}                        0xE000ED0C
${SCB_CFSR}                         0xE000ED28
${SCB_CFSR_NS}                      0xE002ED28
${SCB_HFSR}                         0xE000ED2C
${SCB_BFAR}                         0xE000ED38
${SCB_BFAR_NS}                      0xE002ED38
${SCB_CCR}                          0xE000ED14
${SCB_SFSR}                         0xE000EDE4
${SCB_CPACR}                        0xE000ED88
${SCB_FPCCR}                        0xE000EF34
${SCB_FPCAR}                        0xE000EF38
${NVIC_ISPR0}                       0xE000E200
${NVIC_IABR0}                       0xE000E300
${NVIC_ITNS0}                       0xE000E380
${SHCSR_BUSFAULTENA}                ${{1<<17}}
${SHCSR_BUSFAULTACT}                ${{1<<1}}
${SHCSR_BUSFAULTPENDED}             ${{1<<14}}
${AIRCR_VECTKEY_BFHFNMINS}          0x05FA2000
${CFSR_PRECISERR_BFARVALID}         ${{(1<<9) | (1<<15)}}
${CFSR_UNSTKERR}                    ${{1<<11}}
${CFSR_STKERR}                      ${{1<<12}}
${CFSR_LSPERR}                      ${{1<<13}}
${CFSR_INVPC}                       ${{1<<18}}
${HFSR_VECTTBL}                     ${{1<<1}}
${HFSR_FORCED}                      ${{1<<30}}
${CCR_BFHFNMIGN}                    ${{1<<8}}
${SHCSR_HARDFAULTACT}               ${{1<<2}}
${SHCSR_NMIACT}                     ${{1<<5}}
${SHCSR_HARDFAULTACT_NMIACT}        ${{(1<<2) | (1<<5)}}
${SHCSR_HARDFAULTPENDED}            ${{1<<21}}
${EXC_RETURN_THREAD_MSP}            0xFFFFFFB8
${SFSR_INVIS}                       ${{1<<1}}
${SFSR_INVER}                       ${{1<<2}}
${FPCCR_LSPACT}                     ${{1<<0}}
${FPCCR_HFRDY}                      ${{1<<4}}
${FPCCR_TS}                         ${{1<<26}}
${CPACR_CP10_CP11_FULL_ACCESS}      0x00F00000

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

${LOCKUP_ASSEMBLY}                  SEPARATOR=\n
...                                 """
...                                 ldr r3, =${SCB_HFSR}
...                                 ldr r4, =${HFSR_FORCED}
...                                 str r4, [r3] /* clear HFSR.FORCED before the second fault */
...                                 cmp r5, #0
...                                 itt eq
...                                 ldreq r2, [r0]
...                                 moveq r1, #${R1_AFTER_FAULT}
...                                 b .
...                                 """

${IT_ASSEMBLY}                      SEPARATOR=\n
...                                 """
...                                 cmp r5, #0
...                                 itt eq
...                                 moveq r1, #1
...                                 moveq r2, #2
...                                 b .
...                                 """

${UNSTACK_FAULT_ASSEMBLY}           SEPARATOR=\n
...                                 """
...                                 ldr r0, =${FAULTING_PERIPHERAL_ADDRESS}
...                                 msr msp, r0
...                                 bx lr
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
    Execute Command                 sysbus WriteDoubleWord 0x8 ${{$NMI_HANDLER_ADDRESS | 1}}
    Execute Command                 sysbus WriteDoubleWord 0xC ${{$HARDFAULT_HANDLER_ADDRESS | 1}}  # Thumb bit
    Execute Command                 sysbus WriteDoubleWord 0x14 ${{$BUSFAULT_HANDLER_ADDRESS | 1}}
    Execute Command                 sysbus WriteDoubleWord 0x40 ${{$EXTERNAL_HANDLER_ADDRESS | 1}}
    Execute Command                 cpu AssembleBlock ${NMI_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${BUSFAULT_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${EXTERNAL_HANDLER_ADDRESS} "b ."

Create TrustZone Machine
    Execute Command                 include "${CURDIR}/BusFaultingPeripheral.cs"
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${TRUSTZONE_PLATFORM}
    Execute Command                 sysbus WriteDoubleWord 0x8 ${{$NMI_HANDLER_ADDRESS | 1}}
    Execute Command                 sysbus WriteDoubleWord 0xC ${{$HARDFAULT_HANDLER_ADDRESS | 1}}
    Execute Command                 sysbus WriteDoubleWord 0x14 ${{$BUSFAULT_HANDLER_ADDRESS | 1}}
    Execute Command                 sysbus WriteDoubleWord 0x40 ${{$EXTERNAL_HANDLER_ADDRESS | 1}}
    Execute Command                 cpu AssembleBlock ${NMI_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${BUSFAULT_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${EXTERNAL_HANDLER_ADDRESS} "b ."

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

Enter Instruction-Time Lockup
    Create Machine
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} ${LOCKUP_ASSEMBLY}
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}

    # The first, disabled BusFault escalates to HardFault. The handler clears
    # HFSR.FORCED and faults again while HardFault is active.
    Execute Command                 cpu Step 20

Lockup Should Be Asserted
    PC Should Be Equal              ${LOCKUP_PC}
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    ${lockup_signal}=               Execute Command  nvic Lockup IsSet
    Should Be Equal                 ${locked_up}  True  strip_spaces=True
    Should Be Equal                 ${lockup_signal}  True  strip_spaces=True

IPSR Should Be Equal
    [Arguments]                     ${expected}
    ${xpsr}=                        Execute Command  cpu GetRegister "CPSR"
    ${ipsr}=                        Evaluate  int($xpsr.strip(), 16) & 0x1ff
    Should Be Equal As Integers     ${ipsr}  ${expected}

${width} ${io} Should Be Equal
    [Arguments]  ${expected}
    ${val}=                         Execute Command  sysbus Read${width} ${io} context=cpu
    Should Be Equal As Integers     ${val}  ${expected}

Fault Should Be Precise
    [Arguments]                     ${handler_address}  ${fault_address}  ${expected_hfsr}=0
    PC Should Be Equal              ${handler_address}

    # Neither the faulting load nor the instruction following the failed
    # access may modify architectural state before the exception is taken.
    Register Should Be Equal        1  ${R1_BEFORE_FAULT}
    Register Should Be Equal        2  ${R2_BEFORE_FAULT}

    DoubleWord ${STACKED_R1_ADDRESS} Should Be Equal  ${R1_BEFORE_FAULT}
    DoubleWord ${STACKED_R2_ADDRESS} Should Be Equal  ${R2_BEFORE_FAULT}
    DoubleWord ${STACKED_PC_ADDRESS} Should Be Equal  ${CODE_ADDRESS}

    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_PRECISERR_BFARVALID}
    DoubleWord ${SCB_BFAR} Should Be Equal  ${fault_address}
    DoubleWord ${SCB_HFSR} Should Be Equal  ${expected_hfsr}

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

    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_PRECISERR_BFARVALID}
    DoubleWord ${SCB_BFAR} Should Be Equal  ${FAULTING_PERIPHERAL_ADDRESS}

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
    DoubleWord ${SCB_HFSR} Should Be Equal  0

Should Escalate BusFault That Cannot Preempt Active Handler
    Create Machine
    Enable BusFault
    Execute Command                 cpu AssembleBlock ${BUSFAULT_HANDLER_ADDRESS} ${READ_ASSEMBLY}
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}
    # The BusFault handler itself repeats the access at the same priority.
    # A synchronous fault cannot remain pending, so the single step
    # reaches HardFault through both precise faults.
    Execute Faulting Instruction
    PC Should Be Equal              ${HARDFAULT_HANDLER_ADDRESS}
    Register Should Be Equal        1  ${R1_BEFORE_FAULT}
    Register Should Be Equal        2  ${R2_BEFORE_FAULT}
    DoubleWord ${NESTED_STACKED_PC_ADDRESS} Should Be Equal  ${BUSFAULT_HANDLER_ADDRESS}
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_PRECISERR_BFARVALID}
    DoubleWord ${SCB_BFAR} Should Be Equal  ${FAULTING_PERIPHERAL_ADDRESS}
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_FORCED}

Should Enter Lockup When BusFault Cannot Escalate From HardFault
    Enter Instruction-Time Lockup

    # Armv8-M ARM rules RVGMR and RXHMT: the second synchronous BusFault
    # cannot escalate past the active HardFault. It updates its syndrome, but
    # does not change pending/active state or HFSR.FORCED.
    PC Should Be Equal              ${LOCKUP_PC}
    Register Should Be Equal        1  ${R1_BEFORE_FAULT}
    Register Should Be Equal        2  ${R2_BEFORE_FAULT}
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    ${lockup_signal}=               Execute Command  nvic Lockup IsSet
    ${in_sleep}=                    Execute Command  nvic InSleep IsSet
    ${in_deep_sleep}=               Execute Command  nvic InDeepSleep IsSet
    Should Be Equal                 ${locked_up}  True  strip_spaces=True
    Should Be Equal                 ${lockup_signal}  True  strip_spaces=True
    Should Be Equal                 ${in_sleep}  False  strip_spaces=True
    Should Be Equal                 ${in_deep_sleep}  False  strip_spaces=True

    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_PRECISERR_BFARVALID}
    DoubleWord ${SCB_BFAR} Should Be Equal  ${FAULTING_PERIPHERAL_ADDRESS}
    DoubleWord ${SCB_HFSR} Should Be Equal  0
    DoubleWord ${SCB_SHCSR} Should Be Equal  ${SHCSR_HARDFAULTACT}

    # Rules RMBTM and RHTVD: execution and ITSTATE advancement stop.
    ${itstate_before}=              Execute Command  cpu GetItState
    ${instructions_before}=         Execute Command  cpu ExecutedInstructions
    Should Not Be Equal As Integers  ${itstate_before}  0
    Execute Command                 cpu Step 10
    PC Should Be Equal              ${LOCKUP_PC}
    ${itstate_after}=               Execute Command  cpu GetItState
    ${instructions_after}=          Execute Command  cpu ExecutedInstructions
    Should Be Equal As Integers     ${itstate_after}  ${itstate_before}
    Should Be Equal As Integers     ${instructions_after}  ${instructions_before}

    # Rule RXQSR: reset exits Lockup and rule RHJNP deasserts LOCKUP.
    Execute Command                 cpu Reset
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    ${lockup_signal}=               Execute Command  nvic Lockup IsSet
    Should Be Equal                 ${locked_up}  False  strip_spaces=True
    Should Be Equal                 ${lockup_signal}  False  strip_spaces=True

NMI Should Preempt Instruction-Time Lockup
    Enter Instruction-Time Lockup

    # Rules RXQSR and RSPPN: NMI exits Lockup and stacks 0xEFFFFFFE as
    # its return address.
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${NMI_HANDLER_ADDRESS}
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    ${lockup_signal}=               Execute Command  nvic Lockup IsSet
    DoubleWord ${NESTED_STACKED_PC_ADDRESS} Should Be Equal  ${LOCKUP_PC}
    Should Be Equal                 ${locked_up}  False  strip_spaces=True
    Should Be Equal                 ${lockup_signal}  False  strip_spaces=True

Should Enter Lockup On Exception Unstacking BusFault
    Create Machine
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}

    # First establish an active HardFault, then clear its instruction-time
    # syndrome before NMI preempts it.
    Execute Faulting Instruction
    PC Should Be Equal              ${HARDFAULT_HANDLER_ADDRESS}
    Execute Command                 sysbus WriteDoubleWord ${SCB_CFSR} 0xFFFFFFFF context=cpu
    Execute Command                 sysbus WriteDoubleWord ${SCB_HFSR} ${HFSR_FORCED} context=cpu

    # NMI redirects MSP to the faulting peripheral immediately before its
    # exception return. The returning NMI is cleared before unstacking starts.
    Execute Command                 cpu AssembleBlock ${NMI_HANDLER_ADDRESS} ${UNSTACK_FAULT_ASSEMBLY}
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 3

    # Rules RNZCD and RTCJR: the full frame is consumed, IPSR describes a
    # return to Handler mode, and the derived fault cannot preempt HardFault.
    Lockup Should Be Asserted
    Register Should Be Equal        SP  0x100020
    IPSR Should Be Equal            3
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_UNSTKERR}
    DoubleWord ${SCB_HFSR} Should Be Equal  0
    DoubleWord ${SCB_SHCSR} Should Be Equal  ${SHCSR_HARDFAULTACT}

Should Enter Lockup On Reset Vector BusFault
    Create Machine
    Execute Command                 cpu VectorTableOffset ${FAULTING_PERIPHERAL_ADDRESS}
    Execute Command                 emulation RunFor "0.01"

    # Rule RBHVG and TakeReset: the initial MSP/vector BusFault enters Lockup
    # with HardFault active, IPSR zero, unknown MSP represented as zero, and
    # HFSR.VECTTBL set.
    Lockup Should Be Asserted
    Register Should Be Equal        SP  0
    IPSR Should Be Equal            0
    DoubleWord ${SCB_CFSR} Should Be Equal  0
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_VECTTBL}
    DoubleWord ${SCB_SHCSR} Should Be Equal  ${SHCSR_HARDFAULTACT}

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
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_PRECISERR_BFARVALID}
    DoubleWord ${SCB_BFAR} Should Be Equal  ${FAULTING_PERIPHERAL_ADDRESS}
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_FORCED}

Should Share BusFault State Across Security States
    Create TrustZone Machine
    Enable BusFault
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}
    Execute Faulting Instruction
    Fault Should Be Precise         ${BUSFAULT_HANDLER_ADDRESS}  ${FAULTING_PERIPHERAL_ADDRESS}

    ${secure_state}=                Execute Command  cpu SecureState
    Should Be Equal                 ${secure_state}  True  strip_spaces=True
    DoubleWord ${SCB_CFSR_NS} Should Be Equal  0
    DoubleWord ${SCB_BFAR_NS} Should Be Equal  0

    # BFSR and BFAR are not banked. Once BFHFNMINS retargets BusFault to
    # Non-secure, its aliases expose the syndrome captured by the Secure fault.
    Execute Command                 sysbus WriteDoubleWord ${SCB_AIRCR} ${AIRCR_VECTKEY_BFHFNMINS} context=cpu
    DoubleWord ${SCB_CFSR_NS} Should Be Equal  ${CFSR_PRECISERR_BFARVALID}
    DoubleWord ${SCB_BFAR_NS} Should Be Equal  ${FAULTING_PERIPHERAL_ADDRESS}

Read Access Should Produce Precise Bus Fault Without Single Step
    Run Precise BusFault Test Without Single Step  ${E2E_READ_ASSEMBLY}

Write Access Should Produce Precise Bus Fault Without Single Step
    Run Precise BusFault Test Without Single Step  ${E2E_WRITE_ASSEMBLY}
