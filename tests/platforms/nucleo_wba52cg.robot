*** Variables ***
${UART}                             sysbus.usart1
${GREEN_LED}                        sysbus.gpioPortB.GreenLED
${BLUE_LED}                         sysbus.gpioPortB.BlueLED
${USER_BUTTON}                      sysbus.gpioPortC.UserButton1

${PROJECT_URL}                      @https://dl.antmicro.com/projects/renode
${UART_PRINTF}                      ${PROJECT_URL}/stm32wba--cube_mx_UART_Printf.elf-s_414528-276b355f13e0fc82007222130810179e374d275e
${EXTI_ToggleLED}                   ${PROJECT_URL}/stm32wba--cubemx-EXTI_ToggleLedOnIT_Init.elf-s_196736-e4aae2df7e5f275593f31d5d94db7c852c1575f6
${SPI_POLLING}                      ${PROJECT_URL}/stm32wba52--cube_mx--SPI_FullDuplex_ComPolling_Master.elf-s_351444-751cf3ade71c0e0ff33c010a97ab61f9a97e7487
${SPI_INTERRUPT}                    ${PROJECT_URL}/stm32wba52--cube_mx--SPI_FullDuplex_ComIT_Master.elf-s_370676-fdb46bf729f660edb79ff64bf10f6da8e0dc517b

${PLATFORM}                         @platforms/boards/nucleo_wba52cg.repl
${SPI_LOOPBACK}                     loopback: SPI.SPILoopback @ spi3

*** Keywords ***
Create Machine
    [Arguments]                     ${elf}

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}

    Execute Command                 sysbus LoadELF ${elf}

Run SPI Test Case
    [Arguments]                     ${elf}

    Create Machine                  ${elf}
    Execute Command                 machine LoadPlatformDescriptionFromString "${SPI_LOOPBACK}"
    Create LED Tester               ${GREEN_LED}  defaultTimeout=0.5

    # The green LED should be off to start with
    Assert LED State                false

    # Trigger the SPI transfer
    Execute Command                 ${USER_BUTTON} Press

    # The green LED should turn on indicating that the transfer was successful and
    # the received data was correct (identical to the sent data)
    Assert LED State                true

*** Test Cases ***
Should Have Working UART
    Create Machine                  ${UART_PRINTF}
    Create Terminal Tester          ${UART}

    Start Emulation

    Wait For Line On Uart           UART Printf Example
    Wait For Line On Uart           ** Test finished successfully. **

Should have Working EXTI
    Create Machine                 ${EXTI_TogglelED}
    Create LED Tester              ${BLUE_LED}  defaultTimeout=0.1

    Start Emulation

    Assert LED State               false

    Execute Command                ${USER_BUTTON} PressAndRelease
    Assert LED State               true

    Execute Command                ${USER_BUTTON} PressAndRelease
    Assert LED State               false

SPI Should Work In Polling Mode
    Run SPI Test Case               ${SPI_POLLING}

SPI Should Work In Interrupt Mode
    Run SPI Test Case               ${SPI_INTERRUPT}
