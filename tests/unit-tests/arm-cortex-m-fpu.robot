*** Variables ***
${ZEPHYR_GENERIC_BIN}               @https://dl.antmicro.com/projects/renode/frdm_k64f--zephyr-fpu_sharing_generic.elf-s_861928-bef2795db6dd11f8106387ff6c6afd35686c48de
${STACKING_PLATFORM_TEST_V7M}       @https://dl.antmicro.com/projects/renode/cortex-v7m-extended-frame-test.elf-s_91928-d49ec01cc0c6270f7055330871953182a507efc6
${STACKING_PLATFORM_TEST_V8M}       @https://dl.antmicro.com/projects/renode/cortex-v8m_tz-extended-frame-test.elf-s_92692-88fe4c7b72824b0d3700927033873924025c2b7d

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
