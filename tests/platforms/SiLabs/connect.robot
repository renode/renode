*** Variables ***
${ELF}                          @connect_soc_mac_mode_device.out
${BOARD}                        brd4186c
${QUANTUM_TIME}                 0.000050
${RNG_SEED}                     0
${UART}                         usart0
${DEFAULT_UART_TIMEOUT}         5
${PROMPT}                       >
${PAN_ID}                       0xABCD
${NODE1_SHORT_ID}               0x1111
${NODE2_SHORT_ID}               0x2222
${POWER}                        0
${CHANNEL}                      15
${KEY}                          AAAAAAAAAAAAAAAABBBBBBBBBBBBBBBB
${TEST_PAYLOAD}                 AA BB CC DD EE FF 11 22 33 44 55 66 77 88 99
${SHORT_SHORT_MASK}             0x0122
${SHORT_LONG_MASK}              0x0132
${LONG_SHORT_MASK}              0x0123
${LONG_LONG_MASK}               0x0133


*** Keywords ***
Initial Setup
    Execute Command             emulation SetGlobalSerialExecution true
    Execute Command             emulation SetQuantum "${QUANTUM_TIME}"
    Execute Command             emulation SetAdvanceImmediately true    
    IF  ${RNG_SEED} > 0
        Execute Command         emulation SetSeed ${RNG_SEED}
    END
    ${RNG_SEED}=                Execute Command  emulation GetSeed
    Log To Console              RNG SEED: ${RNG_SEED}
    Execute Command             emulation CreateIEEE802_15_4Medium "wireless"
    Set Default Uart Timeout    ${DEFAULT_UART_TIMEOUT}
    Execute Command             logLevel 3

Create Node
    [Arguments]  ${machine_name}
    [Return]     ${tester_id}
    Execute Command             mach clear
    Execute Command             mach create "${machine_name}"
    Execute Command             machine LoadPlatformDescription @platforms/boards/silabs/${BOARD}.repl
    Execute Command             sysbus LoadELF @${ELF}
    Execute Command             sysbus LogAllPeripheralsAccess false
    Execute Command             connector Connect sysbus.radio wireless
    ${tester_id}=               Create Terminal Tester  sysbus.${UART}  machine=${machine_name}  defaultPauseEmulation=true
    # This command togehter with using the "--enable-xwt" option when launching renote-test 
    # pops up a UART shell for each node and allows to see the nodes CLI activity.
    #Execute Command             showAnalyzer sysbus.${UART}

Commission Network
    [Arguments]  ${tester}  ${node_id}  ${pan_id}  ${power}  ${channel}
    Write Line To Uart          commission 6 ${node_id} ${pan_id} ${power} ${channel}  testerId=${tester}
    Wait For Line On Uart       Node parameters commissioned  testerId=${tester}
    Write Line To Uart          info  testerId=${tester}
    Wait For Line On Uart       Network state: 0x02  testerId=${tester}
    Wait For Line On Uart       Node type: 0x06  testerId=${tester}
    Wait For Line On Uart       Node id: ${node_id}  testerId=${tester}
    Wait For Line On Uart       Pan id: ${pan_id}  testerId=${tester}
    Wait For Line On Uart       Channel: ${channel}  testerId=${tester}

Get Node Long Id
    [Arguments]  ${tester}
    [Return]     ${long_id}
    Write Line To Uart          info  testerId=${tester}
    ${s}=                       Wait For Line On Uart  Node Long id:  testerId=${tester}
    ${long_id}=                 Get Substring  ${s.Line}  -16

Set Key
    [Arguments]  ${tester}  ${key}
    Write Line To Uart          set_key {${key}}  testerId=${tester}
    Wait For Line On Uart       Security key set successful  testerId=${tester}

Set Security
    [Arguments]  ${tester}  ${enable}
    IF  ${enable} == True
        Write Line To Uart      set_options 0x03  testerId=${tester}
    ELSE
        Write Line To Uart      set_options 0x02  testerId=${tester}
    END
    Wait For Line On Uart       Send options set:  testerId=${tester}

Set Security Mapping
    [Arguments]  ${tester}  ${remote_short_id}  ${remote_long_id}
    Write Line To Uart          set_security_mapping ${remote_short_id} {${remote_long_id}}  testerId=${tester}
    Wait For Line On Uart       Security mapping set  testerId=${tester}

Send Test Message
    [Arguments]  ${addr_mask}  ${tx_tester}  ${src_short}  ${src_long}  ${rx_tester}  ${dst_short}  ${dst_long}
    Write Line To Uart          send ${addr_mask} ${src_short} {${src_long}} ${dst_short} {${dst_long}} ${PAN_ID} ${PAN_ID} {${TEST_PAYLOAD}}  ${tx_tester}
    Wait For Line On Uart       MAC frame submitted  testerId=${tx_tester}
    Wait For Line On Uart       MAC RX: Data from.*:{ ${TEST_PAYLOAD}}  testerId=${rx_tester}  treatAsRegex=true
    Should Not Be On Uart       MAC TX:  testerId=${tx_tester}  timeout=0.25

*** Test Cases ***
Connect Mac Mode Basic Test
    Initial Setup

    ${NODE1_TESTER_ID}=         Create Node  node1
    ${NODE2_TESTER_ID}=         Create Node  node2

    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE1_TESTER_ID}
    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE2_TESTER_ID}

    ${NODE1_LONG_ID}=           Get Node Long Id  ${NODE1_TESTER_ID}
    ${NODE2_LONG_ID}=           Get Node Long Id  ${NODE2_TESTER_ID}

    Commission Network          ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${PAN_ID}  ${POWER}  ${CHANNEL}
    Commission Network          ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${PAN_ID}  ${POWER}  ${CHANNEL}

    Set Security                ${NODE1_TESTER_ID}  False
    Set Security                ${NODE2_TESTER_ID}  False

    Send Test Message           ${SHORT_SHORT_MASK}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Send Test Message           ${SHORT_SHORT_MASK}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}

    Send Test Message           ${LONG_SHORT_MASK}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Send Test Message           ${LONG_SHORT_MASK}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}

    Send Test Message           ${SHORT_LONG_MASK}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Send Test Message           ${SHORT_LONG_MASK}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}

    Send Test Message           ${LONG_LONG_MASK}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Send Test Message           ${LONG_LONG_MASK}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}

    Set Key                     ${NODE1_TESTER_ID}  ${KEY}
    Set Key                     ${NODE2_TESTER_ID}  ${KEY}

    Set Security                ${NODE1_TESTER_ID}  True
    Set Security                ${NODE2_TESTER_ID}  True

    Set Security Mapping        ${NODE1_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Set Security Mapping        ${NODE2_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}

    Send Test Message           ${SHORT_SHORT_MASK}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Send Test Message           ${SHORT_SHORT_MASK}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}

    Send Test Message           ${LONG_SHORT_MASK}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Send Test Message           ${LONG_SHORT_MASK}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}

    Send Test Message           ${SHORT_LONG_MASK}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Send Test Message           ${SHORT_LONG_MASK}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}

    Send Test Message           ${LONG_LONG_MASK}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}
    Send Test Message           ${LONG_LONG_MASK}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}  ${NODE2_LONG_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}  ${NODE1_LONG_ID}