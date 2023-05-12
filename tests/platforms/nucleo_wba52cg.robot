*** Variables ***
${UART}                             sysbus.usart1
${UART_PRINTF}                      @https://dl.antmicro.com/projects/renode/stm32wba--cube_mx_UART_Printf.elf-s_414528-276b355f13e0fc82007222130810179e374d275e
${PLATFORM}                         @platforms/boards/nucleo_wba52cg.repl

*** Keywords ***
Create Machine
    [Arguments]                     ${elf}

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}

    Execute Command                 sysbus LoadELF ${elf}

*** Test Cases ***
Should Have Working UART
    Create Machine                  ${UART_PRINTF}
    Create Terminal Tester          ${UART}

    Start Emulation

    Wait For Line On Uart           UART Printf Example
    Wait For Line On Uart           ** Test finished successfully. **
