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
${TIM_PWMInput}                     ${PROJECT_URL}/stm32wba52-TIM_PWMInput.elf-s_710444-22290a962f6bf68bf60ec5b8cd09bb2429340d9a

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

Check Input Capture Line
    [Arguments]                     ${frequency}  ${duty}  ${IC2}

    ${line}=                        Wait For Line On Uart  f = (\\w+) Hz\\s+ duty = (\\w+) %\\s+ IC2 = (\\w+)  treatAsRegex=true
    ${actual_frequency}=            Set Variable           ${line.Groups[0]}
    ${actual_duty}=                 Set Variable           ${line.Groups[1]}
    ${actual_IC2}=                  Set Variable           ${line.Groups[2]}

    Should Be Equal As Integers     ${actual_frequency}    ${frequency}
    Should Be Equal As Integers     ${actual_duty}         ${duty}
    Should Be Equal As Integers     ${actual_IC2}          ${IC2}

*** Test Cases ***
Timer Should Support Input Capture
    Create Machine                  ${TIM_PWMInput}
    Create Terminal Tester          ${UART}
    Execute Command                 machine LoadPlatformDescriptionFromString "gpioPortB: { 6 -> gpioPortA@1 }"

    Start Emulation

    Check Input Capture Line        frequency=0     duty=0   IC2=0
    Execute Command                 sysbus.gpioPortC.UserButton1 PressAndRelease
    Check Input Capture Line        frequency=2000  duty=24  IC2=49999
    Execute Command                 sysbus.gpioPortC.UserButton1 PressAndRelease
    Check Input Capture Line        frequency=3000  duty=50  IC2=33332

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
