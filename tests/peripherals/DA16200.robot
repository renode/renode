*** Keywords ***
Set Machine
    [Arguments]                     ${name}
    Execute Command                 mach set "${name}"

Setup Terminal Tester
    [Arguments]                     ${machine}
    ${tester_id}=                   Create Terminal Tester          sysbus.segger  machine=${machine}  defaultPauseEmulation=true
    RETURN                          ${tester_id}

*** Test Cases ***
Should Run Demo
    Execute Command                 i @scripts/multi-node/da16200.resc
    ${sender_tester}=               Setup Terminal Tester  Sender
    ${receiver_tester}=             Setup Terminal Tester  Receiver

    Wait For Line On Uart           mcu Initialize Success!  testerId=${receiver_tester}
    Wait For Line On Uart           mcu Initialize Success!  testerId=${sender_tester}

    Wait For Line On Uart           Wifi setting OK. Starting UDP communication  timeout=15  testerId=${receiver_tester}
    Wait For Line On Uart           Wifi setting OK. Starting UDP communication  timeout=15  testerId=${sender_tester}

    Wait For Line On Uart           UDP data received: from 192.0.2.2:80 -> Ping!  testerId=${receiver_tester}
    Wait For Line On Uart           UDP data received: from 192.0.2.1:80 -> Pong!  testerId=${sender_tester}

    Wait For Line On Uart           UDP data received: from 192.0.2.2:80 -> Ping!  testerId=${receiver_tester}
    Wait For Line On Uart           UDP data received: from 192.0.2.1:80 -> Pong!  testerId=${sender_tester}

    Wait For Line On Uart           UDP data received: from 192.0.2.2:80 -> Ping!  testerId=${receiver_tester}
    Wait For Line On Uart           UDP data received: from 192.0.2.1:80 -> Pong!  testerId=${sender_tester}
