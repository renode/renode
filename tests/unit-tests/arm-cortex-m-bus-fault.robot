*** Variables ***
${CODE_ADDRESS}                     ${0x200}
${BUSFAULT_HANDLER_ADDRESS}         ${0x300}
${HARDFAULT_HANDLER_ADDRESS}        ${0x340}
${NMI_HANDLER_ADDRESS}              ${0x380}
${EXTERNAL_HANDLER_ADDRESS}         ${0x3C0}
${NS_NMI_HANDLER_ADDRESS}           ${0x10000}
${NS_HARDFAULT_HANDLER_ADDRESS}     ${0x10040}
${NS_VECTOR_TABLE_ADDRESS}          ${0x10800}
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
${SCB_DHCSR}                        0xE000EDF0
${SCB_DHCSR_NS}                     0xE002EDF0
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
${DHCSR_S_LOCKUP}                   ${{1<<19}}
${FPCCR_LSPACT}                     ${{1<<0}}
${FPCCR_HFRDY}                      ${{1<<4}}
${FPCCR_TS}                         ${{1<<26}}
${CPACR_CP10_CP11_FULL_ACCESS}      0x00F00000
${CONTROL_FPCA}                     ${{1<<2}}

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
...                                 mem_ns: Memory.MappedMemory @ sysbus 0x10000
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
    # Armv8-M ARM rule RMBTM: DHCSR.S_LOCKUP reads as 1 to the debugger in Lockup.
    DoubleWord ${SCB_DHCSR} Should Be Equal  0
    ${dhcsr}=                       Execute Command  sysbus ReadDoubleWord ${SCB_DHCSR}
    Should Be True                  ${{(int($dhcsr.strip(), 16) & $DHCSR_S_LOCKUP) != 0}}
    # D1.2.39: unimplemented Halting-debug controls remain RES0/WI.
    Execute Command                 sysbus WriteDoubleWord ${SCB_DHCSR} 0xFFFFFFFF context=cpu
    DoubleWord ${SCB_DHCSR} Should Be Equal  0

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

Should Pend Lazy FP HardFault When Original Context Was Ready
    Create Machine
    Execute Command                 sysbus WriteDoubleWord ${SCB_CPACR} ${CPACR_CP10_CP11_FULL_ACCESS} context=cpu
    Execute Command                 faultingPeripheral FaultOffset 0x20
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} "vmov.f32 s0, s0; b ."
    Execute Command                 cpu AssembleBlock ${NMI_HANDLER_ADDRESS} "nop; vmov.f32 s0, s0; b ."
    Execute Command                 cpu SP 0x100068
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}

    # Create an FP context in Thread mode, then let NMI reserve a lazy frame.
    # UpdateFPCCR() records HFRDY=1 because HardFault could preempt the
    # original Thread context.
    Execute Command                 cpu Step 1
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${{${NMI_HANDLER_ADDRESS} + 2}}
    ${fpcar}=                       Execute Command  cpu FPCAR
    ${fpccr}=                       Execute Command  cpu FPCCR
    Should Be Equal As Integers     ${fpcar}  0x100020
    Should Be True                  ${{(int($fpccr.strip(), 16) & $FPCCR_HFRDY) != 0}}

    # The first lazy-FP store generates BusFault.LSPERR. HardFault cannot
    # preempt the current NMI, but TakePreserveFPException() uses saved
    # HFRDY=1, so it pends HardFault, clears LSPACT, and continues.
    Execute Command                 cpu Step 1
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    Should Be Equal                 ${locked_up}  False  strip_spaces=True
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_LSPERR}
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_FORCED}
    ${shcsr}=                       Execute Command  sysbus ReadDoubleWord ${SCB_SHCSR} context=cpu
    ${fpccr}=                       Execute Command  cpu FPCCR
    Should Be True                  ${{(int($shcsr.strip(), 16) & $SHCSR_HARDFAULTPENDED) != 0}}
    Should Be Equal As Integers     ${{int($fpccr.strip(), 16) & $FPCCR_LSPACT}}  0

Should Enter Lockup On Lazy FP Preservation BusFault
    Create Machine
    Execute Command                 sysbus WriteDoubleWord ${SCB_CPACR} ${CPACR_CP10_CP11_FULL_ACCESS} context=cpu
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} "vmov.f32 s0, s0; b ."
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}

    # Establish HardFault, clear the ordinary BusFault syndrome, and create
    # an FP context at HardFault priority.
    Execute Faulting Instruction
    Execute Command                 sysbus WriteDoubleWord ${SCB_CFSR} 0xFFFFFFFF context=cpu
    Execute Command                 sysbus WriteDoubleWord ${SCB_HFSR} ${HFSR_FORCED} context=cpu
    Execute Command                 cpu Step 1

    # NMI entry reserves the lazy frame at 0x100020 while its basic frame is
    # successfully stacked immediately below it. UpdateFPCCR() records
    # HFRDY=0 because the FP state belongs to the active HardFault context.
    Execute Command                 faultingPeripheral FaultOffset 0x20
    Execute Command                 cpu AssembleBlock ${NMI_HANDLER_ADDRESS} "nop; vmov.f32 s0, s0; b ."
    Execute Command                 cpu SP 0x100068
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${{${NMI_HANDLER_ADDRESS} + 2}}
    ${fpcar}=                       Execute Command  cpu FPCAR
    ${fpccr}=                       Execute Command  cpu FPCCR
    Should Be Equal As Integers     ${fpcar}  0x100020
    Should Be Equal As Integers     ${{int($fpccr.strip(), 16) & $FPCCR_HFRDY}}  0

    # Rule RRNKB and TakePreserveFPException(): the BusFault escalates, cannot
    # preempt NMI, and saved HFRDY=0 makes this Lockup. FORCED and pending
    # state remain unchanged, and LSPACT/FP contents are preserved.
    Execute Command                 cpu Step 1
    Lockup Should Be Asserted
    Register Should Be Equal        SP  0x100000
    IPSR Should Be Equal            2
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_LSPERR}
    DoubleWord ${SCB_HFSR} Should Be Equal  0
    DoubleWord ${SCB_SHCSR} Should Be Equal  ${SHCSR_HARDFAULTACT_NMIACT}
    ${fpccr}=                       Execute Command  cpu FPCCR
    Should Be True                  ${{(int($fpccr.strip(), 16) & $FPCCR_LSPACT) != 0}}

Should Reserve Complete Secure Lazy FP Frame With TS
    Create TrustZone Machine
    Execute Command                 sysbus WriteDoubleWord ${SCB_CPACR} ${CPACR_CP10_CP11_FULL_ACCESS} context=cpu
    ${fpccr}=                       Execute Command  sysbus ReadDoubleWord ${SCB_FPCCR} context=cpu
    Execute Command                 sysbus WriteDoubleWord ${SCB_FPCCR} ${{int($fpccr.strip(), 16) | $FPCCR_TS}} context=cpu
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} "vmov.f32 s0, s0; b ."
    Execute Command                 cpu SP ${STACK_TOP}
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}

    # A Secure FP context with FPCCR.TS reserves the 0x20 core frame,
    # 0x48 caller FP frame, and 0x40 Additional FP frame from PushStack().
    Execute Command                 cpu Step 1
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${NMI_HANDLER_ADDRESS}
    Register Should Be Equal        SP  0xF58
    ${fpcar}=                       Execute Command  cpu FPCAR
    Should Be Equal As Integers     ${fpcar}  0xF78

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

Should Tail Chain On Exception Unstacking BusFault
    Create Machine
    Enable BusFault
    Execute Command                 faultingPeripheral FaultOnWrites false
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${NMI_HANDLER_ADDRESS} "nop; bx lr"
    Execute Command                 cpu SP 0x100020
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}
    Execute Command                 cpu Step 1

    # Writes to the peripheral-backed stack succeed for NMI entry, while
    # reads fail when BX LR starts PopStack().
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${{${NMI_HANDLER_ADDRESS} + 2}}
    Execute Command                 cpu Step 1

    # NMI is already inactive when UNSTKERR is generated. The enabled
    # BusFault can therefore be taken, and RVJKL requires it to tail-chain
    # through the unconsumed frame rather than allocate a second one.
    PC Should Be Equal              ${BUSFAULT_HANDLER_ADDRESS}
    Register Should Be Equal        SP  0x100000
    Register Should Be Equal        LR  ${EXC_RETURN_THREAD_MSP}
    IPSR Should Be Equal            5
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    Should Be Equal                 ${locked_up}  False  strip_spaces=True
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_UNSTKERR}
    DoubleWord ${SCB_HFSR} Should Be Equal  0

Should Clear FPCA When Tail Chaining On Unstacking BusFault
    Create Machine
    Enable BusFault
    Execute Command                 sysbus WriteDoubleWord ${SCB_CPACR} ${CPACR_CP10_CP11_FULL_ACCESS} context=cpu
    Execute Command                 faultingPeripheral FaultOnWrites false
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${NMI_HANDLER_ADDRESS} "vmov.f32 s0, s0; bx lr"
    Execute Command                 cpu SP 0x100020
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}
    Execute Command                 cpu Step 1

    # NMI stacking succeeds in the peripheral, and its first FP instruction
    # establishes FPCA in the handler context.
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    ${control}=                     Execute Command  cpu GetRegister "CONTROL"
    Should Be True                  ${{(int($control.strip(), 16) & $CONTROL_FPCA) != 0}}

    # The return read faults and tail-chains to BusFault through the existing
    # frame. ActivateException() clears FPCA on this entry just as it does for
    # a non-tail-chained exception.
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${BUSFAULT_HANDLER_ADDRESS}
    IPSR Should Be Equal            5
    ${control}=                     Execute Command  cpu GetRegister "CONTROL"
    Should Be Equal As Integers     ${{int($control.strip(), 16) & $CONTROL_FPCA}}  0
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_UNSTKERR}

Should Mask Banked Non-secure HardFault With FAULTMASK_NS
    Create TrustZone Machine
    Execute Command                 sysbus WriteDoubleWord ${SCB_AIRCR} ${AIRCR_VECTKEY_BFHFNMINS} context=cpu
    Execute Command                 cpu SAURegionNumber 0
    Execute Command                 cpu SAURegionBaseAddress 0x10000
    Execute Command                 cpu SAURegionLimitAddress 0x10FE1
    Execute Command                 cpu SAUControl 1
    Execute Command                 cpu AssembleBlock 0x10000 "udf #0; b ."
    Execute Command                 cpu SP ${STACK_TOP}
    Execute Command                 cpu SecureState false
    Execute Command                 cpu SP 0x11000
    Execute Command                 cpu SetRegister "FAULTMASK" 1
    Execute Command                 cpu PC 0x10001
    Execute Command                 cpu Step 1

    # ExecutionPriority() boosts the Non-secure execution priority to -1
    # when BFHFNMINS is set. The disabled UsageFault escalates to the banked
    # Non-secure HardFault at the same priority, so it cannot be taken.
    Lockup Should Be Asserted
    IPSR Should Be Equal            0
    ${secure_state}=                Execute Command  cpu SecureState
    Should Be Equal                 ${secure_state}  False  strip_spaces=True
    DoubleWord ${SCB_HFSR} Should Be Equal  0

Should Allow Secure HardFault Past FAULTMASK_NS
    Create TrustZone Machine
    Execute Command                 cpu SAURegionNumber 0
    Execute Command                 cpu SAURegionBaseAddress 0x10000
    Execute Command                 cpu SAURegionLimitAddress 0x10FE1
    Execute Command                 cpu SAUControl 1
    Execute Command                 cpu AssembleBlock 0x10000 "udf #0; b ."
    Execute Command                 cpu SP ${STACK_TOP}
    Execute Command                 cpu SecureState false
    Execute Command                 cpu SP 0x11000
    Execute Command                 cpu SetRegister "FAULTMASK" 1
    Execute Command                 cpu PC 0x10001
    Execute Command                 cpu Step 1

    # With BFHFNMINS clear, FAULTMASK_NS boosts execution priority to zero.
    # The disabled Non-secure UsageFault therefore escalates to the single
    # Secure HardFault at priority -1, which is still able to preempt.
    PC Should Be Equal              ${HARDFAULT_HANDLER_ADDRESS}
    IPSR Should Be Equal            3
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    ${secure_state}=                Execute Command  cpu SecureState
    Should Be Equal                 ${locked_up}  False  strip_spaces=True
    Should Be Equal                 ${secure_state}  True  strip_spaces=True
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_FORCED}

Should Allow Banked Secure HardFault Past PRIMASK_NS
    Create TrustZone Machine
    Execute Command                 sysbus WriteDoubleWord ${SCB_AIRCR} ${AIRCR_VECTKEY_BFHFNMINS} context=cpu
    Execute Command                 cpu SAURegionNumber 0
    Execute Command                 cpu SAURegionBaseAddress 0x10000
    Execute Command                 cpu SAURegionLimitAddress 0x10FE1
    Execute Command                 cpu SAUControl 1
    Execute Command                 sysbus WriteDoubleWord 0x8 ${{$NS_NMI_HANDLER_ADDRESS | 1}}
    Execute Command                 cpu AssembleBlock ${NS_NMI_HANDLER_ADDRESS} "nop; bx lr"
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} "b ."
    Execute Command                 cpu SP ${STACK_TOP}
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}
    Execute Command                 cpu Step 1

    # Enter Non-secure NMI, then set PRIMASK_NS and make its EXC_RETURN fail
    # the ES/DCRS integrity check.
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${{${NS_NMI_HANDLER_ADDRESS} + 2}}
    Execute Command                 cpu SetRegister "PRIMASK" 1
    Execute Command                 cpu SetRegister "LR" 0xFFFFFFD8
    Execute Command                 cpu Step 1

    # ValidateExceptionReturn() generates SecureFault, which escalates to
    # banked HardFault_S. PRIMASK_NS boosts execution priority only to zero,
    # so the priority -3 Secure HardFault remains unmasked.
    PC Should Be Equal              ${HARDFAULT_HANDLER_ADDRESS}
    IPSR Should Be Equal            3
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    ${secure_state}=                Execute Command  cpu SecureState
    Should Be Equal                 ${locked_up}  False  strip_spaces=True
    Should Be Equal                 ${secure_state}  True  strip_spaces=True
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_FORCED}

Should Retain Secure FAULTMASK For HardFault Return Lockup
    Create TrustZone Machine
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} "movs r1, #1; msr faultmask, r1; ldr r0, =${FAULTING_PERIPHERAL_ADDRESS}; msr msp, r0; bx lr"
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}

    # Establish Secure HardFault, then isolate the exception-return syndrome.
    Execute Faulting Instruction
    PC Should Be Equal              ${{${HARDFAULT_HANDLER_ADDRESS} + 2}}
    Execute Command                 sysbus WriteDoubleWord ${SCB_CFSR} 0xFFFFFFFF context=cpu
    Execute Command                 sysbus WriteDoubleWord ${SCB_HFSR} ${HFSR_FORCED} context=cpu
    Execute Command                 cpu Step 4

    # RCDCR retains FAULTMASK_S because RawExecutionPriority() is negative
    # while returning from HardFault. The handler is deactivated before the
    # unstack BusFault, but FAULTMASK_S still prevents the escalated Secure
    # HardFault from becoming active, so RVJKL and RNZCD require Lockup.
    Lockup Should Be Asserted
    Register Should Be Equal        SP  0x100020
    IPSR Should Be Equal            0
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_UNSTKERR}
    DoubleWord ${SCB_HFSR} Should Be Equal  0
    DoubleWord ${SCB_SHCSR} Should Be Equal  0

Should Enter Lockup On RETPSR Integrity Failure
    Create Machine
    Prepare Faulting Instruction    ${READ_ASSEMBLY}  ${FAULTING_PERIPHERAL_ADDRESS}

    # Establish an active HardFault, then remove its instruction-time
    # syndromes so the exception-return failure is observed in isolation.
    Execute Faulting Instruction
    PC Should Be Equal              ${HARDFAULT_HANDLER_ADDRESS}
    Execute Command                 sysbus WriteDoubleWord ${SCB_CFSR} 0xFFFFFFFF context=cpu
    Execute Command                 sysbus WriteDoubleWord ${SCB_HFSR} ${HFSR_FORCED} context=cpu

    # NMI preempts HardFault. Its EXC_RETURN requests Handler mode, but zeroing
    # the stacked IPSR makes RETPSR inconsistent with that destination mode.
    Execute Command                 cpu AssembleBlock ${NMI_HANDLER_ADDRESS} "movs r0, #0; str r0, [sp, #28]; bx lr"
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 3

    # PopStack() raises UsageFault.INVPC after NMI is deactivated. The disabled
    # UsageFault escalates to HardFault, which cannot preempt the still-active
    # background HardFault, so rules RVJKL, RNZCD, and RTCJR require Lockup.
    Lockup Should Be Asserted
    Register Should Be Equal        SP  0xFE0
    IPSR Should Be Equal            3
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_INVPC}
    DoubleWord ${SCB_HFSR} Should Be Equal  0
    DoubleWord ${SCB_SHCSR} Should Be Equal  ${SHCSR_HARDFAULTACT}

Should Enter Lockup On Reset Vector BusFault
    Create Machine
    Execute Command                 faultingPeripheral FaultOffset 4
    Execute Command                 cpu VectorTableOffset ${FAULTING_PERIPHERAL_ADDRESS}
    Execute Command                 emulation RunFor "0.01"

    # Rule RBHVG and TakeReset: the initial MSP/vector BusFault enters Lockup
    # with HardFault active, IPSR zero, unknown MSP represented as zero, and
    # HFSR.VECTTBL set.
    Lockup Should Be Asserted
    Register Should Be Equal        SP  0
    Register Should Be Equal        LR  0xFFFFFFFF
    IPSR Should Be Equal            0
    DoubleWord ${SCB_CFSR} Should Be Equal  0
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_VECTTBL}
    DoubleWord ${SCB_SHCSR} Should Be Equal  ${SHCSR_HARDFAULTACT}

Should Enter Lockup On Initial MSP BusFault
    Create Machine
    # TakeReset() permits either vector-load order. Renode reads the reset
    # vector first, so leave offset 4 readable and fault only the initial MSP.
    Execute Command                 faultingPeripheral FaultOffset 0
    Execute Command                 cpu VectorTableOffset ${FAULTING_PERIPHERAL_ADDRESS}
    Execute Command                 emulation RunFor "0.01"

    Lockup Should Be Asserted
    Register Should Be Equal        SP  0
    Register Should Be Equal        LR  0xFFFFFFFF
    IPSR Should Be Equal            0
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_VECTTBL}
    DoubleWord ${SCB_SHCSR} Should Be Equal  ${SHCSR_HARDFAULTACT}

Should Tail Chain On Invalid Non-secure DCRS
    Create TrustZone Machine
    Execute Command                 sysbus WriteDoubleWord ${SCB_AIRCR} ${AIRCR_VECTKEY_BFHFNMINS} context=cpu
    Execute Command                 cpu SAURegionNumber 0
    Execute Command                 cpu SAURegionBaseAddress 0x10000
    Execute Command                 cpu SAURegionLimitAddress 0x10FE1
    Execute Command                 cpu SAUControl 1
    Execute Command                 sysbus WriteDoubleWord 0x8 ${{$NS_NMI_HANDLER_ADDRESS | 1}}
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} "b ."
    Execute Command                 cpu AssembleBlock ${NS_NMI_HANDLER_ADDRESS} "nop; bx lr"
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} "b ."
    Execute Command                 cpu SP ${STACK_TOP}
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}
    Execute Command                 cpu Step 1

    # NMI targets Non-secure state while its interrupted frame and Additional
    # state context reside on the Secure MSP.
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    PC Should Be Equal              0x10002

    # Rule RNCQN and ValidateExceptionReturn(): ES=0 requires DCRS=1.
    # Clear DCRS in the NMI's otherwise valid EXC_RETURN, then execute BX LR.
    Execute Command                 cpu SetRegister "LR" 0xFFFFFFD8
    Execute Command                 cpu Step 1

    # The INVER SecureFault is generated after NMI is deactivated. It
    # escalates to Secure HardFault and, per RVJKL, tail-chains through the
    # existing cross-security frame.
    PC Should Be Equal              ${HARDFAULT_HANDLER_ADDRESS}
    Register Should Be Equal        SP  0xFB8
    Register Should Be Equal        LR  0xFFFFFFD9
    IPSR Should Be Equal            3
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    Should Be Equal                 ${locked_up}  False  strip_spaces=True
    DoubleWord ${SCB_SFSR} Should Be Equal  ${SFSR_INVER}
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_FORCED}

Should Keep BusFault From Failed Integrity Signature Read
    Create TrustZone Machine
    Execute Command                 sysbus WriteDoubleWord ${SCB_AIRCR} ${AIRCR_VECTKEY_BFHFNMINS} context=cpu
    Execute Command                 cpu SAURegionNumber 0
    Execute Command                 cpu SAURegionBaseAddress 0x10000
    Execute Command                 cpu SAURegionLimitAddress 0x10FE1
    Execute Command                 cpu SAUControl 1
    Execute Command                 cpu VectorTableOffsetNonSecure ${NS_VECTOR_TABLE_ADDRESS}
    Execute Command                 sysbus WriteDoubleWord ${{${NS_VECTOR_TABLE_ADDRESS} + 8}} ${{$NS_NMI_HANDLER_ADDRESS | 1}}
    Execute Command                 sysbus WriteDoubleWord ${{${NS_VECTOR_TABLE_ADDRESS} + 12}} ${{$NS_HARDFAULT_HANDLER_ADDRESS | 1}}
    Execute Command                 cpu AssembleBlock ${NS_NMI_HANDLER_ADDRESS} "nop; bx lr"
    Execute Command                 cpu AssembleBlock ${NS_HARDFAULT_HANDLER_ADDRESS} "b ."
    Execute Command                 faultingPeripheral FaultOnWrites false
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} "b ."
    Execute Command                 cpu SP 0x100048
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}
    Execute Command                 cpu Step 1

    # Non-secure NMI entry writes the basic and Additional state contexts to
    # the peripheral-backed Secure stack. Writes succeed, but the first return
    # read of the integrity signature generates BusFault.UNSTKERR.
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${{${NS_NMI_HANDLER_ADDRESS} + 2}}
    Execute Command                 cpu Step 1

    # PopStack() compares the signature only if its read succeeded. The
    # BusFault therefore escalates to Non-secure HardFault without being
    # overwritten by SecureFault.INVIS.
    PC Should Be Equal              ${NS_HARDFAULT_HANDLER_ADDRESS}
    IPSR Should Be Equal            3
    ${secure_state}=                Execute Command  cpu SecureState
    Should Be Equal                 ${secure_state}  False  strip_spaces=True
    DoubleWord ${SCB_CFSR} Should Be Equal  ${CFSR_UNSTKERR}
    DoubleWord ${SCB_SFSR} SHould Be Equal  0
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_FORCED}

Should Take HardFault On Integrity Signature Mismatch
    Create TrustZone Machine
    # Set BFHFNMINS so HardFault is banked and NMI targets Non-secure.
    Execute Command                 sysbus WriteDoubleWord ${SCB_AIRCR} ${AIRCR_VECTKEY_BFHFNMINS} context=cpu

    # Leave the SAU background region Secure and mark only the NMI handler
    # memory Non-secure. This keeps the derived Secure HardFault handler
    # executable in Secure state.
    Execute Command                 cpu SAURegionNumber 0
    Execute Command                 cpu SAURegionBaseAddress 0x10000
    Execute Command                 cpu SAURegionLimitAddress 0x10FE1
    Execute Command                 cpu SAUControl 1

    # Point the NMI vector to the Non-secure handler.
    Execute Command                 sysbus WriteDoubleWord 0x8 ${{$NS_NMI_HANDLER_ADDRESS | 1}}

    # Set up the HardFault handler (taken after the derived SecureFault
    # escalates to HardFault_S, which is not previously active).
    Execute Command                 cpu AssembleBlock ${HARDFAULT_HANDLER_ADDRESS} "b ."

    # Set up the NMI handler in Non-secure memory as "nop; bx lr". The nop
    # gives us a step between NMI entry and return to corrupt the signature.
    Execute Command                 cpu AssembleBlock ${NS_NMI_HANDLER_ADDRESS} "nop; bx lr"

    # Set up Thread mode code that loops.
    Execute Command                 cpu AssembleBlock ${CODE_ADDRESS} "b ."
    Execute Command                 cpu SP ${STACK_TOP}
    Execute Command                 cpu PC ${{$CODE_ADDRESS | 1}}
    Execute Command                 cpu Step 1

    # Pend NMI. It targets Non-secure (BFHFNMINS=1) and preempts from Secure
    # Thread mode, pushing the additional state context (integrity signature)
    # on the Secure stack. After stacking: SP_S = 0x1000 - 0x20 (basic frame)
    # - 0x28 (additional state context) = 0xFB8. The integrity signature is
    # the last word pushed, at 0xFB8.
    Execute Command                 nvic SetPendingIRQ 2
    Execute Command                 cpu Step 1
    # After NMI entry + nop, PC is at the "bx lr" instruction (0x10002).
    PC Should Be Equal              0x10002

    # Corrupt the integrity signature at 0xFB8 from the test script.
    Execute Command                 sysbus WriteDoubleWord 0xFB8 0

    # Step again to execute "bx lr" and trigger the exception return.
    Execute Command                 cpu Step 1

    # PopStack() and HandleExceptionTransitions(): SFSR.INVIS creates a
    # SecureFault after NMI has been deactivated. Because no HardFault is
    # active, the disabled SecureFault escalates and HardFault_S is taken;
    # this is not a Lockup case.
    PC Should Be Equal              ${HARDFAULT_HANDLER_ADDRESS}
    # Rule RVJKL and HandleExceptionTransitions() require this to be a
    # tail-chain using the unconsumed Secure frame, not a normal entry which
    # would allocate another frame. ExceptionTaken() also updates ES and DCRS
    # in the reused EXC_RETURN for the Non-secure-to-Secure transition.
    Register Should Be Equal        SP  0xFB8
    Register Should Be Equal        LR  0xFFFFFFD9
    IPSR Should Be Equal            3
    ${locked_up}=                   Execute Command  cpu IsLockedUp
    Should Be Equal                 ${locked_up}  False  strip_spaces=True
    DoubleWord ${SCB_SFSR} Should Be Equal  ${SFSR_INVIS}
    DoubleWord ${SCB_HFSR} Should Be Equal  ${HFSR_FORCED}

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

DHCSR Lockup Status Should Follow DAP Visibility
    Create TrustZone Machine
    Execute Command                 nvic Lockup Set true

    # S_LOCKUP is visible only to a remote debugger at the base address.
    # Software reads zero through either address, including Secure software
    # using the Non-secure alias.
    DoubleWord ${SCB_DHCSR} Should Be Equal  0
    DoubleWord ${SCB_DHCSR_NS} Should Be Equal  0

    # ReadDoubleWord with no cpu context ≈ debugger
    ${dhcsr_debugger}=              Execute Command  sysbus ReadDoubleWord ${SCB_DHCSR}
    Should Be Equal As Integers     ${dhcsr_debugger}  ${DHCSR_S_LOCKUP}
    ${dhcsr_ns_debugger}=           Execute Command  sysbus ReadDoubleWord ${SCB_DHCSR_NS}
    Should Be Equal As Integers     ${dhcsr_ns_debugger}  0

    Execute Command                 cpu SecureState false
    DoubleWord ${SCB_DHCSR} Should Be Equal  0
    DoubleWord ${SCB_DHCSR_NS} Should Be Equal  0

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
