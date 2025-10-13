*** Keywords ***
Setup Terminal Tester
    [Arguments]                     ${machine}
    ${tester_id}=                   Create Terminal Tester  sysbus.segger  machine=${machine}  defaultPauseEmulation=true  timeout=4
    RETURN                          ${tester_id}

*** Test Cases ***
Should Run Demo
    Execute Command                 i @scripts/multi-node/da16200.resc
    ${sender_tester}=               Setup Terminal Tester  Sender
    ${receiver_tester}=             Setup Terminal Tester  Receiver

    # The first timeouts are longer as they include the overhead of the setup phase
    Wait For Line On Uart           UDP data received: from 192.0.2.2:80 -> Ping!  testerId=${receiver_tester}  timeout=100
    Wait For Line On Uart           UDP data received: from 192.0.2.1:80 -> Pong!  testerId=${sender_tester}  timeout=100

    Wait For Line On Uart           UDP data received: from 192.0.2.2:80 -> Ping!  testerId=${receiver_tester}
    Wait For Line On Uart           UDP data received: from 192.0.2.1:80 -> Pong!  testerId=${sender_tester}

    Wait For Line On Uart           UDP data received: from 192.0.2.2:80 -> Ping!  testerId=${receiver_tester}
    Wait For Line On Uart           UDP data received: from 192.0.2.1:80 -> Pong!  testerId=${sender_tester}
