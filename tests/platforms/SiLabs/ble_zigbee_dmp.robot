*** Settings ***
Resource                      common/zigbee.resource
Test Template                 Zigbee And BLE Should Run Concurrently

*** Variables ***
${QUANTUM_TIME}               0.000010
${PROMPT}                     DMPLight>
${JOIN_COMPLETE}              Join Success \\(0x00\\)
${BLE_CHARACTERISTIC_ID}      31
@{STUBS}                      sl_zigbee_af_stack_status_cb  sl_zigbee_af_post_attribute_change_cb  enableBleAdvertisements

*** Keywords ***
Restart BLE Stack
    [Arguments]               ${node}
    Send                      ${node}  plugin ble stop
    Wait For                  ${node}  Stopping Bluetooth Stack: success
    Send                      ${node}  plugin ble start
    Wait For                  ${node}  BLE hello: success
    ${line}=                  Wait For  ${node}  BLE address: \\[.+\\]  endline=${True}
    Send                      ${node}  plugin ble gap set-conn-params 0x00C8 0x00C8 0x0000 0x0064
    Wait For                  ${node}  success
    RETURN                    ${{re.search(r"BLE address: \[(.+)\]", $line).group(1)}}

BLE Connection Should Be Open
    [Arguments]               ${node}  ${peer}
    Send                      ${node}  plugin ble gap print-connections
    Wait For                  ${node}  Connection Info
    Wait For                  ${node}  BLE address: \\[${peer}\\]  endline=${True}

Get BLE Connection Handle
    [Arguments]               ${node}  ${peer}
    Send                      ${node}  plugin ble gap print-connections
    Wait For                  ${node}  Connection Info
    ${line}=                  Wait For  ${node}  connection handle  endline=${True}
    Wait For                  ${node}  BLE address: \\[${peer}\\]  endline=${True}
    RETURN                    ${line}[-4:]

BLE Light Write Should Be Received
    [Arguments]               ${tx}  ${rx}  ${handle}  ${value}
    Send                      ${tx}  plugin ble gatt write-characteristic ${handle} ${BLE_CHARACTERISTIC_ID} {0${value}}
    Wait For                  ${tx}  success
    Wait For                  ${rx}  Light state write; ${value}

Zigbee And BLE Should Run Concurrently
    [Arguments]               ${board}  ${elf}
    Create Emulation
    # The CLI runs in its own OS task, so command echo can interleave with other output
    ${node1}=                 Create Node  node1  ${board}  ${elf}  eusart0  @{STUBS}  waitForEcho=false
    ${node2}=                 Create Node  node2  ${board}  ${elf}  eusart0  @{STUBS}  waitForEcho=false
    Wait For                  ${node1}  ${PROMPT}
    Wait For                  ${node2}  ${PROMPT}

    ${node1_id}=              Form Network  ${node1}
    Open Network              ${node1}
    ${node2_id}=              Join Network  ${node2}  ${JOIN_COMPLETE}
    Throughput Should Be At Least 80 Percent  ${node1}  ${node2_id}
    Throughput Should Be At Least 80 Percent  ${node2}  ${node1_id}

    ${node1_ble}=             Restart BLE Stack  ${node1}
    ${node2_ble}=             Restart BLE Stack  ${node2}
    Send                      ${node2}  plugin ble gap set-mode 0 2 2
    Wait For                  ${node2}  success
    Send                      ${node1}  plugin ble gap conn-open {${node2_ble}} 0
    Wait For                  ${node1}  success
    Wait For                  ${node1}  BLE connection opened
    BLE Connection Should Be Open  ${node1}  ${node2_ble}
    BLE Connection Should Be Open  ${node2}  ${node1_ble}
    ${node1_handle}=          Get BLE Connection Handle  ${node1}  ${node2_ble}
    ${node2_handle}=          Get BLE Connection Handle  ${node2}  ${node1_ble}
    BLE Light Write Should Be Received  ${node1}  ${node2}  ${node1_handle}  1
    BLE Light Write Should Be Received  ${node2}  ${node1}  ${node2_handle}  0

    # Zigbee keeps working with the BLE connection open
    Throughput Should Be At Least 80 Percent  ${node1}  ${node2_id}
    Throughput Should Be At Least 80 Percent  ${node2}  ${node1_id}

    # The BLE connection survives reforming the Zigbee network the other way round
    Leave Network             ${node1}
    Leave Network             ${node2}
    BLE Connection Should Be Open  ${node1}  ${node2_ble}
    BLE Connection Should Be Open  ${node2}  ${node1_ble}
    ${node2_id}=              Form Network  ${node2}
    Open Network              ${node2}
    ${node1_id}=              Join Network  ${node1}  ${JOIN_COMPLETE}
    BLE Connection Should Be Open  ${node1}  ${node2_ble}
    BLE Connection Should Be Open  ${node2}  ${node1_ble}
    Throughput Should Be At Least 80 Percent  ${node1}  ${node2_id}
    Throughput Should Be At Least 80 Percent  ${node2}  ${node1_id}
    BLE Light Write Should Be Received  ${node1}  ${node2}  ${node1_handle}  0
    BLE Light Write Should Be Received  ${node2}  ${node1}  ${node2_handle}  1
    BLE Connection Should Be Open  ${node1}  ${node2_ble}
    BLE Connection Should Be Open  ${node2}  ${node1_ble}

*** Test Cases ***            BOARD     ELF
Should Run Zigbee And BLE Concurrently On xG24
    brd4186c  ${FIRMWARE_URL}/xg24_zigbee_ble_dynamic_multiprotocol_light_3_4_25.out-s_11699564-18d8372e3b20eb250197cabb4515c5b750f34996

Should Run Zigbee And BLE Concurrently On xG26
    brd4121a  ${FIRMWARE_URL}/xg26_zigbee_ble_dynamic_multiprotocol_light_3_4_25.out-s_11646900-af51dd6ab7ef7aef28cf01176d0034b7b3e50707

Should Run Zigbee And BLE Concurrently On SiXG301
    brd4407a  ${FIRMWARE_URL}/sixg301_mp-zb-ble-soc-light_6_29_26.out-s_9847696-65fda5485f4c5674b28768be54f146f07014d0cb
