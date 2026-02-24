*** Variables ***
${ELF}                              @https://dl.antmicro.com/projects/renode/versal2_rpu--zephyr-hello_world.elf-s_418164-fae7dbceeea7ab56e2762f25d3b3e26d27e41e29
${REPL}                             "${CURDIR}${/}ARM_SBSA_UART.repl"
${UART}                             sysbus.uart1

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${REPL}
    Execute Command                 sysbus LoadELF ${ELF}

*** Test Cases ***
Should show hello world demo
    Create Machine
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           Hello World!
