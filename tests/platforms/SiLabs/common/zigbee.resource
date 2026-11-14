*** Settings ***
Resource                      silabs.resource

*** Variables ***
${PAN_ID}                     0xABCD
${POWER}                      0
${CHANNEL}                    15
${NUM_ZIGBEE_PACKETS}         10

*** Keywords ***
Form Network
    [Arguments]               ${node}
    Send                      ${node}  plugin network-creator form 0 ${PAN_ID} ${POWER} ${CHANNEL}
    ${line}=                  Wait For  ${node}  NETWORK_UP 0x....
    RETURN                    ${line}[-6:]

Join Network
    [Arguments]               ${node}  ${join_complete}
    Send                      ${node}  plugin network-steering start 1
    Wait For                  ${node}  NWK Steering: Start:
    ${line}=                  Wait For  ${node}  NETWORK_UP 0x....
    Wait For                  ${node}  ${join_complete}
    RETURN                    ${line}[-6:]

Open Network
    [Arguments]               ${node}
    Send                      ${node}  plugin network-creator-security open-network
    Wait For                  ${node}  Open network: 0x00
    Wait For                  ${node}  NETWORK_OPENED

Leave Network
    [Arguments]               ${node}
    Send                      ${node}  plugin network-steering stop
    Wait For                  ${node}  NWK Steering: Stop
    Send                      ${node}  plugin network-creator stop
    Wait For                  ${node}  NWK Creator: Stop
    Send                      ${node}  network leave
    ${line}=                  Wait For  ${node}  leave 0x.
    IF  '0x0' in $line
        Wait For              ${node}  NETWORK_DOWN
    END

Throughput Should Be At Least 80 Percent
    [Arguments]               ${node}  ${destination}
    Send                      ${node}  network_test start_zigbee_test 70 ${NUM_ZIGBEE_PACKETS} 0 3 ${destination} 0x00
    Wait For                  ${node}  ZigBee TX test started
    ${line}=                  Wait For  ${node}  Success messages:.*out of ${NUM_ZIGBEE_PACKETS}
    Should Be True            int($line.split(": ")[1].split(" ")[0]) / ${NUM_ZIGBEE_PACKETS} >= 0.8
