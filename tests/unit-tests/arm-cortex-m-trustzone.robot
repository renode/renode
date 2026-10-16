*** Settings ***
Resource                            arm-cortex-m-common.robot

*** Variables ***
${SRAM_BASE_S}                      ${0x20020000}
${SRAM_BASE_NS}                     ${0x30020000}
${SRAM_CPU0_CODE_S}                 ${0x20021000}
${SRAM_CPU0_STACKTOP_S}             ${0x20021F80}
${SRAM_CPU0_CODE_NS}                ${0x30023000}
${SRAM_CPU0_STACKTOP_NS}            ${0x30023F80}
${UART_BASE_S}                      ${0x40208000}
${UART_BASE_NS}                     ${0x50208000}
${SAU_FAULT_ADDRESS}                ${{$SRAM_CPU0_CODE_S + 0x100}}
${SRAM_CPU0_SECURE_FAULT_CODE}      ${0x20021200}
${SRAM_BASE_RESERVED}               ${0xF0000000}

${CPU}                              sysbus.cpu0
${STACKED_PC_POSITION}              6

${REPL_STRING}                      SEPARATOR=\n
...                                 """
...                                 sram: Memory.ArrayMemory @ {
...                                 ${SPACE*8}sysbus 0x0;
...                                 ${SPACE*8}sysbus ${SRAM_BASE_S};
...                                 ${SPACE*8}sysbus ${SRAM_BASE_NS};
...                                 ${SPACE*8}sysbus ${SRAM_BASE_RESERVED};
...                                 ${SPACE*4}}
...                                 ${SPACE*4}size: 0x80000
...
...                                 nvic0: IRQControllers.NVIC @ {
...                                 ${SPACE*8}sysbus new Bus.BusPointRegistration { address: 0xE000E000; cpu: cpu0 };
...                                 ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0xE002E000; size: 0x1000; region: "NonSecure"; cpu: cpu0 }
...                                 ${SPACE*4}}
...                                 ${SPACE*4}-> cpu0@0
...
...                                 cpu0: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m55"
...                                 ${SPACE*4}nvic: nvic0
...                                 ${SPACE*4}cpuId: 0
...                                 ${SPACE*4}enableTrustZone: true
...
...                                 uart: UART.TrivialUart @ {
...                                 ${SPACE*4}sysbus ${UART_BASE_S};
...                                 ${SPACE*4}sysbus ${UART_BASE_NS}
...                                 }
...                                 """

${TRUSTZONE_TEST_S}                 SEPARATOR=\n
...                                 ldr sp, =${SRAM_CPU0_STACKTOP_S}
...                                 adr r3, cpu0_strings
...                                 ldr r4, =${UART_BASE_S}
...                                 ldr r0, =${SRAM_CPU0_CODE_NS}
...                                 ldr r11, [r0, #4] // r11 = initial PC from nonsecure vector table
...                                 bic r11, #1 // blxns instr expects bit[0] clear for branch to nonsecure
...                                 bl str_print // hello
...                                 // configure SAU region 0
...                                 // start=(SRAM_CPU0_CODE_NS) limit=(SRAM_CPU0_STACKTOP_NS) nonsecure
...                                 ldr r9, =0xe000edd0
...                                 mov r10, #0
...                                 str r10, [r9, #0x8] // SAU->RNR = 0
...                                 str r0, [r9, #0xc] // SAU->RBAR = (SRAM_CPU0_CODE_NS)
...                                 ldr r10, =${SRAM_CPU0_STACKTOP_NS}+0x1
...                                 str r10, [r9, #0x10] // SAU->RLAR = (SRAM_CPU0_STACKTOP_NS) | (nonsecure)
...                                 // configure SAU region 1
...                                 // start=0x50000000 limit=0x5fffffe0 nonsecure
...                                 mov r10, #1
...                                 str r10, [r9, #0x8] // SAU->RNR = 1
...                                 ldr r10, =0x50000000
...                                 str r10, [r9, #0xc] // SAU->RBAR = 0x50000000
...                                 ldr r10, =0x5fffffe1
...                                 str r10, [r9, #0x10] // SAU->RLAR = 0x5fffffe0 | (nonsecure)
...                                 // enable SAU
...                                 mov r10, #3
...                                 str r10, [r9] // SAU->CTRL = (enable) | (allns)
...                                 // set nonsecure vector table ptr
...                                 ldr r9, =0xe002ed08
...                                 str r0, [r9] // SCB->VTOR_NS = (SRAM_CPU0_CODE_NS)
...                                 // initialize MSP_NS
...                                 ldr r10, [r0]
...                                 msr msp_ns, r10
...                                 // synchronization barrier
...                                 dsb
...                                 isb
...                                 // ready to call nonsecure
...                                 blxns r11 // test 1
...                                 1: wfi
...                                 b 1b
...                                 cpu0_strings:
...                                 .asciz "Hello from cpu0 secure\\n"
...
...                                 str_print:
...                                 push {r7, lr}
...                                 1: ldrb r7, [r3] // iterate chars in string
...                                 add r3, r3, #1
...                                 cbz r7, 2f
...                                 str r7, [r4] // write char
...                                 b 1b
...                                 2: pop {r7, pc}

${TRUSTZONE_TEST_NS}                SEPARATOR=\n
...                                 // nonsecure vector table
...                                 .word ${SRAM_CPU0_STACKTOP_NS} // initial SP
...                                 .word ${SRAM_CPU0_CODE_NS}+0x201 // initial PC = nonsecure_app
...                                 .fill (9), 4, 0 // unused vectors
...                                 .word ${SRAM_CPU0_CODE_NS}+0x201+nonsecure_svc_handler-nonsecure_app
...                                 .align 8 // hack to get org to ${SRAM_CPU0_CODE_NS}+0x100
...                                 nonsecure_str_ptr:
...                                 .word nonsecure_hello
...                                 .word svc_hello
...                                 nonsecure_hello:
...                                 .asciz "Hello from cpu0 nonsecure\\n"
...                                 svc_hello:
...                                 .asciz "Hello from cpu0 svc\\n"
...                                 .align 9 // hack to get org to ${SRAM_CPU0_CODE_NS}+0x200
...                                 nonsecure_app:
...                                 push {r0, r4, r5, lr}
...                                 ldr r4, =${UART_BASE_NS}
...                                 ldr r5, =nonsecure_hello
...                                 bl nonsecure_print
...                                 svc #0
...                                 1: wfi
...                                 b 1b
...                                 nonsecure_svc_handler:
...                                 ldr r4, =${UART_BASE_NS}
...                                 ldr r5, =svc_hello
...                                 bl nonsecure_print
...                                 1: wfi
...                                 b 1b
...                                 nonsecure_print:
...                                 push {r3, r7, lr}
...                                 mov r3, r5
...                                 1: ldrb r7, [r3] // iterate chars in string
...                                 add r3, r3, #1
...                                 cbz r7, 2f
...                                 str r7, [r4]  // write char
...                                 b 1b
...                                 2: str r3, [r5]
...                                 pop {r3, r7, pc}

${SECURE_FAULT_HANDLER}             SEPARATOR=\n
...                                 b .

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL_STRING}

Setup SecureFault Handler
    ${shcsr}=                       Execute Command  sysbus ReadDoubleWord ${SCB_SHCSR} context=${CPU}
    Execute Command                 sysbus WriteDoubleWord ${SCB_SHCSR} ${{ ${shcsr.strip()} | (1<<19) }} context=${CPU}  # Enable SecureFault exception through SHCSR.SECUREFAULTENA
    Execute Command                 sysbus WriteDoubleWord 0x1C ${{ ${SRAM_CPU0_SECURE_FAULT_CODE} | 1 }}  # Set destination for SecureFault exception
    Execute Command                 ${CPU} AssembleBlock ${SRAM_CPU0_SECURE_FAULT_CODE} """${SECURE_FAULT_HANDLER}"""

Setup SAU/IDAU Test
    Create Machine
    Setup SecureFault Handler
    Execute Command                 ${CPU} PC ${SRAM_CPU0_CODE_S}
    Execute Command                 ${CPU} SetRegister "SP" ${SRAM_CPU0_STACKTOP_S}
    Execute Command                 ${CPU} SetRegister "MSPNS" ${SRAM_CPU0_STACKTOP_NS}

Assemble Jump to NS
    [Arguments]                     ${address}
    Execute Command                 ${CPU} AssembleBlock ${address} "blxns r0"

Assemble Write To Memory
    [Arguments]                     ${address}
    Execute Command                 ${CPU} AssembleBlock ${address} "str r2, [r1]"

Assemble SG and Jump to Self
    [Arguments]                     ${address}
    Execute Command                 ${CPU} AssembleBlock ${address} "sg; b ."

Assemble Jump to Self
    [Arguments]                     ${address}
    Execute Command                 ${CPU} AssembleBlock ${address} "b ."

Add SAU Region
    [Arguments]                     ${id}
    ...                             ${base}
    ...                             ${limit}
    ...                             ${enabled}=${True}
    ...                             ${callable}=${False}

    ${options}=                     Evaluate  (0x2 * int(${callable})) | (0x1 * int(${enabled}))

    Execute Command                 ${CPU} SAURegionNumber ${id}
    Execute Command                 ${CPU} SAURegionBaseAddress ${{ ${base} & ~0x1F }}
    Execute Command                 ${CPU} SAURegionLimitAddress ${{ (${limit} & ~0x1F) | ${options} }}

Add IDAU Region
    [Arguments]                     ${id}
    ...                             ${base}
    ...                             ${limit}
    ...                             ${enabled}=${True}
    ...                             ${callable}=${False}

    Execute Command                 ${CPU} SetIDAURegion ${id} ${{ ${base} & ~0x1F }} ${{ ${limit} | 0x1F }} ${enabled} ${callable}

${width} ${io} Should Be Equal
    [Arguments]                     ${expected}
    ...                             ${message}=${None}

    ${val}=                         Execute Command  sysbus Read${width} ${io} context=${CPU}
    IF  not $message
        ${message}=                     Set Variable  Value at ${io} doesn't match
    END
    Should Be Equal As Integers     ${val}  ${expected}  msg=${message}

Stack Element Should Be Equal
    [Arguments]                     ${position}
    ...                             ${expected}
    ...                             ${sp}=SP
    ${sp}=                          Execute Command  ${CPU} ${sp}
    DoubleWord ${{ ${sp.strip()} + ${position} * 4 }} Should Be Equal  ${expected}  message=${position} stacked element doesn't match

Assert Secure Fault
    [Arguments]                     ${sfsr}=${None}
    ...                             ${sfar}=${None}
    ...                             ${fault_pc}=${SRAM_CPU0_CODE_NS}
    ...                             ${pc}=${SRAM_CPU0_SECURE_FAULT_CODE}
    ...                             ${sp}=MSPNS

    PC Should be Equal              ${pc}
    Stack Element Should Be Equal   ${STACKED_PC_POSITION}  ${fault_pc}  sp=${sp}

    IF  $sfsr
        DoubleWord ${SCB_SFSR} Should Be Equal  ${sfsr}
    END

    IF  $sfar
        DoubleWord ${SCB_SFAR} Should Be Equal  ${sfar}
    END

Test SecureFault on FPU Instruction
    [Arguments]                     ${instruction}
    ...                             ${fault_address}

    Reset Emulation
    Setup SAU/IDAU Test

    Execute Command                 sysbus WriteDoubleWord ${SCB_CPACR} ${CPACR_CP10_CP11_FULL_ACCESS} context=${CPU}
    Execute Command                 sysbus WriteDoubleWord ${SCB_NSACR} ${NSACR_CP10_CP11_FULL_ACCESS} context=${CPU}
    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Execute Command                 ${CPU} SetRegister "R1" ${fault_address}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Execute Command                 ${CPU} AssembleBlock ${SRAM_CPU0_CODE_NS} "${instruction}"

    Execute Command                 ${CPU} SAUControl 1
    Add SAU Region                  0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             sfsr=${{ $SFSR_AUVIOL | $SFSR_SFARVALID }}  sfar=${fault_address}

Test ${sp_type:(MSPCURR|PSPCURR|MSPS|PSPS|MSPNS|PSPNS)} Register Access
    [Arguments]                     ${uses_psp}
    ...                             ${is_secure}

    TRY
        Reset Emulation
        Create Machine

        IF  "${sp_type}" == "MSPCURR"
            ${arm_name}=                    Set Variable  MSP
        ELSE IF  "${sp_type}" == "PSPCURR"
            ${arm_name}=                    Set Variable  PSP
        ELSE IF  "${sp_type}" == "MSPS"
            ${arm_name}=                    Set Variable  MSP
        ELSE IF  "${sp_type}" == "PSPS"
            ${arm_name}=                    Set Variable  PSP
        ELSE IF  "${sp_type}" == "MSPNS"
            IF  ${is_secure}
                ${arm_name}=                    Set Variable  MSP_NS
            ELSE
                ${arm_name}=                    Set Variable  MSP
            END
        ELSE IF  "${sp_type}" == "PSPNS"
            IF  ${is_secure}
                ${arm_name}=                    Set Variable  PSP_NS
            ELSE
                ${arm_name}=                    Set Variable  PSP
            END
        END

        ${steps}=                       Set Variable  ${0}

        IF  not ${is_secure}
            Execute Command                 ${CPU} AssembleBlock ${SRAM_CPU0_CODE_S} """blxns r0"""
            ${address}=                     Set Variable  ${SRAM_CPU0_CODE_NS}
            ${steps}=                       Evaluate  ${steps} + 1
        ELSE
            ${address}=                     Set Variable  ${SRAM_CPU0_CODE_S}
        END

        IF  ${uses_psp}
            # Set current SPSEL to use Process Stack Pointer
            ${assembly}=                    Catenate  SEPARATOR=\n
            ...                             mrs r0, CONTROL
            ...                             orr r0, #0x00000002
            ...                             msr CONTROL, r0
            ...                             mrs r0, ${arm_name}
            Execute Command                 ${CPU} AssembleBlock ${address} """${assembly}"""
            ${steps}=                       Evaluate  ${steps} + 3
        ELSE
            Execute Command                 ${CPU} AssembleBlock ${address} """mrs r0, ${arm_name}"""
        END

        Execute Command                 ${CPU} SAUControl 1
        Add SAU Region                  0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}

        Execute Command                 ${CPU} PC ${SRAM_CPU0_CODE_S}
        Execute Command                 ${CPU} SetRegister "r0" ${SRAM_CPU0_CODE_NS}

        ${test_value}=                  Set Variable  0xdeadbeef
        ${trimmed_test_value}=          Evaluate  hex(${test_value} & 0xfffffffc)

        Execute Command                 ${CPU} Step ${steps}  # Step until we're in state defined by uses_psp and is_secure
        Execute Command                 ${CPU} SetRegister "${sp_type}" ${test_value}

        Execute Command                 ${CPU} Step 1  # Run until read from sp register

        Register Should Be Equal        ${sp_type}  ${trimmed_test_value}
        Register Should Be Equal        R0  ${trimmed_test_value}
    EXCEPT  AS  ${message}
        Fail                            sp_type=${sp_type} uses_psp=${uses_psp} is_secure=${is_secure}: ${message}
    END

*** Test Cases ***
Should Print Hello From Both States
    Create Machine
    Execute Command                 showAnalyzer sysbus.uart
    Create Terminal Tester          sysbus.uart
    Execute Command                 ${CPU} PC ${SRAM_CPU0_CODE_S}
    Execute Command                 ${CPU} AssembleBlock `${CPU} PC` """${TRUSTZONE_TEST_S}"""
    Execute Command                 ${CPU} AssembleBlock ${SRAM_CPU0_CODE_NS} """${TRUSTZONE_TEST_NS}"""
    Wait For Line On Uart           Hello from cpu0 secure
    Wait For Line On Uart           Hello from cpu0 nonsecure
    Wait For Line On Uart           Hello from cpu0 svc

Should Stop Before Executing Handler On Instruction Fetch SecureFault
    Create Machine
    # The SAU attributes ${SAU_FAULT_ADDRESS} as Non-secure (an enabled region with the NSC
    # bit cleared), so the instruction fetch at ${SAU_FAULT_ADDRESS} in Secure state raises
    # raises an INVTRAN SecureFault, which escalates to HardFault.
    Execute Command                 sysbus WriteDoubleWord ${{$SRAM_BASE_S + 0xC}} ${{$SRAM_CPU0_CODE_S | 1}}  # HardFault vector
    Execute Command                 ${CPU} VectorTableOffset ${SRAM_BASE_S}
    Execute Command                 ${CPU} AssembleBlock ${SRAM_CPU0_CODE_S} "nop; nop; nop"
    Execute Command                 ${CPU} AssembleBlock ${SAU_FAULT_ADDRESS} "nop; nop; nop"
    Execute Command                 ${CPU} SP ${SRAM_CPU0_STACKTOP_S}
    Execute Command                 ${CPU} PC ${{$SAU_FAULT_ADDRESS | 1}}
    Execute Command                 ${CPU} SAURegionNumber 0
    Execute Command                 ${CPU} SAURegionBaseAddress ${SAU_FAULT_ADDRESS}
    Execute Command                 ${CPU} SAURegionLimitAddress ${{$SAU_FAULT_ADDRESS | 1}}
    Execute Command                 ${CPU} SAUControl 1

    # The SecureFault is raised on the instruction fetch, before any instruction is
    # executed. The step must stop on the boundary of the faulting fetch, so before
    # executing the first instruction of the HardFault handler.
    Execute Command                 ${CPU} Step 1
    PC Should Be Equal              ${SRAM_CPU0_CODE_S}
    DoubleWord ${SCB_SFSR} Should Be Equal  ${SFSR_INVTRAN}

Should Execute Instructions Preceding Instruction Fetch SecureFault
    Create Machine
    # The handler sleeps on `wfe` after two nops.
    Execute Command                 sysbus WriteDoubleWord ${{$SRAM_BASE_S + 12}} ${{$SRAM_CPU0_CODE_S | 1}}
    Execute Command                 ${CPU} VectorTableOffset ${SRAM_BASE_S}
    Execute Command                 ${CPU} AssembleBlock ${SRAM_CPU0_CODE_S} "nop; nop; wfe; nop"
    # The instructions at $SAU_FAULT_ADDRESS - 6 are outside the Non-secure region
    # so the instruction fetch at $SAU_FAULT_ADDRESS raises an INVTRAN SecureFault
    # in Secure state.
    Execute Command                 ${CPU} AssembleBlock ${{$SAU_FAULT_ADDRESS - 6}} "movs r0, #1; movs r1, #2; nop; nop; nop"
    Execute Command                 ${CPU} SP ${SRAM_CPU0_STACKTOP_S}
    Execute Command                 ${CPU} PC ${{$SAU_FAULT_ADDRESS - 6}}
    Execute Command                 ${CPU} SAURegionNumber 0
    Execute Command                 ${CPU} SAURegionBaseAddress ${SAU_FAULT_ADDRESS}
    Execute Command                 ${CPU} SAURegionLimitAddress ${{$SAU_FAULT_ADDRESS | 1}}
    Execute Command                 ${CPU} SAUControl 1

    # The fetch of the instruction at ${SAU_FAULT_ADDRESS} raises the SecureFault, but
    # the instructions preceding it must be executed before the exception is taken, as
    # the block containing them must not be discarded. A continuous run is required to
    # reach the faulting fetch within the same translated block, which ends with a wfe
    # sleep.
    Execute Command                 emulation RunFor "0.001"
    PC Should Be Equal              ${{$SRAM_CPU0_CODE_S + 6}}
    Register Should Be Equal        R0  1
    Register Should Be Equal        R1  2
    ${executed}=                    Execute Command  ${CPU} ExecutedInstructions
    Should Be Equal As Integers     ${executed}  7

Should Fault On Second Halfword Of First Thumb-2 Instruction
    [Timeout]                       15s
    Create Machine
    Execute Command                 sysbus WriteDoubleWord ${{$SRAM_BASE_S + 12}} ${{$SRAM_CPU0_CODE_S | 1}}
    Execute Command                 ${CPU} VectorTableOffset ${SRAM_BASE_S}
    Execute Command                 ${CPU} AssembleBlock ${SRAM_CPU0_CODE_S} "nop; nop; nop"
    # MOVW starts in Secure memory, but its second halfword is in the Non-secure region.
    Execute Command                 ${CPU} AssembleBlock ${{$SAU_FAULT_ADDRESS - 2}} "movw r0, #1; nop"
    Execute Command                 ${CPU} SP ${SRAM_CPU0_STACKTOP_S}
    Execute Command                 ${CPU} PC ${{$SAU_FAULT_ADDRESS - 2}}
    Execute Command                 ${CPU} SAURegionNumber 0
    Execute Command                 ${CPU} SAURegionBaseAddress ${SAU_FAULT_ADDRESS}
    Execute Command                 ${CPU} SAURegionLimitAddress ${{$SAU_FAULT_ADDRESS | 1}}
    Execute Command                 ${CPU} SAUControl 1

    Execute Command                 ${CPU} Step 1
    PC Should Be Equal              ${SRAM_CPU0_CODE_S}
    Register Should Be Equal        R0  0
    DoubleWord ${SCB_SFSR} Should Be Equal  ${SFSR_INVTRAN}

Should Execute Preceding Instructions Before Second Halfword Fetch Fault
    [Timeout]                       15s
    Create Machine
    Execute Command                 sysbus WriteDoubleWord ${{$SRAM_BASE_S + 12}} ${{$SRAM_CPU0_CODE_S | 1}}
    Execute Command                 ${CPU} VectorTableOffset ${SRAM_BASE_S}
    Execute Command                 ${CPU} AssembleBlock ${SRAM_CPU0_CODE_S} "nop; nop; wfe; nop"
    Execute Command                 ${CPU} AssembleBlock ${{$SAU_FAULT_ADDRESS - 6}} "movs r1, #2; nop; movw r0, #1; nop"
    Execute Command                 ${CPU} SP ${SRAM_CPU0_STACKTOP_S}
    Execute Command                 ${CPU} PC ${{$SAU_FAULT_ADDRESS - 6}}
    Execute Command                 ${CPU} SAURegionNumber 0
    Execute Command                 ${CPU} SAURegionBaseAddress ${SAU_FAULT_ADDRESS}
    Execute Command                 ${CPU} SAURegionLimitAddress ${{$SAU_FAULT_ADDRESS | 1}}
    Execute Command                 ${CPU} SAUControl 1
    Execute Command                 ${CPU} InstallOpcodeCounterPattern "faulting_movw" "11110xxxxxxxxxxx"
    Execute Command                 ${CPU} EnableOpcodesCounting true

    Execute Command                 emulation RunFor "0.001"
    PC Should Be Equal              ${{$SRAM_CPU0_CODE_S + 6}}
    Register Should Be Equal        R0  0
    Register Should Be Equal        R1  2
    DoubleWord ${SCB_SFSR} Should Be Equal  ${SFSR_INVTRAN}
    ${executed}=                    Execute Command  ${CPU} ExecutedInstructions
    Should Be Equal As Integers     ${executed}  6
    ${faulting_opcodes}=            Execute Command  ${CPU} GetOpcodeCounter "faulting_movw"
    Should Be Equal As Integers     ${faulting_opcodes}  0

Non-secure Should Fault at Execution on Secure SAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Add SAU Region                  0  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}

Non-secure Should Fault at Execution on Secure Non-secure Callable SAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Add SAU Region                  0  ${SRAM_CPU0_CODE_NS}  ${{ ${SRAM_CPU0_CODE_NS} + 0x100 }}  callable=${True}
    Add SAU Region                  1  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}

Non-secure Should Enter Secure State on Secure Non-secure Callable SG on SAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble SG and Jump to Self    ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Add SAU Region                  0  ${SRAM_CPU0_CODE_NS}  ${{ ${SRAM_CPU0_CODE_NS} + 0x100 }}  callable=${True}
    Add SAU Region                  1  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    PC Should be Equal              ${SRAM_CPU0_CODE_NS+4}
    ${in_secure_state}=             Execute Command  cpu0 SecureState
    Should Be True                  ${in_secure_state}

Non-secure Should Fault at Write to Secure SAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Execute Command                 ${CPU} SetRegister "R1" ${SRAM_CPU0_STACKTOP_S}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Write To Memory        ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Add SAU Region                  0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             sfsr=${{ $SFSR_AUVIOL | $SFSR_SFARVALID }}  sfar=${SRAM_CPU0_STACKTOP_S}

Non-secure Should Fault at Execution on Secure IDAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 2
    Execute Command                 ${CPU} IDAUEnabled true
    Add IDAU Region                 0  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}

Non-secure Should Fault at Execution on Secure Non-secure Callable IDAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 2
    Execute Command                 ${CPU} IDAUEnabled true
    Add IDAU Region                 0  ${SRAM_CPU0_CODE_NS}  ${{ ${SRAM_CPU0_CODE_NS} + 0x100 }}  callable=${True}
    Add IDAU Region                 1  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}

Non-secure Should Enter Secure State on Secure Non-secure Callable SG on IDAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble SG and Jump to Self    ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 2
    Execute Command                 ${CPU} IDAUEnabled true
    Add IDAU Region                 0  ${SRAM_CPU0_CODE_NS}  ${{ ${SRAM_CPU0_CODE_NS} + 0x100 }}  callable=${True}
    Add IDAU Region                 1  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    PC Should be Equal              ${SRAM_CPU0_CODE_NS+4}
    ${in_secure_state}=             Execute Command  cpu0 SecureState
    Should Be True                  ${in_secure_state}

Non-secure Should Fault at Write to Secure IDAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Execute Command                 ${CPU} SetRegister "R1" ${SRAM_CPU0_STACKTOP_S}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Write To Memory        ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 2
    Execute Command                 ${CPU} IDAUEnabled true
    Add IDAU Region                 0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             sfsr=${{ $SFSR_AUVIOL | $SFSR_SFARVALID }}  sfar=${SRAM_CPU0_STACKTOP_S}

IDAU Secure Should Override SAU Non-secure Restrictions
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Execute Command                 ${CPU} IDAUEnabled true
    Add SAU Region                  0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}
    Add IDAU Region                 0  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}

IDAU Non-secure Should not Override SAU Secure Restrictions
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Execute Command                 ${CPU} IDAUEnabled true
    Add IDAU Region                 0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}
    Add SAU Region                  0  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}

IDAU Secure Non-secure Callable Should Override SAU Non-secure Restrictions
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Execute Command                 ${CPU} IDAUEnabled true
    Add SAU Region                  0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}
    Add IDAU Region                 0  ${SRAM_CPU0_CODE_NS}  ${{ ${SRAM_CPU0_CODE_NS} + 0x100 }}  callable=${True}
    Add IDAU Region                 1  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}

Non-secure Should Fault at Write to Secure Non-secure Callable SAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Execute Command                 ${CPU} SetRegister "R1" ${SRAM_CPU0_STACKTOP_S}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Write To Memory        ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Add SAU Region                  0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}
    Add SAU Region                  1  ${{ ${SRAM_CPU0_STACKTOP_S} - 0x100}}  ${{ ${SRAM_CPU0_STACKTOP_S} + 0x100 }}  callable=${True}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             sfsr=${{ $SFSR_AUVIOL | $SFSR_SFARVALID }}  sfar=${SRAM_CPU0_STACKTOP_S}

Non-secure Should Fault at Write to Secure Non-secure Callable IDAU Address
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Execute Command                 ${CPU} SetRegister "R1" ${SRAM_CPU0_STACKTOP_S}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Write To Memory        ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 2
    Execute Command                 ${CPU} IDAUEnabled true
    Add IDAU Region                 0  ${SRAM_CPU0_CODE_NS}  ${SRAM_CPU0_STACKTOP_NS}
    Add IDAU Region                 1  ${{ ${SRAM_CPU0_STACKTOP_S} - 0x100}}  ${{ ${SRAM_CPU0_STACKTOP_S} + 0x100 }}  callable=${True}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             sfsr=${{ $SFSR_AUVIOL | $SFSR_SFARVALID }}  sfar=${SRAM_CPU0_STACKTOP_S}

Non-secure Should Fault at Execution on Upper Address Range
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_BASE_RESERVED}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_BASE_RESERVED}

    Execute Command                 ${CPU} SAUControl 1
    Execute Command                 ${CPU} IDAUEnabled true
    Add SAU Region                  0  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}
    Add IDAU Region                 0  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}
    Add SAU Region                  1  ${SRAM_BASE_RESERVED}  ${{ ${SRAM_BASE_RESERVED} + 0x100 }}
    Add IDAU Region                 1  ${SRAM_BASE_RESERVED}  ${{ ${SRAM_BASE_RESERVED} + 0x100 }}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}  fault_pc=${SRAM_BASE_RESERVED}

Non-secure Should Fault at Execution on Overlapping SAU Regions
    Setup SAU/IDAU Test

    Execute Command                 ${CPU} SetRegister "R0" ${SRAM_CPU0_CODE_NS}
    Assemble Jump to NS             ${SRAM_CPU0_CODE_S}
    Assemble Jump to Self           ${SRAM_CPU0_CODE_NS}

    Execute Command                 ${CPU} SAUControl 1
    Add SAU Region                  0  ${{ ${SRAM_CPU0_STACKTOP_NS} - 0x100 }}  ${SRAM_CPU0_STACKTOP_NS}
    Add SAU Region                  1  ${SRAM_CPU0_CODE_NS}  ${{ ${SRAM_CPU0_CODE_NS} + 0x100 }}
    Add SAU Region                  2  ${SRAM_CPU0_CODE_NS}  ${{ ${SRAM_CPU0_CODE_NS} + 0x100 }}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVEP}  fault_pc=${SRAM_CPU0_CODE_NS}

Secure Should Fault at Execution on Non-secure SAU Address
    Setup SAU/IDAU Test

    Assemble Jump to Self           ${SRAM_CPU0_CODE_S}

    Execute Command                 ${CPU} SAUControl 1
    Add SAU Region                  0  ${SRAM_CPU0_CODE_S}  ${{ ${SRAM_CPU0_CODE_S} + 0x100 }}

    Execute Command                 emulation RunFor "0.01"

    Assert Secure Fault             ${SFSR_INVTRAN}  fault_pc=${SRAM_CPU0_CODE_S}  sp=SP

Should Raise SecureFault on Width Varied MVE Instructions
    # The following instructions can access memory on different alignment
    # The following test is supposed to test if the SecureFault is risen properly even when memory fetches aren't 32-bit aligned
    ${base_address}=                Set Variable  ${{ ${SRAM_CPU0_STACKTOP_NS} + 0x20 }}
    FOR  ${instruction_template}  IN
    ...  VST40.{0} {{Q0, Q1, Q2, Q3}}, [r1]
    ...  VLD40.{0} {{Q0, Q1, Q2, Q3}}, [r1]
    ...  VST20.{0} {{Q0, Q1}}, [r1]
    ...  VLD20.{0} {{Q0, Q1}}, [r1]
    ...  VSTR{1}.u32 Q0, [r1]
    ...  VLDR{1}.u32 Q0, [r1]
    ...  VSTR{1}.u32 Q0, [r1, Q5]  # Q5 should be equal 0 so access will happen exactly at address contained in r1
    ...  VLDR{1}.u32 Q0, [r1, Q5]
        FOR  ${element}  IN  0  1  2
            ${alignment}=                   Set Variable  0
            WHILE  ${alignment} < 32
                ${size}=                        Evaluate  (8 << ${element})
                ${letter}=                      Evaluate  ["B", "H", "W"][${element}]

                ${instruction}=                 Evaluate  "${instruction_template}".format(${size}, "${letter}")
                ${address}=                     Evaluate  ${base_address} + ${alignment} // 8

                Execute Command                 log "Testing ${instruction} with R1=${address}"
                TRY
                    Test SecureFault on FPU Instruction  ${instruction}  ${address}
                EXCEPT  AS  ${message}
                    Fail                            ${instruction} with alignment=${alignment}: ${message}
                END
                Reset Emulation

                ${alignment}=                   Evaluate  ${alignment} + ${size}
            END
        END
    END

Should Raise SecureFault on VSTR/VLDR Instructions
    ${base_address}=                Set Variable  ${{ ${SRAM_CPU0_STACKTOP_NS} + 0x20 }}
    FOR  ${instruction}  ${address}  IN
    ...  VSTRD.s64 Q0, [r1, Q5]  ${base_address}
    ...  VLDRD.s64 Q0, [r1, Q5]  ${base_address}
    ...  VSTR s0, [r1]  ${base_address}
    ...  VSTR d0, [r1]  ${base_address}
    ...  VSTR d0, [r1]  ${{ ${base_address} + 0x4 }}
    ...  VLDR s0, [r1]  ${base_address}
    ...  VLDR d0, [r1]  ${base_address}
    ...  VSTR d0, [r1]  ${{ ${base_address} + 0x4 }}
    ...  VSTR FPSCR, [r1]  ${base_address}
    ...  VLDR FPSCR, [r1]  ${base_address}
        Execute Command                 log "Testing ${instruction} with R1=${address}"
        TRY
            Test SecureFault on FPU Instruction  ${instruction}  ${address}
        EXCEPT  AS  ${message}
            Fail                            ${instruction} with address=${{ hex(${address}) }}: ${message}
        END
    END

Should Test SP Register Secure Access
    FOR  ${uses_psp}  IN  True  False
        Test MSPCURR Register Access    ${uses_psp}  is_secure=True
        Test PSPCURR Register Access    ${uses_psp}  is_secure=True
        Test MSPS Register Access       ${uses_psp}  is_secure=True
        Test PSPS Register Access       ${uses_psp}  is_secure=True
        Test MSPNS Register Access      ${uses_psp}  is_secure=True
        Test PSPNS Register Access      ${uses_psp}  is_secure=True
    END

Should Test SP Register Non-secure Access
    FOR  ${uses_psp}  IN  True  False
        Test MSPCURR Register Access    ${uses_psp}  is_secure=False
        Test PSPCURR Register Access    ${uses_psp}  is_secure=False
        Test MSPNS Register Access      ${uses_psp}  is_secure=False
        Test PSPNS Register Access      ${uses_psp}  is_secure=False
    END
