*** Variables ***
${UART}                       sysbus.usart1
${URL}                        https://dl.antmicro.com/projects/renode

*** Test Cases ***
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
