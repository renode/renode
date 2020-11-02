*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.usart1

*** Test Cases ***
Run Mbed-OS Hello World
    Execute Command           set bin @https://dl.antmicro.com/projects/renode/renode-mbed-pipeline-helloworld.elf-ga2ede71-s_2466384-6e3635e4ed159bc847cf1deb3dc7f24b10d26b41
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
    Execute Command           fb_tester WaitForFrame @https://dl.antmicro.com/projects/renode/mbed-stm32f7.png-s_4651-99842c172e660e408b2197e48c8e9dccd7948421