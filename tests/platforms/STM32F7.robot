*** Variables ***
${UART}                       sysbus.usart1
${URL}                        https://dl.antmicro.com/projects/renode

*** Keywords ***
UART Should Transmit And Receive With Interrupt
    [Arguments]               ${uart}  ${address}  ${pending_register}  ${interrupt_mask}
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/stm32f746.repl
    Execute Command           cpu IsHalted true
    Create Terminal Tester    sysbus.${uart}

    # Configure 1 Mbaud, then enable UE, RE, TE and RXNEIE.
    Execute Command           sysbus WriteDoubleWord ${{ ${address} + 0xC }} 200
    Execute Command           sysbus WriteDoubleWord ${address} 0x2D
    Execute Command           sysbus WriteDoubleWord ${{ ${address} + 0x28 }} 0x41
    Execute Command           sysbus WriteDoubleWord ${{ ${address} + 0x28 }} 0x0A
    Wait For Line On Uart     A

    ${pending}=               Execute Command  sysbus ReadDoubleWord ${pending_register}
    Should Be Equal As Numbers  ${pending}  0
    Execute Command           sysbus.${uart} WriteChar 0x5A
    Execute Command           emulation RunFor "0.000020"
    ${pending}=               Execute Command  sysbus ReadDoubleWord ${pending_register}
    Should Be Equal As Numbers  ${pending}  ${interrupt_mask}
    ${data}=                  Execute Command  sysbus ReadDoubleWord ${{ ${address} + 0x24 }}
    Should Be Equal As Numbers  ${data}  0x5A
    ${irq}=                   Execute Command  sysbus.${uart} IRQ IsSet
    Should Contain            ${irq}  False

*** Test Cases ***
UART4 Should Transmit And Receive With Interrupt
    UART Should Transmit And Receive With Interrupt  uart4  0x40004C00  0xE000E204  0x00100000

UART5 Should Transmit And Receive With Interrupt
    UART Should Transmit And Receive With Interrupt  uart5  0x40005000  0xE000E204  0x00200000

UART7 Should Transmit And Receive With Interrupt
    UART Should Transmit And Receive With Interrupt  uart7  0x40007800  0xE000E208  0x00040000

UART8 Should Transmit And Receive With Interrupt
    UART Should Transmit And Receive With Interrupt  uart8  0x40007C00  0xE000E208  0x00080000

Run Mbed-OS Hello World
    Execute Command           set bin @${URL}/renode-mbed-pipeline-helloworld.elf-ga2ede71-s_2466384-6e3635e4ed159bc847cf1deb3dc7f24b10d26b41
    Execute Command           include @scripts/single-node/stm32f746_mbed.resc

    Execute Command           showAnalyzer ${UART}
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     HELLO WORLD MBED+RENODE

    Provides                  hello-world

Wait For Message on LTDC
    [Tags]                    non_critical
    Requires                  hello-world

    Execute Command           emulation CreateFrameBufferTester "fb_tester" 10
    Execute Command           fb_tester AttachTo sysbus.ltdc
    Execute Command           fb_tester WaitForFrame @${URL}/mbed-stm32f7.png-s_4651-99842c172e660e408b2197e48c8e9dccd7948421

Run FreeRTOS CLI
    Execute Command           set bin @${URL}/stm32f746--cube_mx-freertos_cli.elf-s_1057672-cffcaec0bd9a5b282d701ad1fe8ded67e117a52b
    Execute Command           include @scripts/single-node/stm32f746.resc

    Execute Command           showAnalyzer ${UART}
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     FreeRTOS command server.
    Wait For Prompt On Uart   >
    Write Line To Uart        help
    Wait For Line On Uart     [Press ENTER to execute the previous command again]
    Wait For Prompt On Uart   >
    Write Line To Uart        echo-parameters a b
    Wait For Line On Uart     The parameters were:
    Wait For Line On Uart     1: a
    Wait For Line On Uart     2: b

Should Run Dartino
    Execute Command           set bin @${URL}/dartino-lines.elf-s_486816-cd8876ab9de60af779f4429dfe16c79bf831b84d
    Execute Command           include @scripts/single-node/stm32f746.resc
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Setup dartino
    Wait For Line On Uart     Reading dartino snapshot
    Wait For Line On Uart     Run dartino program

Should Run Zephyr Echo Client With Quectel BG96 Modem
    Execute Command           include @scripts/single-node/stm32f746_modem.resc
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Network is ready  timeout=15

    FOR  ${i}  IN RANGE  3
        Wait For Line On Uart     IPv4 TCP: Received and compared \\d+ bytes, all ok  treatAsRegex=true
    END

Should Fail To Run Zephyr Echo Client With Quectel BG96 Modem With Overridden Command
    Execute Command           include @scripts/single-node/stm32f746_modem.resc
    Create Terminal Tester    ${UART}

    Execute Command           usart2.bg96 OverrideResponseForCommand "AT+QIACT=1" "ERROR"

    Wait For Line On Uart     modem_quectel_bg9x: Error activating modem with pdp context
