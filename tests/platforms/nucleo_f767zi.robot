*** Variables ***
${UART}                             sysbus.usart3

${PROJECT_URL}                      https://dl.antmicro.com/projects/renode
# Networking server/client sample uses old Zephyr, due to limitations in our EthernetMAC model
${ECHO_SERVER}                      ${PROJECT_URL}/zephyr--nucleo_f767zi_echo_server.elf-s_3779788-3a2b4ad807c647f40f33a3b9b2d6a1492cdb4728
${ECHO_CLIENT}                      ${PROJECT_URL}/zephyr--nucleo_f767zi_echo_client.elf-s_3732872-2c680b71bd6ac70a11af54637402fac552cd5e52
${BLINKY}                           ${PROJECT_URL}/zephyr--nucleo_f767zi_blinky_sample.elf-s_521280-9cb6d6ed019906b8fd8da5c862f25bcd0014f558
${BUTTON}                           ${PROJECT_URL}/zephyr--nucleo_f767zi_button_sample.elf-s_528064-4966b57fd00cbae06d1cbd2a3dce1ae6c336554f

${PLATFORM}                         @platforms/boards/nucleo_f767zi.repl

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
