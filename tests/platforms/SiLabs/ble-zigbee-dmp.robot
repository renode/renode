*** Variables ***
${ELF}                          @zigbee_ble_dmp_app.out
${BOARD}                        brd4186c
${QUANTUM_TIME}                 0.000020
${RNG_SEED}                     0
${UART}                         usart0
${DEFAULT_UART_TIMEOUT}         10
${EFR32_COMMON_SCRIPT}          tests/platforms/SiLabs/common/stub_util.resc
${PROMPT}                       DMPLight>
${PAN_ID}                       0xABCD
${POWER}                        0
${CHANNEL}                      15
${BLE_CHARACTERISTIC_ID}        31
${NUM_ZIGBEE_PACKETS}           10
${ENABLE_UI}                    False


*** Keywords ***
Initial Setup
    Execute Script              ${EFR32_COMMON_SCRIPT}
    Execute Command             emulation SetGlobalSerialExecution true
    Execute Command             emulation SetQuantum "${QUANTUM_TIME}"
    Execute Command             emulation SetAdvanceImmediately true
    IF  ${RNG_SEED} > 0
        Execute Command         emulation SetSeed ${RNG_SEED}
    END
    ${RNG_SEED}=                Execute Command  emulation GetSeed
    Log To Console              RNG SEED: ${RNG_SEED}
    Execute Command             emulation CreateBLEMedium "wireless"
    Execute Python              sl_add_stub("sl_zigbee_af_stack_status_cb")
    Execute Python              sl_add_stub("sl_zigbee_af_post_attribute_change_cb")
    Execute Python              sl_add_stub("enableBleAdvertisements")
    Set Default Uart Timeout    ${DEFAULT_UART_TIMEOUT}
    Execute Command             logLevel 3

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
    Execute Python              sl_add_hooks()
    ${tester_id}=               Create Terminal Tester  sysbus.${UART}  machine=${machine_name}  defaultPauseEmulation=true  defaultWaitForEcho=false
    # This command togehter with using the "--enable-xwt" option when launching renote-test 
    # pops up a UART shell for each node and allows to see the nodes CLI activity.
    IF  ${ENABLE_UI}
        Execute Command             showAnalyzer sysbus.${UART}
    END
    Execute Command             logLevel 3
    
Restart Ble Stack
    [Arguments]  ${tester}
    [Return]     ${ble_id}
    Write Line To Uart      plugin ble stop  testerId=${tester}
    Wait For Line On Uart   Stopping Bluetooth Stack: success  testerId=${tester}
    Write Line To Uart      plugin ble start  testerId=${tester}
    Wait For Line On Uart   BLE hello: success  testerId=${tester}

    ${s}=                       Wait For Line On Uart  BLE address: [  testerId=${tester}
    ${ble_id}=                  Get Substring  ${s.Line}  -18  -1
    Write Line To Uart          plugin ble gap set-conn-params 0x00C8 0x00C8 0x0000 0x0064  testerId=${tester}
    Wait For Line On Uart       success  testerId=${tester}

Start Ble Advertising 
    [Arguments]  ${tester}         
    Write Line To Uart          plugin ble gap set-mode 0 2 2  testerId=${tester}
    Wait For Line On Uart       success  testerId=${tester}

Create Ble Connection
    [Arguments]  ${tester}  ${peer_addr}
    Write Line To Uart          plugin ble gap conn-open {${peer_addr}} 0  testerId=${tester}
    Wait For Line On Uart       success  testerId=${tester}
    Wait For Line On Uart       BLE connection opened  testerId=${tester}

Check Ble Connection
    [Arguments]  ${tester}  ${peer_addr}
    Write Line To Uart          plugin ble gap print-connections  testerId=${tester}
    Wait For Line On Uart       Connection Info  testerId=${tester}
    Wait For Line On Uart       BLE address: [${peer_addr}]  testerId=${tester}

Get Ble Connection Handle
    [Arguments]  ${tester}  ${peer_addr}
    [Return]     ${connection_handle}
    Write Line To Uart          plugin ble gap print-connections  testerId=${tester}
    Wait For Line On Uart       Connection Info  testerId=${tester}
    ${s}=                       Wait For Line On Uart  connection handle  testerId=${tester}
    ${connection_handle}=       Get Substring  ${s.Line}  -4
    Wait For Line On Uart       BLE address: [${peer_addr}]  testerId=${tester}

Send Ble Test Message
    [Arguments]  ${tx_tester}  ${rx_tester}  ${connection_handle}  ${value}
    Write Line To Uart          plugin ble gatt write-characteristic ${connection_handle} ${BLE_CHARACTERISTIC_ID} {0${value}}  testerId=${tx_tester}
    Wait For Line On Uart       success  testerId=${tx_tester}
    Wait For Line On Uart       Light state write; ${value}  testerId=${rx_tester}

Form Zigbee Network
    [Arguments]  ${pan_id}  ${power}  ${channel}  ${tester}
    [Return]     ${short_id}
    Write Line To Uart          plugin network-creator form 0 ${pan_id} ${power} ${channel}  testerId=${tester}
    ${s}=                       Wait For Line On Uart  NETWORK_UP  testerId=${tester}
    ${short_id}=                Get Substring  ${s.Line}  -7

Join Zigbee Network
    [Arguments]  ${tester}
    [Return]     ${short_id}
    Write Line To Uart          plugin network-steering start 1  testerId=${tester}
    Wait For Line On Uart       NWK Steering: Start:  testerId=${tester}
    ${s}=                       Wait For Line On Uart  NETWORK_UP  testerId=${tester}
    ${short_id}=                Get Substring  ${s.Line}  -7
    Wait For Line On Uart       Join Success (0x00)  testerId=${tester}

Open Zigbee Network
    [Arguments]  ${tester}
    Write Line To Uart          plugin network-creator-security open-network  testerId=${tester}
    Wait For Line On Uart       Open network: 0x00  testerId=${tester}
    Wait For Line On Uart       NETWORK_OPENED  testerId=${tester}

Leave Zigbee Network
    [Arguments]  ${tester}
    Write Line To Uart          plugin network-steering stop  testerId=${tester}
    Wait For Line On Uart       NWK Steering: Stop  testerId=${tester}
    Write Line To Uart          plugin network-creator stop  testerId=${tester}
    Wait For Line On Uart       NWK Creator: Stop  testerId=${tester}
    Write Line To Uart          network leave  testerId=${tester}
    ${s}=                       Wait For Line On Uart  leave 0x  testerId=${tester}
    ${network_left}=            Run Keyword And Return Status  Should Contain  ${s.Line}  0x0
    IF  ${network_left} == True
        Wait For Line On Uart   NETWORK_DOWN  testerId=${tester}
    END

Send Zigbee Test Message
    [Arguments]  ${tx_tester}  ${rx_tester}  ${rx_tester_short_id}
    Write Line To Uart          zcl global read 0x0006 0x0  testerId=${tx_tester}
    Wait For Line On Uart       buffer  testerId=${tx_tester}
    Write Line To Uart          send ${rx_tester_short_id} 1 1  testerId=${tx_tester}
    Wait For Line On Uart       RX len 5, ep 01, clus 0x0006 (On/off)  testerId=${rx_tester}
    Wait For Line On Uart       READ_ATTR: clus 0006  testerId=${rx_tester}

Run Zigbee Throughput Test
    [Arguments]  ${tx_tester}  ${rx_tester_short_id}
    Write Line To Uart          network_test start_zigbee_test 70 ${NUM_ZIGBEE_PACKETS} 0 3 ${rx_tester_short_id} 0x00  testerId=${tx_tester}
    Wait For Line On Uart       ZigBee TX test started  testerId=${tx_tester}
    ${s}=                       Wait For Line On Uart  Success messages:  testerId=${tx_tester}
    ${packet_stats}=            Get Regexp Matches  ${s.Line}  \\d+
    ${passingStr}=              Get From List  ${packet_stats}  0
    ${passing}=                 Convert To Number  ${passing_str}
    ${totalStr}=                Get From List  ${packet_stats}  1
    ${total}=                   Convert To Number  ${total_str}
    ${passRate}=                Evaluate  ${passing} / ${total}
    Should Be True              ${passRate} >= 0.8


*** Test Cases ***
Zigbee BLE Dynamic Multiprotocol Test
    Initial Setup

    ${NODE1_TESTER_ID}=         Create Node  node1
    ${NODE2_TESTER_ID}=         Create Node  node2

    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE1_TESTER_ID}
    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE2_TESTER_ID}

    ${NODE1_SHORT_ID}=          Form Zigbee Network  ${PAN_ID}  ${POWER}  ${CHANNEL}  ${NODE1_TESTER_ID}
    Open Zigbee Network         ${NODE1_TESTER_ID}
    ${NODE2_SHORT_ID}=          Join Zigbee Network  ${NODE2_TESTER_ID}

    Run Zigbee Throughput Test  ${NODE1_TESTER_ID}  ${NODE2_SHORT_ID}
    Run Zigbee Throughput Test  ${NODE2_TESTER_ID}  ${NODE1_SHORT_ID}

    ${NODE1_BLE_ID}=            Restart Ble Stack  ${NODE1_TESTER_ID}
    ${NODE2_BLE_ID}=            Restart Ble Stack  ${NODE2_TESTER_ID}
    Start Ble Advertising       ${NODE2_TESTER_ID}
    Create Ble Connection       ${NODE1_TESTER_ID}  ${NODE2_BLE_ID}

    Check Ble Connection        ${NODE1_TESTER_ID}  ${NODE2_BLE_ID}
    Check Ble Connection        ${NODE2_TESTER_ID}  ${NODE1_BLE_ID}

    ${NODE1_CONN_HANDLE}=       Get Ble Connection Handle  ${NODE1_TESTER_ID}  ${NODE2_BLE_ID}
    ${NODE2_CONN_HANDLE}=       Get Ble Connection Handle  ${NODE2_TESTER_ID}  ${NODE1_BLE_ID}

    Send Ble Test Message       ${NODE1_TESTER_ID}  ${NODE2_TESTER_ID}  ${NODE1_CONN_HANDLE}  1
    Send Ble Test Message       ${NODE2_TESTER_ID}  ${NODE1_TESTER_ID}  ${NODE2_CONN_HANDLE}  0

    Run Zigbee Throughput Test  ${NODE1_TESTER_ID}  ${NODE2_SHORT_ID}
    Run Zigbee Throughput Test  ${NODE2_TESTER_ID}  ${NODE1_SHORT_ID}

    Leave Zigbee Network        ${NODE1_TESTER_ID}
    Leave Zigbee Network        ${NODE2_TESTER_ID}

    Check Ble Connection        ${NODE1_TESTER_ID}  ${NODE2_BLE_ID}
    Check Ble Connection        ${NODE2_TESTER_ID}  ${NODE1_BLE_ID}

    ${NODE2_SHORT_ID}=          Form Zigbee Network  ${PAN_ID}  ${POWER}  ${CHANNEL}  ${NODE2_TESTER_ID}
    Open Zigbee Network         ${NODE2_TESTER_ID}
    ${NODE1_SHORT_ID}=          Join Zigbee Network  ${NODE1_TESTER_ID}

    Check Ble Connection        ${NODE1_TESTER_ID}  ${NODE2_BLE_ID}
    Check Ble Connection        ${NODE2_TESTER_ID}  ${NODE1_BLE_ID}

    Run Zigbee Throughput Test  ${NODE1_TESTER_ID}  ${NODE2_SHORT_ID}
    Run Zigbee Throughput Test  ${NODE2_TESTER_ID}  ${NODE1_SHORT_ID}

    Send Ble Test Message       ${NODE1_TESTER_ID}  ${NODE2_TESTER_ID}  ${NODE1_CONN_HANDLE}  0
    Send Ble Test Message       ${NODE2_TESTER_ID}  ${NODE1_TESTER_ID}  ${NODE2_CONN_HANDLE}  1

    Check Ble Connection        ${NODE1_TESTER_ID}  ${NODE2_BLE_ID}
    Check Ble Connection        ${NODE2_TESTER_ID}  ${NODE1_BLE_ID}
