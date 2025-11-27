*** Variables ***
${ZEPHYR_GENERIC_BIN}               @https://dl.antmicro.com/projects/renode/frdm_k64f--zephyr-fpu_sharing_generic.elf-s_861928-bef2795db6dd11f8106387ff6c6afd35686c48de
${STACKING_PLATFORM_TEST_V7M}       @https://dl.antmicro.com/projects/renode/cortex-v7m-extended-frame-test.elf-s_91928-d49ec01cc0c6270f7055330871953182a507efc6
${STACKING_PLATFORM_TEST_V8M}       @https://dl.antmicro.com/projects/renode/cortex-v8m_tz-extended-frame-test.elf-s_92692-88fe4c7b72824b0d3700927033873924025c2b7d

${NOCP_UART}                        0x100000
${NOCP_SCB_CSFR}                    0xE000ED2A
${NOCP_SCB_SHCSR}                   0xE000ED24
${NOCP_ASSEMBLY}                    SEPARATOR=\n
...                                 """
...                                 Vector_Table:
...                                 .word 0x1000  // SP
...                                 .word Reset_Handler+1
...                                 .word 0
...                                 .word 0
...                                 .word 0
...                                 .word 0
...                                 .word UsageFault_Handler+1
...                                 .align 12
...
...                                 Reset_Handler:
...                                 ldr r1, =${NOCP_SCB_SHCSR}
...                                 ldr r2, [r1]
...                                 orr r2, r2, 0x40000  // (1u << 18) SCB_SHCSR_USGFAULTENA
...                                 str r2, [r1]
...                                 mov r3, ${NOCP_UART}
...
...                                 mov r7, 0x200
...                                 mov r2, Vector_Table
...                                 vldr s15, [r2]
...                                 vcvt.s32.f32 s15, s15
...                                 vcvt.f32.s32 s15, s15
...                                 vstr s15, [r7]
...
...                                 ldr r4, =String_OK
...                                 b Print_String
...
...                                 Print_String:
...                             1:  ldrb r0, [r4]
...                                 add r4, r4, #1
...                                 cmp r0, #0
...                                 beq 2f
...                                 strb r0, [r3]
...                                 b 1b
...                             2:  wfi
...
...                                 UsageFault_Handler:
...                                 ldr r1, =${NOCP_SCB_CSFR}
...                                 ldr r2, [r1]
...                                 mov r1, 0b1000 // NOCP bit
...                                 ldr r4, =String_NOCP
...                                 cmp r1, r2
...                                 beq Print_String
...                                 wfi
...
...                                 String_NOCP:
...                                 .asciz "NOCP\n"
...                                 String_OK:
...                                 .asciz "OK\n"
...                                 """

${STACKING_PLATFORM_COMMON}         SEPARATOR=\n  """
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x40000
...                                 uart: UART.NS16550 @ sysbus 0x80000
...                                 """

${STACKING_PLATFORM_V7M}            SEPARATOR=\n  """
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m4"
...                                 ${SPACE*4}nvic: nvic
...                                 nvic: IRQControllers.NVIC @ sysbus 0xe000e000
...                                 ${SPACE*4}-> cpu@0
...                                 """

${STACKING_PLATFORM_V8M}            SEPARATOR=\n  """
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m33"
...                                 ${SPACE*4}enableTrustZone: true
...                                 ${SPACE*4}nvic: nvic
...                                 nvic: IRQControllers.NVIC @ sysbus 0xe000e000
...                                 ${SPACE*4}-> cpu@0
...                                 """

${TRIVIAL_PLATFORM_V8M}             SEPARATOR=\n  """
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x40000
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m33"
...                                 ${SPACE*4}nvic: nvic
...                                 nvic: IRQControllers.NVIC @ sysbus 0xe000e000
...                                 ${SPACE*4}-> cpu@0
...                                 uart: UART.TrivialUart @ sysbus 0x100000
...                                 """

*** Keywords ***
Prepare Trivial Platform
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${TRIVIAL_PLATFORM_V8M}
    Create Terminal Tester          sysbus.uart  defaultPauseEmulation=True
    Execute Command                 cpu AssembleBlock 0x10000 ${NOCP_ASSEMBLY}
    Execute Command                 cpu VectorTableOffset 0x10000

*** Test Cases ***
Should Pass Zephyr FPU Sharing Generic Tests
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/nxp-k6xf.repl
    Create Terminal Tester          sysbus.uart0
    Execute Command                 sysbus LoadELF ${ZEPHYR_GENERIC_BIN}

    Start Emulation
    ${result}=                      Wait For Line On Uart  PROJECT EXECUTION (SUCCESSFUL|FAILED)  timeout=32  treatAsRegex=true
    Should Contain                  ${result.Line}  SUCCESSFUL

Should Pass Context Stacking Preservation Test v7-M
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${STACKING_PLATFORM_COMMON}
    Execute Command                 machine LoadPlatformDescriptionFromString ${STACKING_PLATFORM_V7M}
    Create Terminal Tester          sysbus.uart  defaultPauseEmulation=True

    Execute Command                 sysbus LoadELF ${STACKING_PLATFORM_TEST_V7M}
    Execute Command                 cpu VectorTableOffset `sysbus GetSymbolAddress "vector_table"`

    Wait For Line On Uart           Test succeeded

Should Pass Context Stacking Preservation Test v8-M with TrustZone
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${STACKING_PLATFORM_COMMON}
    Execute Command                 machine LoadPlatformDescriptionFromString ${STACKING_PLATFORM_V8M}
    Create Terminal Tester          sysbus.uart  defaultPauseEmulation=True

    Execute Command                 sysbus LoadELF ${STACKING_PLATFORM_TEST_V8M}
    Execute Command                 cpu VectorTableOffset `sysbus GetSymbolAddress "vector_table"`

    Wait For Line On Uart           Test succeeded

Should Not Raise Exception
    Prepare Trivial Platform

    Execute Command                 cpu FpuEnabled true
    Wait For Line On Uart           OK

Should Raise NOCP Exception
    Prepare Trivial Platform

    Wait For Line On Uart           NOCP
