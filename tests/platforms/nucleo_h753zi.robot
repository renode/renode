*** Variables ***
${UART}                             sysbus.usart3

${PROJECT_URL}                      https://dl.antmicro.com/projects/renode
${ECHO_SERVER}                      ${PROJECT_URL}/zephyr-nucleo_h753zi_echo_server.elf-s_3820436-2a55e73d28b438666b588d87cc9822365ee46cf6
${ECHO_CLIENT}                      ${PROJECT_URL}/zephyr-nucleo_h753zi_echo_client.elf-s_3773508-692f892b406f5a4a0aedb4afe120acd26f420d21
${BLINKY}                           ${PROJECT_URL}/zephyr--nucleo-h753zi-blinky.elf-s_586204-d9aa33947652eb18930088c06704ad6a8cdc7fa4
${BUTTON}                           ${PROJECT_URL}/zephyr--nucleo_h753zi_button_sample.elf-s_582696-3d5e6775a24c75e8fff6b812d5bc850b361e3d93

${PLATFORM}                         @platforms/boards/nucleo_h753zi.repl

*** Keywords ***
Create Setup
    Execute Command                 emulation CreateSwitch "switch"

    Create Machine                  ${ECHO_SERVER}  server
    Execute Command                 connector Connect sysbus.ethernet switch
    Create Machine                  ${ECHO_CLIENT}  client
    Execute Command                 connector Connect sysbus.ethernet switch

Create Machine
    [Arguments]                     ${elf}  ${name}

    Execute Command                 mach add "${name}"
    Execute Command                 mach set "${name}"
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}

    Execute Command                 sysbus LoadELF @${elf}

*** Test Cases ***
Should Talk Over Ethernet
    Create Setup
    ${server}=  Create Terminal Tester          ${UART}  machine=server  defaultPauseEmulation=True
    ${client}=  Create Terminal Tester          ${UART}  machine=client  defaultPauseEmulation=True

    Wait For Line On Uart           Initializing network                                                 testerId=${server}
    Wait For Line On Uart           Run echo server                                                      testerId=${server}
    Wait For Line On Uart           Network connected                                                    testerId=${server}
    Wait For Line On Uart           Waiting for TCP connection                                           testerId=${server}

    Wait For Line On Uart           Initializing network                                                 testerId=${client}
    Wait For Line On Uart           Run echo client                                                      testerId=${client}
    Wait For Line On Uart           Network connected                                                    testerId=${client}

    Wait For Line On Uart           Accepted connection                                                  testerId=${server}

    Wait For Line On Uart           Sent                                                                 testerId=${client}
    Wait For Line On Uart           Received and replied                                                 testerId=${server}
    Wait For Line On Uart           Received and compared \\d+ bytes, all ok                             testerId=${client}   treatAsRegex=true

    Wait For Line On Uart           Sent                                                                 testerId=${client}
    Wait For Line On Uart           Received and replied                                                 testerId=${server}
    Wait For Line On Uart           Received and compared \\d+ bytes, all ok                             testerId=${client}   treatAsRegex=true

    Wait For Line On Uart           Sent                                                                 testerId=${client}
    Wait For Line On Uart           Received and replied                                                 testerId=${server}
    Wait For Line On Uart           Received and compared \\d+ bytes, all ok                             testerId=${client}   treatAsRegex=true

    Wait For Line On Uart           Sent                                                                 testerId=${client}
    Wait For Line On Uart           Received and replied                                                 testerId=${server}
    Wait For Line On Uart           Received and compared \\d+ bytes, all ok                             testerId=${client}   treatAsRegex=true

Should Blink Led
    Create Machine                  ${BLINKY}  blinky

    Create Terminal Tester          ${UART}                                       defaultPauseEmulation=True
    Create LED Tester               sysbus.gpioPortB.GreenLED                     defaultTimeout=1

    Wait For Line On Uart           *** Booting Zephyr OS                         includeUnfinishedLine=true
    Wait For Line On Uart           LED state: (ON|OFF)                           treatAsRegex=true

    Assert LED Is Blinking          testDuration=8  onDuration=1  offDuration=1  pauseEmulation=true

Should See Button Press
    Create Machine                  ${BUTTON}  button

    Create Terminal Tester          ${UART}                                       defaultPauseEmulation=True
    Create LED Tester               sysbus.gpioPortB.GreenLED                     defaultTimeout=1

    Wait For Line On Uart           *** Booting Zephyr OS                         includeUnfinishedLine=true
    Wait For Line On Uart           Press the button
    Assert LED State                false

    Execute Command                 sysbus.gpioPortC.UserButton1 Press
    Wait For Line On Uart           Button pressed at                             includeUnfinishedLine=true
    Assert LED State                true
    Execute Command                 sysbus.gpioPortC.UserButton1 Release
    Assert LED State                false
