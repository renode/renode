*** Variables ***
${SRAM_BASE_S}                      0x20020000
${SRAM_BASE_NS}                     0x30020000
${SRAM_CPU0_CODE_S}                 0x20021000
${SRAM_CPU0_STACKTOP_S}             0x20021F80
${SRAM_CPU0_CODE_NS}                0x30023000
${SRAM_CPU0_STACKTOP_NS}            0x30023F80
${UART_BASE_S}                      0x40208000
${UART_BASE_NS}                     0x50208000
${CPU}                              sysbus.cpu0

${REPL_STRING}                      SEPARATOR=\n
...                                 """
...                                 sram: Memory.ArrayMemory @ {
...                                 ${SPACE*8}sysbus ${SRAM_BASE_S};
...                                 ${SPACE*8}sysbus ${SRAM_BASE_NS}
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
...                                 ${SPACE*4}cpuType: "cortex-m33"
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

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL_STRING}

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
