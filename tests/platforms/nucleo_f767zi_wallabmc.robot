*** Settings ***
Library                             http_helper.py
Library                             ../network-logging/telnet_library.py

*** Variables ***
${BOARD_IP}                         192.0.2.55
${REPL}                             @platforms/boards/nucleo_f767zi.repl
${ELF}                              @https://dl.antmicro.com/projects/renode/zephyr--nucleo_f767zi_wallabmc.elf-s_9924968-2a8abf47fcd5b028fa5dd14d6eb905316820f98c
${UART}                             sysbus.usart3

*** Keywords ***
Create Machine
    Execute Command                 include @${REPL}
    # Zephyr derives MAC addresses from the unique device ID. Make it consistent across tests
    Execute Command                 rom WriteDoubleWord 0xF420 7
    Execute Command                 rom WriteDoubleWord 0xF424 6
    Execute Command                 rom WriteDoubleWord 0xF428 7
    Execute Command                 showAnalyzer ${UART}
    Execute Command                 sysbus LoadELF ${ELF}

Setup TAP
    Execute Command                 emulation CreateTap "tap0" "tap"
    Execute Command                 emulation CreateSwitch "switch"
    Execute Command                 connector Connect host.tap switch
    Execute Command                 connector Connect sysbus.ethernet switch
    Network Interface Should Have Address  tap0  192.0.2.1

*** Test Cases ***
Should Talk To Host Over TAP Using Telnet
    [Tags]                          tap  exclude_osx
    Create Machine
    Setup TAP
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           wallabmc: BMC boot complete
    Telnet Connect                  host=${BOARD_IP}  port=23
    Telnet Write Line               config show
    ${response}=                    Telnet Read Until  ---------------------
    Should Contain                  ${response}  BMC hostname: wallabmc

Should Talk To Host Over TAP Using HTTP
    [Tags]                          tap  exclude_osx
    Create Machine
    Setup TAP
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           wallabmc: BMC boot complete
    ${auth_header}=                 Http Basic Auth Header  admin  demo
    ${response}=                    Http Get URL  host=${BOARD_IP}  path=/redfish/v1/Managers/bmc  parse_json=True  headers=${auth_header}
    Should Be Equal                 ${response["FirmwareVersion"]}  7773531
