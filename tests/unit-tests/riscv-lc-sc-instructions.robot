*** Variables ***
${UART}                                sysbus.mmuart1
${URI}                                 @https://dl.antmicro.com/projects/renode
${PLATFORM}                            @platforms/cpus/polarfire-soc.repl


*** Test Cases ***

Should Handle LC and SC Instructions Properly
    Execute Command                    mach create
    Execute Command                    machine LoadPlatformDescription ${PLATFORM}
    Execute Command                    sysbus LoadELF ${URI}/zephyr-custom_lc_sc_instructions.elf-s_501480-bbacc1d271881ea90dba9f1b4a77561545c77545

    Create Terminal Tester             ${UART}

    Wait For Line On Uart              (first thread) number1: 1 (expected: 1), returned value: 0
    Wait For Line On Uart              (first thread) number1: 1 (expected: 1), returned value: 1
    Wait For Line On Uart              (second thread) number1: 1 (expected: 1), returned value: 1
    Wait For Line On Uart              (second thread) number1: 4 (expected: 4), returned value: 0
    Wait For Line On Uart              (first thread) number1: 4 (expected: 4), returned value: 1
    Wait For Line On Uart              (first thread) number1: 5 (expected: 5), returned value: 0
    Wait For Line On Uart              (first thread) number2: 6 (expected: 6), returned value: 0
    
