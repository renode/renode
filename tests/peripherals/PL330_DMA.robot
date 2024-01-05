*** Variables ***
${PLATFORM}                         platforms/cpus/cortex-a53-gicv3.repl
${BIN}                              https://dl.antmicro.com/projects/renode/zephyr-pl330-dma_loop_tests.elf-s_912392-0f726563ef89afccd24b1e7f35fdca8040e58487
${UART}                             sysbus.uart0

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString "dma_program_memory: Memory.MappedMemory @ sysbus 0x93B0000 { size: 0x10000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "dma: DMA.PL330_DMA @ sysbus 0x9300000"
    Execute Command                 sysbus LoadELF @${BIN}

    Create Terminal Tester          ${UART}           defaultPauseEmulation=True

*** Test Cases ***
Should Pass Zephyr DMA Loop Transfer Test
    Create Machine

    Wait For Line On Uart     I: Device pl330@9300000 initialized

    Wait For Line On Uart     PASS - test_test_dma0_m2m_loop
    Wait For Line On Uart     PASS - test_test_dma0_m2m_loop_repeated_start_stop

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL
