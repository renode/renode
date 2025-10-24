*** Variables ***
${ELF}                          @railtest.out
${BOARD}                        brd1019a
${QUANTUM_TIME}                 0.000020
${RNG_SEED}                     0
${UART}                         eusart0
${DEFAULT_UART_TIMEOUT}         1
${PROMPT}                       >

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
    Execute Command             emulation CreateBLEMedium "wireless"
    Set Default Uart Timeout    ${DEFAULT_UART_TIMEOUT}
    Execute Command             logLevel 1

Create Node
    [Arguments]  ${machine_name}
    [Return]     ${tester_id}
    Execute Command             mach clear
    Execute Command             mach create "${machine_name}"
    Execute Command             machine LoadPlatformDescription @platforms/boards/silabs/${BOARD}.repl
    Execute Command             sysbus LoadELF @${ELF}
    Execute Command             sysbus.cpu VectorTableOffset `sysbus GetSymbolAddress "__Vectors"`
    Execute Command             sysbus LogAllPeripheralsAccess false
    Execute Command             connector Connect sysbus.radio wireless
    ${tester_id}=               Create Terminal Tester  sysbus.${UART}  machine=${machine_name}  defaultPauseEmulation=true
    Execute Command             logLevel 3
    # This command togehter with using the "--enable-xwt" option when launching renote-test 
    # pops up a UART shell for each node and allows to see the nodes CLI activity.
    #Execute Command             showAnalyzer sysbus.${UART}
    
Send Packet
    [Arguments]  ${tx_tester}  ${rx_tester}  ${expect_rx}
    Write Line To Uart          tx 1  testerId=${tx_tester}
    IF  ${expect_rx} == True
        Wait For Line On Uart   (rxPacket)  testerId=${rx_tester}
    ELSE
        Should Not Be On Uart   (rxPacket)  testerId=${rx_tester}  timeout=0.25
    END

Enable Rx
    [Arguments]  ${tester}  ${enable}
    IF  ${enable} == True
        Write Line To Uart      rx 1  testerId=${tester}
        Wait For Line On Uart   {Rx:Enabled}{Idle:Disabled}  testerId=${tester}
    ELSE
        Write Line To Uart      rx 0  testerId=${tester}
        Wait For Line On Uart   {Rx:Disabled}{Idle:Enabled}  testerId=${tester}
    END

Set Channel
    [Arguments]  ${tester}  ${channel}
    Write Line To Uart          setChannel ${channel}  testerId=${tester}
    Wait For Line On Uart       {channel:${channel}}  testerId=${tester}

Check Radio State
    [Arguments]  ${tester}  ${state}
    Write Line To Uart          getRadioState  testerId=${tester}
    Wait For Line On Uart       radioState:${state}  testerId=${tester}

Configure 802.15.4 Mode
    [Arguments]  ${tester}
    Write Line To Uart          enable802154 rx 100 192 864  testerId=${tester}
    Wait For Line On Uart       {idleTiming:100}{turnaroundTime:192}{ackTimeout:864}  testerId=${tester}
    Write Line To Uart          config2p4GHz802154  testerId=${tester}
    Wait For Line On Uart       {802.15.4:Enabled}  testerId=${tester}
    Write Line To Uart          acceptFrames 1 1 1 1  testerId=${tester}
    Wait For Line On Uart       {CommandFrame:Enabled}{AckFrame:Enabled}{DataFrame:Enabled}{BeaconFrame:Enabled}  testerId=${tester}
    Write Line To Uart          setPromiscuousMode 0  testerId=${tester}
    Wait For Line On Uart       {PromiscuousMode:Disabled}  testerId=${tester}

Set 802.14.4 Fields
    [Arguments]  ${tester}  ${pan_id}  ${short_id}
    Write Line To Uart          setpanid802154 ${pan_id} 0  testerId=${tester}
    Wait For Line On Uart       {802.15.4PanId:Success}  testerId=${tester}
    Write Line To Uart          setshortaddr802154 ${short_id} 0  testerId=${tester}
    Wait For Line On Uart       {802.15.4ShortAddress:Success}  testerId=${tester}

*** Test Cases ***
Basic Communication Test
    Initial Setup

    ${NODE1_TESTER_ID}=         Create Node  node1
    ${NODE2_TESTER_ID}=         Create Node  node2

    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE1_TESTER_ID}
    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE2_TESTER_ID}
    Check Radio State           ${NODE1_TESTER_ID}  Rx
    Check Radio State           ${NODE2_TESTER_ID}  Rx

    # Nodes on the same channel: send packets, expect reception
    Set Channel                 ${NODE1_TESTER_ID}  5
    Set Channel                 ${NODE2_TESTER_ID}  5
    Send Packet                 ${NODE1_TESTER_ID}  ${NODE2_TESTER_ID}  True
    Send Packet                 ${NODE2_TESTER_ID}  ${NODE1_TESTER_ID}  True

    # Nodes on different channels: send packets, expect NO reception
    Set Channel                 ${NODE2_TESTER_ID}  7
    Send Packet                 ${NODE1_TESTER_ID}  ${NODE2_TESTER_ID}  False
    Send Packet                 ${NODE2_TESTER_ID}  ${NODE1_TESTER_ID}  False

    # Nodes on the same channel: send packets, expect reception
    Set Channel                 ${NODE2_TESTER_ID}  5
    Send Packet                 ${NODE1_TESTER_ID}  ${NODE2_TESTER_ID}  True
    Send Packet                 ${NODE2_TESTER_ID}  ${NODE1_TESTER_ID}  True

    # Node 2 radio is off: send a packet, expect NO reception
    Enable Rx                   ${NODE2_TESTER_ID}  False
    Check Radio State           ${NODE2_TESTER_ID}  Idle
    Send Packet                 ${NODE1_TESTER_ID}  ${NODE2_TESTER_ID}  False

802.15.4 Auto-Acking Test
    Initial Setup

    ${NODE1_TESTER_ID}=         Create Node  node1
    ${NODE2_TESTER_ID}=         Create Node  node2

    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE1_TESTER_ID}
    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE2_TESTER_ID}

    # Node 1 (RX) config
    Enable Rx                   ${NODE1_TESTER_ID}  False
    Configure 802.15.4 Mode     ${NODE1_TESTER_ID}
    Set Channel                 ${NODE1_TESTER_ID}  24
    Set 802.14.4 Fields         ${NODE1_TESTER_ID}  0x5555  0xAAAA
    Enable Rx                   ${NODE1_TESTER_ID}  True

    # Node 2 (TX) config
    Enable Rx                   ${NODE2_TESTER_ID}  False
    Configure 802.15.4 Mode     ${NODE2_TESTER_ID}
    Set Channel                 ${NODE2_TESTER_ID}  24
    Write Line To Uart          configTxOptions 1  testerId=${NODE2_TESTER_ID}
    Wait For Line On Uart       {waitForAck:True}  testerId=${NODE2_TESTER_ID}

    # Node 2 TX a packet to Node 1, gets an ACK back
    Write Line To Uart          settxpayload 0 14 0x23 0x88 0xbe 0x55 0x55 0xAA 0xAA 0x55 0x55 0xAA 0xAA 0x04  testerId=${NODE2_TESTER_ID}
    Write Line To Uart          tx 1  testerId=${NODE2_TESTER_ID}
    Wait For Line On Uart       (rxPacket).*{isAck:True}  testerId=${NODE2_TESTER_ID}  treatAsRegex=true
