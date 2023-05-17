*** Variables ***
${UART}                             sysbus.usart1
${USER_LED}                         sysbus.gpioPortB.BlueLED
${USER_BUTTON}                      sysbus.gpioPortC.UserButton1
${PROJECT_URL}                      @https://dl.antmicro.com/projects/renode
${UART_PRINTF}                      ${PROJECT_URL}/stm32wba--cube_mx_UART_Printf.elf-s_414528-276b355f13e0fc82007222130810179e374d275e
${EXTI_ToggleLED}                   ${PROJECT_URL}/stm32wba--cubemx-EXTI_ToggleLedOnIT_Init.elf-s_196736-e4aae2df7e5f275593f31d5d94db7c852c1575f6

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

Should have Working EXTI
    Create Machine                 ${EXTI_TogglelED}
    Create LED Tester              ${USER_LED}  defaultTimeout=0.1

    Start Emulation

    Assert LED State               true

    Execute Command                ${USER_BUTTON} PressAndRelease
    Assert LED State               false

    Execute Command                ${USER_BUTTON} PressAndRelease
    Assert LED State               true
