*** Variables ***
${URI}                          @https://dl.antmicro.com/projects/renode
${ELF}                          ${URI}/zigbee_z3_light.out
${BOARD}                        brd4186c
${QUANTUM_TIME}                 0.000050
${RNG_SEED}                     0
${UART}                         eusart0
${DEFAULT_UART_TIMEOUT}         10
${EFR32_COMMON_SCRIPT}          scripts/complex/SiLabs/efr32_common.resc
${PROMPT}                       z3_light>
${PAN_ID}                       0xABCD
${POWER}                        0
${CHANNEL}                      15
${NUM_TEST_PACKETS}             10
${NUM_JAM_PACKETS}              50
${MAX_JOIN_ATTEMPTS}            3
${INVALID_SHORT_ID}             0xFFFF
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
    Execute Command             emulation CreateIEEE802_15_4Medium "wireless"
    Execute Python              sl_add_stub("sl_zigbee_af_main_init_cb")
    Execute Python              sl_add_stub("sl_zigbee_af_stack_status_cb")
    Execute Python              sl_add_stub("sl_zigbee_af_network_steering_complete_cb")
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
    
Form Network
    [Arguments]  ${pan_id}  ${power}  ${channel}  ${tester}
    [Return]     ${short_id}
    Write Line To Uart          plugin network-creator form 0 ${pan_id} ${power} ${channel}  testerId=${tester}
    ${s}=                       Wait For Line On Uart  NETWORK_UP  testerId=${tester}
    ${short_id}=                Get Substring  ${s.line}  -7

Try Join Network
    [Arguments]  ${tester}
    [Return]     ${short_id}
    Write Line To Uart          plugin network-steering start 1  testerId=${tester}
    Wait For Line On Uart       NWK Steering: Start:  testerId=${tester}
    ${s}=                       Wait For Line On Uart  Beacons heard:  testerId=${tester}
    ${beacons_str}=             Get Substring  ${s.line}  -2
    ${beacons_count}=           Convert To Number  ${beacons_str}
    IF  ${beacons_count} == 0
        ${s}=                   Wait For Line On Uart  Beacons heard:  testerId=${tester}
        ${beacons_str}=         Get Substring  ${s.line}  -2
        ${beacons_count}=       Convert To Number  ${beacons_str}
        IF  ${beacons_count} == 0
            ${short_id}=        Set Variable  ${INVALID_SHORT_ID}
            Wait For Line On Uart   NWK Steering Stop  testerId=${tester}
        END
    END
    IF  ${beacons_count} > 0
        ${s}=                   Wait For Line On Uart  NETWORK_UP  testerId=${tester}
        ${short_id}=            Get Substring  ${s.line}  -7
        Wait For Line On Uart   NWK Steering network joined  testerId=${tester}
        Wait For Line On Uart   NWK Steering: Broadcasting permit join: 0x00  testerId=${tester}
        Wait For Line On Uart   NWK Steering Stop  testerId=${tester}
    END

Join Network
    [Arguments]  ${tester}
    [Return]     ${short_id}
    ${attempt_count}            Set Variable  ${MAX_JOIN_ATTEMPTS}
    WHILE  ${attempt_count} > 0
        ${attempt_count}=       Evaluate  ${attempt_count} - 1
        ${short_id}=            Try Join Network  ${tester}
        IF  ${short_id} != ${INVALID_SHORT_ID}
            ${attempt_count}    Set Variable  0
        END
    END
    Should Be True              ${short_id} != ${INVALID_SHORT_ID}

Open Network
    [Arguments]  ${tester}
    Write Line To Uart          plugin network-creator-security open-network  testerId=${tester}
    Wait For Line On Uart       Open network: 0x00  testerId=${tester}
    Wait For Line On Uart       NETWORK_OPENED  testerId=${tester}

Leave Network
    [Arguments]  ${tester}
    Write Line To Uart          plugin network-steering stop  testerId=${tester}
    Wait For Line On Uart       NWK Steering: Stop  testerId=${tester}
    Write Line To Uart          plugin network-creator stop  testerId=${tester}
    Wait For Line On Uart       NWK Creator: Stop  testerId=${tester}
    Write Line To Uart          network leave  testerId=${tester}
    ${s}=                       Wait For Line On Uart  leave 0x  testerId=${tester}
    ${network_left}=            Run Keyword And Return Status  Should Contain  ${s.line}  0x0
    IF  ${network_left} == True
        Wait For Line On Uart   NETWORK_DOWN  testerId=${tester}
    END

Send Test Message
    [Arguments]  ${tx_tester}  ${rx_tester}  ${rx_tester_short_id}
    Write Line To Uart          zcl global read 0 0  testerId=${tx_tester}
    Wait For Line On Uart       buffer  testerId=${tx_tester}
    Write Line To Uart          send ${rx_tester_short_id} 1 1  testerId=${tx_tester}
    Wait For Line On Uart       READ_ATTR: clus 0000  testerId=${rx_tester}

Start Zigbee Throughput Test
    [Arguments]  ${tx_tester}  ${rx_tester_short_id}  ${num_packets}
    Write Line To Uart          network_test start_zigbee_test 70 ${num_packets} 0 3 ${rx_tester_short_id} 0x00  testerId=${tx_tester}
    Wait For Line On Uart       ZigBee TX test started  testerId=${tx_tester}

Stop Zigbee Throughput Test
    [Arguments]  ${tx_tester}
    Write Line To Uart          network_test stop_zigbee_test  testerId=${tx_tester}
    Wait For Line On Uart       ZigBee TX test stopped  testerId=${tx_tester}

Run Zigbee Throughput Test
    [Arguments]  ${tx_tester}  ${rx_tester_short_id}
    Start Zigbee Throughput Test  ${tx_tester}  ${rx_tester_short_id}  ${NUM_TEST_PACKETS}
    ${s}=                       Wait For Line On Uart  Success messages:  testerId=${tx_tester}
    ${packet_stats}=            Get Regexp Matches  ${s.line}  \\d+
    ${passingStr}=              Get From List  ${packet_stats}  0
    ${passing}=                 Convert To Number  ${passing_str}
    ${totalStr}=                Get From List  ${packet_stats}  1
    ${total}=                   Convert To Number  ${total_str}
    ${passRate}=                Evaluate  ${passing} / ${total}
    Should Be True              ${passRate} >= 0.8


*** Test Cases ***
Zigbee Z3Light Basic Test
    Initial Setup

    ${NODE1_TESTER_ID}=         Create Node  node1
    ${NODE2_TESTER_ID}=         Create Node  node2
    ${NODE3_TESTER_ID}=         Create Node  node3

    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE1_TESTER_ID}
    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE2_TESTER_ID}
    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE3_TESTER_ID}

    ${NODE1_SHORT_ID}=          Form Network  ${PAN_ID}  ${POWER}  ${CHANNEL}  ${NODE1_TESTER_ID}
    Open Network                ${NODE1_TESTER_ID}
    ${NODE2_SHORT_ID}=          Join Network  ${NODE2_TESTER_ID}
    ${NODE3_SHORT_ID}=          Join Network  ${NODE3_TESTER_ID}

    # Send a message with default APS options from any node to any node to trigger a route discovery
    Send Test Message           ${NODE1_TESTER_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}
    Send Test Message           ${NODE1_TESTER_ID}  ${NODE3_TESTER_ID}  ${NODE3_SHORT_ID}
    Send Test Message           ${NODE2_TESTER_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}
    Send Test Message           ${NODE2_TESTER_ID}  ${NODE3_TESTER_ID}  ${NODE3_SHORT_ID}
    Send Test Message           ${NODE3_TESTER_ID}  ${NODE1_TESTER_ID}  ${NODE1_SHORT_ID}
    Send Test Message           ${NODE3_TESTER_ID}  ${NODE2_TESTER_ID}  ${NODE2_SHORT_ID}

    # Node2 and node3 send traffic simultanously to node1
    Start Zigbee Throughput Test  ${NODE2_TESTER_ID}  ${NODE1_SHORT_ID}  ${NUM_JAM_PACKETS}
    Run Zigbee Throughput Test    ${NODE3_TESTER_ID}  ${NODE1_SHORT_ID}
    Stop Zigbee Throughput Test   ${NODE2_TESTER_ID}
    
    Start Zigbee Throughput Test  ${NODE3_TESTER_ID}  ${NODE1_SHORT_ID}  ${NUM_JAM_PACKETS}
    Run Zigbee Throughput Test    ${NODE2_TESTER_ID}  ${NODE1_SHORT_ID}
    Stop Zigbee Throughput Test   ${NODE3_TESTER_ID}
    
    # Node1 and node3 send traffic simultanously to node2
    Start Zigbee Throughput Test  ${NODE1_TESTER_ID}  ${NODE2_SHORT_ID}  ${NUM_JAM_PACKETS}
    Run Zigbee Throughput Test    ${NODE3_TESTER_ID}  ${NODE2_SHORT_ID}
    Stop Zigbee Throughput Test   ${NODE1_TESTER_ID}
    
    Start Zigbee Throughput Test  ${NODE3_TESTER_ID}  ${NODE2_SHORT_ID}  ${NUM_JAM_PACKETS}
    Run Zigbee Throughput Test    ${NODE1_TESTER_ID}  ${NODE2_SHORT_ID}
    Stop Zigbee Throughput Test   ${NODE3_TESTER_ID}

    # Node1 and node2 send traffic simultanously to node3
    Start Zigbee Throughput Test  ${NODE1_TESTER_ID}  ${NODE3_SHORT_ID}  ${NUM_JAM_PACKETS}
    Run Zigbee Throughput Test    ${NODE2_TESTER_ID}  ${NODE3_SHORT_ID}
    Stop Zigbee Throughput Test   ${NODE1_TESTER_ID}
    
    Start Zigbee Throughput Test  ${NODE2_TESTER_ID}  ${NODE3_SHORT_ID}  ${NUM_JAM_PACKETS}
    Run Zigbee Throughput Test    ${NODE1_TESTER_ID}  ${NODE3_SHORT_ID}
    Stop Zigbee Throughput Test   ${NODE1_TESTER_ID}