*** Variables ***

${MACHINE_EXTERNAL_INTERRUPT_INDEX}        11
${MCAUSE_MACHINE_EXTERNAL_INTERRUPT}       ${0x80000000 + ${MACHINE_EXTERNAL_INTERRUPT_INDEX}}
${MIE_MIP_MACHINE_EXTERNAL_INTERRUPT_BIT}  ${1 << ${MACHINE_EXTERNAL_INTERRUPT_INDEX}}

${MTVEC_ADDRESS}                           0x20000
${MTVEC_MIE_ENTRY_ADDRESS}                 ${${MTVEC_ADDRESS} + 4*${MACHINE_EXTERNAL_INTERRUPT_INDEX}}
${M_EXTERNAL_IRQ_HANDLER_ADDRESS}          0x21000
${PIC_MEIVT_ADDRESS}                       0x22000
${PIC_INT2_HANDLER_ADDRESS}                0x23200
${PIC_INT5_HANDLER_ADDRESS}                0x23500
${INIT_PC}                                 0x28000
${PIC_BASE_ADDRESS}                        0xE0000000

${PLATFORM}                         SEPARATOR=\n
...    cpu: CPU.VeeR_EL2 @ sysbus
...
...    pic: IRQControllers.VeeR_EL2_PIC @ sysbus new Bus.BusPointRegistration {
...    ${SPACE*4}${SPACE*4}address: ${PIC_BASE_ADDRESS};
...    ${SPACE*4}${SPACE*4}cpu: cpu
...    ${SPACE*4}}
...    ${SPACE*4}cpu: cpu
...    ${SPACE*4}interruptSourcesCount: 63
...    ${SPACE*4}->cpu@${MACHINE_EXTERNAL_INTERRUPT_INDEX}
...
...    memory: Memory.MappedMemory @ sysbus 0x20000
...    ${SPACE*4}size: 0x10000

${renode_a0_index}  10

# PIC custom CSRs
${meivt}            0xBC8
${meipt}            0xBC9
${meicpct}          0xBCA
${meicidpl}         0xBCB
${meicurpl}         0xBCC
${meihap}           0xFC8

# VeeR custom CSR
${mpmc}             0x7C6

# PIC memory-mapped registers

${PIC_CONFIGURATION_REGISTER}  ${${PIC_BASE_ADDRESS} + 0x3000}  # mpiccfg

# Bit per interrupt source, 8 registers total
${INTERRUPTS_PENDING_BASE}     ${${PIC_BASE_ADDRESS} + 0x1000}  # meipX

# Each interrupt source has its own register
# id1 => 0x*004, id255 => 0x*3FC (source with id0 isn't possible)
${PRIORITY_LEVEL_BASE}         ${${PIC_BASE_ADDRESS} + 0x0}     # meiplS
${ENABLE_BASE}                 ${${PIC_BASE_ADDRESS} + 0x2000}  # meieS
${GATEWAY_CONFIGURATION_BASE}  ${${PIC_BASE_ADDRESS} + 0x4000}  # meigwctrlS
${GATEWAY_CLEAR_BASE}          ${${PIC_BASE_ADDRESS} + 0x5000}  # meigwclrS

# Code

${INIT_CODE}                        SEPARATOR=\n
...    ${PIC_INIT_CODE}
...    li a0, ${PIC_MEIVT_ADDRESS}
...    csrw ${meivt}, a0
...    li a0, (${MTVEC_ADDRESS} + 1)  // 1: vectored mode
...    csrw mtvec, a0
...    csrr a0, mstatus
...    ori a0, a0, 0x8  // MIE=1
...    csrw mstatus, a0
...    ${LOOP_CODE}

${LOOP_CODE}                        SEPARATOR=\n
...    loop:
...    j loop

${PIC_MEIVT_VECTOR_TABLE}           SEPARATOR=\n
...    .word 0x0
...    .word 0x0                          // pointer to pic source 1 handler
...    .word ${PIC_INT2_HANDLER_ADDRESS}  // pointer to pic source 2 handler
...    .word 0x0                          // pointer to pic source 3 handler
...    .word 0x0                          // pointer to pic source 4 handler
...    .word ${PIC_INT5_HANDLER_ADDRESS}  // pointer to pic source 5 handler
...    .word 0x0                          // ...

${PIC_EDGE_TRIGGERED_INT_HANDLER}   SEPARATOR=\n
...    li a2, \id
...    ${MACRO_CLEAR_GATEWAY}
...    mret

${PIC_LEVEL_TRIGGERED_INT_HANDLER}  SEPARATOR=\n
...    li a2, \id
...    mret

${MTVEC_VTABLE_AND_MIE_HANDLER}     SEPARATOR=\n
...    .org ${MACHINE_EXTERNAL_INTERRUPT_INDEX}*4
...    j mie_handler
...
...    .org ${M_EXTERNAL_IRQ_HANDLER_ADDRESS} - ${MTVEC_ADDRESS}
...    mie_handler:
...    ${M_EXTERNAL_IRQ_HANDLER_CODE}

## "Example Interrupt Flows" (section 8.15.1 of VeeR EL2 docs)

${PIC_INIT_CODE}                    SEPARATOR=\n
...    ${MACRO_DISABLE_MACHINE_EXT_INTS}
...    ${MACRO_SET_THRESHOLD}
...    ${MACRO_INIT_PRIORITYORDER}
...    ${MACRO_INIT_GATEWAY}
...    ${MACRO_CLEAR_GATEWAY}
...    ${MACRO_INT_SOURCE_SET_PRIORITY}
...    ${MACRO_INT_SOURCE_ENABLE}
...    ${MACRO_ENABLE_MACHINE_EXT_INTS}

### trap_handler
${M_EXTERNAL_IRQ_HANDLER_CODE}      SEPARATOR=\n
...    csrwi ${meicpct}, 1          // Capture winning claim id and priority
...    csrr t0, ${meihap}           // Load pointer index
...    lw t1, 0(t0)                 // Load vector address
...    jr t1                        // Go there

## "Example Interrupt Macros" (section 8.15.2 of VeeR EL2 docs)

### clear_gateway id
${MACRO_CLEAR_GATEWAY}              SEPARATOR=\n
...    li tp, (${GATEWAY_CLEAR_BASE} + (\id << 2))
...    sw zero, 0(tp)

### disable_ext_int
${MACRO_DISABLE_MACHINE_EXT_INTS}   SEPARATOR=\n
...    li a0, (1 << ${MACHINE_EXTERNAL_INTERRUPT_INDEX})
...    csrrc zero, mie, a0

### enable_ext_int
${MACRO_ENABLE_MACHINE_EXT_INTS}    SEPARATOR=\n
...    li a0, (1 << ${MACHINE_EXTERNAL_INTERRUPT_INDEX})
...    csrrs zero, mie, a0

### init_gateway id, polarity, type
${MACRO_INIT_GATEWAY}               SEPARATOR=\n
...    li tp, (${GATEWAY_CONFIGURATION_BASE} + (\id << 2))
...    li t0, ((\type << 1) | \polarity)
...    sw t0, 0(tp)

### init_priorityorder priord
${MACRO_INIT_PRIORITYORDER}         SEPARATOR=\n
...    li tp, ${PIC_CONFIGURATION_REGISTER}
...    li t0, \priord
...    sw t0, 0(tp)

### enable_interrupt id
${MACRO_INT_SOURCE_ENABLE}          SEPARATOR=\n
...    li tp, (${ENABLE_BASE} + (\id << 2))
...    li t0, 1
...    sw t0, 0(tp)

### set_priority id, priority
${MACRO_INT_SOURCE_SET_PRIORITY}    SEPARATOR=\n
...    li tp, (${PRIORITY_LEVEL_BASE} + (\id << 2))
...    li t0, \priority
...    sw t0, 0(tp)

### set_threshold threshold
${MACRO_SET_THRESHOLD}              SEPARATOR=\n
...    li a0, \threshold
...    csrw ${meipt}, a0


*** Keywords ***

Add Init Program
    [Arguments]                     ${destination}  ${priord}  ${threshold}  ${source_id}  ${priority}
    ...                             ${source_active_low}=False  ${source_edge_triggered}=False

    # Replace macro arguments with values
    ${prog}=  Set Variable          ${INIT_CODE}
    ${prog}=  Replace String        ${prog}  \priord     ${priord}
    ${prog}=  Replace String        ${prog}  \threshold  ${threshold}
    ${prog}=  Replace String        ${prog}  \id         ${source_id}
    ${prog}=  Replace String        ${prog}  \priority   ${priority}
    ${prog}=  Replace String        ${prog}  \polarity   ${{ "1" if ${source_active_low} else "0" }}
    ${prog}=  Replace String        ${prog}  \type       ${{ "1" if ${source_edge_triggered} else "0" }}

    ${length}=  Execute Command     cpu AssembleBlock ${destination} """${prog}"""
    ${length}=  Strip String        ${length}

    # -2 because `j 0` is a 2-byte instruction.
    ${loop_pc}=  Evaluate           ${INIT_PC} + ${length} - 2
    [Return]                        ${loop_pc}


Create Machine
    [Arguments]                     ${edge_triggered_interrupts}=False

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM}"""
    Execute Command                 cpu PC ${INIT_PC}
    Create Log Tester               timeout=0

    Execute Command                 cpu AssembleBlock ${MTVEC_ADDRESS} """${MTVEC_VTABLE_AND_MIE_HANDLER}"""
    Execute Command                 cpu AssembleBlock ${PIC_MEIVT_ADDRESS} """${PIC_MEIVT_VECTOR_TABLE}"""

    IF    ${edge_triggered_interrupts}
        ${int_handler}=  Set Variable    ${PIC_EDGE_TRIGGERED_INT_HANDLER}
    ELSE
        ${int_handler}=  Set Variable    ${PIC_LEVEL_TRIGGERED_INT_HANDLER}
    END

    ${handler2}=  Replace String    ${int_handler}  \id  2
    Execute Command                 cpu AssembleBlock ${PIC_INT2_HANDLER_ADDRESS} """${handler2}"""

    ${handler5}=  Replace String    ${int_handler}  \id  5
    Execute Command                 cpu AssembleBlock ${PIC_INT5_HANDLER_ADDRESS} """${handler5}"""


Enable Source ${id}
    ${reg_address}=  Evaluate       ${ENABLE_BASE} + (${id} << 2)
    Execute Command                 sysbus WriteDoubleWord ${reg_address} 1 context=cpu


External IRQ Should Be Handled
    [Arguments]                     ${source_id}  ${handler_address}  ${loop_pc}
    ...                             ${source_active_low}=False  ${source_edge_triggered}=False

    PIC Should Have Interrupt Source ${source_id} Pending
    PIC IRQ Should Be Set

    Should Step Over MTVEC#11
    Pc Should Be Equal              ${M_EXTERNAL_IRQ_HANDLER_ADDRESS}
    Register Should Be Equal        MEPC    ${loop_pc}
    Register Should Be Equal        MIP     ${MIE_MIP_MACHINE_EXTERNAL_INTERRUPT_BIT}
    Register Should Be Equal        MCAUSE  ${MCAUSE_MACHINE_EXTERNAL_INTERRUPT}

    # MIE handler
    Execute Command                 cpu Step 4
    Pc Should Be Equal              ${handler_address}

    # PIC_INT${source_id}_HANDLER_CODE
    ## A2=${source_id}
    Execute Command                 cpu Step 1
    Register Should Be Equal        A2  ${source_id}

    ## With edge-triggered gateways more steps are needed to step over the interrupt-pending bit
    ## clearing code, with level-triggered ones we need to have source state toggled before MRET.
    IF    ${source_edge_triggered}
        # 3 since MACRO_CLEAR_GATEWAY's `li tp, <ADDRESS>` becomes `lui tp, ...; addi tp, tp, ...`
        # for non-zero source IDs which is a fair assumption given that source ID 0 is never valid.
        Execute Command             cpu Step 3
    ELSE
        Execute Command             pic OnGPIO ${source_id} ${source_active_low}
    END

    ## MRET
    Execute Command                 cpu Step 1

    # The log could be present if we didn't jump exactly to the handler and executed any unset memory.
    Should Not Be In Log            Illegal instruction


External IRQ With Insufficient Priority Should Not Be Handled
    [Arguments]                     ${loop_pc}  ${reversed}

    IF    ${reversed}
        Set Source 2 Priority To 15
    ELSE
        Set Source 2 Priority To 0
    END

    Enable Source 2
    Set External Source 2 Interrupt Request
    PIC IRQ Should Be Unset

    # CPU should be kept in loop
    FOR    ${counter}    IN RANGE    0    2
        Execute Command             cpu Step 1
        Pc Should Be Equal          ${loop_pc}
    END


External IRQ With Priority Equal To Threshold Should Be Handled
    [Arguments]                     ${loop_pc}  ${threshold}

    Set Source 2 Priority To ${threshold}
    Enable Source 2
    Set External Source 2 Interrupt Request
    PIC IRQ Should Be Set

    Single External IRQ Should Be Handled
    ...    source_id=2  handler_address=${PIC_INT2_HANDLER_ADDRESS}  loop_pc=${loop_pc}


PIC Should Have Interrupt Source ${id} Pending
    ${meip}=  Execute Command       sysbus ReadDoubleWord ${${INTERRUPTS_PENDING_BASE} + 4*(${id} // 32)} context=cpu
    ${meip}=  Strip String          ${meip}

    ${bit}=   Evaluate              1 << ${id}
    Should Be Equal As Integers     ${${meip} & ${bit}}  ${bit}


PIC ${irq_name} Should Be ${Set_or_Unset}
    ${output}=  Execute Command     pic ${irq_name}
    ${output}=  Strip String        ${output}
    ${state_lower}=  Evaluate       "${Set_or_Unset}".lower()
    Should Be Equal As Strings      ${output}  GPIO: ${state_lower}


Register Should Be Equal
    [Arguments]                     ${register}  ${expected_output}

    IF    "${register}".startswith("A")
        ${register_index}=  Evaluate    ${renode_a0_index} + int("${register}"[1:])
        ${output}=  Execute Command     cpu GetRegister ${register_index}
    ELSE IF    "${register}".startswith("M")
        ${output}=  Execute Command     cpu ${register}
    ELSE
        Fail                            Unsupported register group: ${register}
    END
    Should Be Equal As Integers     ${output}  ${expected_output}


Set Source ${id} Priority To ${priority_level}
    ${reg_address}=  Evaluate       ${PRIORITY_LEVEL_BASE} + (${id} << 2)
    Execute Command                 sysbus WriteDoubleWord ${reg_address} ${priority_level} context=cpu


# Valid only for sources with active-high gateways.
${Set_or_Unset} External Source ${id} Interrupt Request
    IF    "${Set_or_Unset}" not in ["Set", "Unset"]
        Fail                        Invalid Set_or_Unset argument: ${Set_or_Unset}
    END

    ${new_state}=  Evaluate         "${Set_or_Unset}" == "Set"
    Execute Command                 pic OnGPIO ${id} ${new_state}


Single External IRQ Should Be Handled
    [Arguments]                     ${source_id}  ${handler_address}  ${loop_pc}
    ...                             ${source_active_low}=False  ${source_edge_triggered}=False

    External IRQ Should Be Handled  ${source_id}  ${handler_address}  ${loop_pc}  ${source_active_low}  ${source_edge_triggered}
    PIC IRQ Should Be Unset
    Pc Should Be Equal              ${loop_pc}


Should Step Over MTVEC#11
    # Step after raising an interrupt executes MTVEC instruction but lands right after it.
    # Therefore PC cannot be verified before or after Step if MTVEC instruction is jump.
    ${mtvec11_log}=  Set Variable   MTVEC#${MACHINE_EXTERNAL_INTERRUPT_INDEX} executed
    Execute Command                 cpu AddHook ${MTVEC_MIE_ENTRY_ADDRESS} "cpu.InfoLog('${mtvec11_log}')"
    Execute Command                 cpu Step
    Wait For Log Entry              ${mtvec11_log}  timeout=0
    Execute Command                 cpu RemoveAllHooks

External IRQ Should Be Handled With Standard Priority Order
    [Arguments]                     ${source_active_low}=False  ${source_edge_triggered}=False

    Create Machine                  ${source_edge_triggered}
    ${loop_pc}=  Add Init Program   destination=${INIT_PC}  priord=0  threshold=5  source_id=5  priority=10
    ...    source_active_low=${source_active_low}  source_edge_triggered=${source_edge_triggered}

    # Make source inactive before PIC is configured so that we don't have IRQ set right away.
    Execute Command                 pic OnGPIO 5 ${source_active_low}

    Execute Command                 emulation RunFor "0.000001"
    Pc Should Be Equal              ${loop_pc}
    PIC IRQ Should Be Unset

    # Set External Source 5 Interrupt Request
    Execute Command                 pic OnGPIO 5 ${{ False if ${source_active_low} else True }}
    IF    ${source_edge_triggered}
        # IRQ should remain set with edge-triggered gateways regardless of further signal changes.
        Execute Command             pic OnGPIO 5 ${source_active_low}
    END

    Single External IRQ Should Be Handled
    ...    source_id=5  handler_address=${PIC_INT5_HANDLER_ADDRESS}  loop_pc=${loop_pc}
    ...    source_active_low=${source_active_low}  source_edge_triggered=${source_edge_triggered}

    Pc Should Be Equal              ${loop_pc}


Test MaxPriorityIRQ And Interrupt Handling
    [Arguments]                     ${priord}
    Create Machine

    # Interrupt from source 2 is expected to be handled before the one from source 5
    # and to trigger MaxPriorityIRQ.
    ${priority2}=  Evaluate         "15" if ${priord} == 0 else "0"
    ${priority5}=  Evaluate         "10" if ${priord} == 0 else "3"

    ${loop_pc}=  Add Init Program   destination=${INIT_PC}  priord=${priord}  threshold=5  source_id=5  priority=${priority5}

    Execute Command                 emulation RunFor "0.000001"
    Pc Should Be Equal              ${loop_pc}
    PIC IRQ Should Be Unset

    Set External Source 5 Interrupt Request
    PIC Should Have Interrupt Source 5 Pending
    PIC IRQ Should Be Set
    PIC MaxPriorityIRQ Should Be Unset

    # It has a priority over source 5 and it's a max priority level for the given priority order.
    Set Source 2 Priority To ${priority2}
    Enable Source 2

    Set External Source 2 Interrupt Request
    PIC Should Have Interrupt Source 2 Pending
    PIC IRQ Should Be Set
    PIC MaxPriorityIRQ Should Be Set

    # Contrary to `Single External IRQ Should Be Handled`, in this case:
    # * PIC IRQ remains set because source 5's interrupt is still pending
    # * MRET jumps to MTVEC's MIE entry
    External IRQ Should Be Handled
    ...    source_id=2  handler_address=${PIC_INT2_HANDLER_ADDRESS}  loop_pc=${loop_pc}
    Pc Should Be Equal              ${MTVEC_MIE_ENTRY_ADDRESS}

    # IRQ should remain set but only the main one as source 5 isn't set to a max priority level.
    PIC IRQ Should Be Set
    PIC MaxPriorityIRQ Should Be Unset

    # IRQ from source 5 should now be handled the same as in cases of single IRQs.
    Single External IRQ Should Be Handled
    ...    source_id=5  handler_address=${PIC_INT5_HANDLER_ADDRESS}  loop_pc=${loop_pc}
    PIC MaxPriorityIRQ Should Be Unset


*** Test Cases ***


External IRQ Should Be Handled With Standard Priority Order And High Level Gateway
    External IRQ Should Be Handled With Standard Priority Order
    ...    source_active_low=False  source_edge_triggered=False

    Provides                        standard_priord_looped_after_handling_interrupt


External IRQ Should Be Handled With Standard Priority Order And Low Level Gateway
    External IRQ Should Be Handled With Standard Priority Order
    ...    source_active_low=True  source_edge_triggered=False


External IRQ Should Be Handled With Standard Priority Order And Low To High Edge Gateway
    External IRQ Should Be Handled With Standard Priority Order
    ...    source_active_low=False  source_edge_triggered=True


External IRQ Should Be Handled With Standard Priority Order And High To Low Edge Gateway
    External IRQ Should Be Handled With Standard Priority Order
    ...    source_active_low=True  source_edge_triggered=True


External IRQ With Priority Lower Than Threshold Should Not Be Handled
    Requires                        standard_priord_looped_after_handling_interrupt
    ${loop_pc}=  Execute Command    cpu Step

    External IRQ With Insufficient Priority Should Not Be Handled
    ...    ${loop_pc}    reversed=False


External IRQ With Priority Equal To Threshold Should Be Handled Standard
    Requires                        standard_priord_looped_after_handling_interrupt
    ${loop_pc}=  Execute Command    cpu Step

    External IRQ With Priority Equal To Threshold Should Be Handled
    ...    ${loop_pc}    threshold=5


External IRQ Should Be Handled With Reversed Priority Order
    Create Machine
    ${loop_pc}=  Add Init Program   destination=${INIT_PC}  priord=1  threshold=10  source_id=5  priority=5

    Execute Command                 emulation RunFor "0.000001"
    Pc Should Be Equal              ${loop_pc}
    PIC IRQ Should Be Unset

    Set External Source 5 Interrupt Request
    Single External IRQ Should Be Handled
    ...    source_id=5  handler_address=${PIC_INT5_HANDLER_ADDRESS}  loop_pc=${loop_pc}

    Pc Should Be Equal              ${loop_pc}
    Provides                        reversed_priord_looped_after_handling_interrupt


External IRQ With Reversed Priority Higher Than Threshold Should Not Be Handled
    Requires                        reversed_priord_looped_after_handling_interrupt
    ${loop_pc}=  Execute Command    cpu Step

    External IRQ With Insufficient Priority Should Not Be Handled
    ...    ${loop_pc}    reversed=True


External IRQ With Priority Equal To Threshold Should Be Handled Reversed
    Requires                        reversed_priord_looped_after_handling_interrupt
    ${loop_pc}=  Execute Command    cpu Step

    External IRQ With Priority Equal To Threshold Should Be Handled
    ...    ${loop_pc}    threshold=10


Threshold Change Should Trigger IRQ
    Create Machine
    ${loop_pc}=  Add Init Program   destination=${INIT_PC}  priord=1  threshold=10  source_id=5  priority=5

    Execute Command                 emulation RunFor "0.000001"
    Pc Should Be Equal              ${loop_pc}
    PIC IRQ Should Be Unset

    Set Source 2 Priority To 15
    Enable Source 2
    Set External Source 2 Interrupt Request
    PIC IRQ Should Be Unset

    Execute Command                 cpu SetRegister ${meipt} 15
    PIC IRQ Should Be Set

    Single External IRQ Should Be Handled
    ...    source_id=2  handler_address=${PIC_INT2_HANDLER_ADDRESS}  loop_pc=${loop_pc}


Test MaxPriorityIRQ And Interrupt Handling With Standard Priority Order
    Test MaxPriorityIRQ And Interrupt Handling
    ...    priord=0


Test MaxPriorityIRQ And Interrupt Handling With Reversed Priority Order
    Test MaxPriorityIRQ And Interrupt Handling
    ...    priord=1


Only MaxPriorityIRQ Should Wake Core From FwHalt
    Create Machine

    ${loop_pc}=  Add Init Program   destination=${INIT_PC}  priord=0  threshold=5  source_id=5  priority=10

    Execute Command                 emulation RunFor "0.000001"
    Pc Should Be Equal              ${loop_pc}
    PIC IRQ Should Be Unset

    Execute Command                 logLevel -1

    # Put core into FwHalt
    ${length}=  Execute Command        cpu AssembleBlock ${loop_pc} "li t0, 1; csrw ${mpmc}, t0; loop: j loop"
    ${loop_pc}=  Evaluate              ${loop_pc} + (${length} - 2)

    Execute Command                    emulation RunFor "0.000001"
    Pc Should Be Equal                 ${loop_pc}
    ${count_before}=  Execute Command  cpu GetCurrentInstructionsCount

    Set External Source 5 Interrupt Request
    PIC Should Have Interrupt Source 5 Pending
    PIC IRQ Should Be Set
    PIC MaxPriorityIRQ Should Be Unset

    # Check that the core is still sleeping
    Execute Command                   emulation RunFor "0.000001"
    Pc Should Be Equal                ${loop_pc}
    ${count_after}=  Execute Command  cpu GetCurrentInstructionsCount
    Should Be Equal                   ${count_before}  ${count_after}

    # It has a priority over source 5 and it's a max priority level for the given priority order.
    Set Source 2 Priority To 15
    Enable Source 2

    Set External Source 2 Interrupt Request
    PIC Should Have Interrupt Source 2 Pending
    PIC IRQ Should Be Set
    PIC MaxPriorityIRQ Should Be Set

    # Core should now have woken up
    External IRQ Should Be Handled
    ...    source_id=2  handler_address=${PIC_INT2_HANDLER_ADDRESS}  loop_pc=${loop_pc}
    Pc Should Be Equal              ${MTVEC_MIE_ENTRY_ADDRESS}

    # IRQ should remain set but only the main one as source 5 isn't set to a max priority level.
    PIC IRQ Should Be Set
    PIC MaxPriorityIRQ Should Be Unset

    # IRQ from source 5 should now be handled the same as in cases of single IRQs.
    Single External IRQ Should Be Handled
    ...    source_id=5  handler_address=${PIC_INT5_HANDLER_ADDRESS}  loop_pc=${loop_pc}
    PIC MaxPriorityIRQ Should Be Unset
