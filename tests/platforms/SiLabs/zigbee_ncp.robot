*** Settings ***
Documentation                 The Zigbee host gateway is an x86-64 Linux binary talking to the NCP over a PTY.
Resource                      common/zigbee.resource
Library                       common/host_process.py
Test Tags                     exclude_windows  exclude_osx  exclude_host_aarch64
Test Teardown                 Run Keywords  Terminate Host Processes  AND  Renode Test Teardown

*** Variables ***
${PROMPT}                     zigbee_z3_gateway>
${NCP_ELF}                    ${FIRMWARE_URL}/xg24_zigbee_ncp_uart_hw_v2025.6.1.out-s_5274788-d5111cb67c2fd30fbb5651ddfd5c8138bdca3044
${HOST_BINARY}                ${FIRMWARE_URL}/unix_zigbee_z3_gateway_v2025.6.1-s_866688-2bb69c08c2e7197b340096ab1eed67684cc4fe80

*** Keywords ***
Create NCP With Host
    [Documentation]           Creates an NCP board and starts a host gateway connected to its UART over a PTY.
    [Arguments]               ${name}
    Create Node               ${name}  brd4186c  ${NCP_ELF}  usart0
    # The gateway rejects long serial port names
    ${pty}=                   Set Variable  /tmp/sim_${name}
    Execute Command           emulation CreateUartPtyTerminal "pty_${name}" "${pty}" true
    Execute Command           connector Connect sysbus.usart0 pty_${name}
    Launch Host Process       host_${name}  ${HOST_BINARY}  -p  ${pty}
    Wait For Host Line        host_${name}  ${PROMPT}

Host Should Form Network
    [Arguments]               ${host}
    Write Line To Host        ${host}  plugin network-creator form 0 ${PAN_ID} ${POWER} ${CHANNEL}
    Wait For Host Line        ${host}  Form: 0x00
    ${line}=                  Wait For Host Line  ${host}  NETWORK_UP 0x....
    RETURN                    ${line}[-6:]

Host Should Open Network
    [Arguments]               ${host}
    Write Line To Host        ${host}  plugin network-creator-security open-network
    Wait For Host Line        ${host}  Open network: 0x00
    Wait For Host Line        ${host}  NETWORK_OPENED

Host Should Join Network
    [Arguments]               ${host}
    Write Line To Host        ${host}  plugin network-steering start 1
    Wait For Host Line        ${host}  NWK Steering: Start:
    ${line}=                  Wait For Host Line  ${host}  NETWORK_UP 0x....
    Wait For Host Line        ${host}  Join Success
    RETURN                    ${line}[-6:]

On Off Read Should Be Received
    [Arguments]               ${sender}  ${receiver}  ${receiver_id}
    Write Line To Host        ${sender}  zcl global read 0x0006 0x0
    Wait For Host Line        ${sender}  buffer
    Write Line To Host        ${sender}  send ${receiver_id} 1 1
    Wait For Host Line        ${receiver}  RX len 5, ep 01, clus 0x0006 \\(On/off\\)
    Wait For Host Line        ${receiver}  READ_ATTR: clus 0006

*** Test Cases ***
Should Form Network And Exchange Messages Through NCPs On xG24
    Create Emulation
    Create NCP With Host      ncp1
    Create NCP With Host      ncp2

    ${host1_id}=              Host Should Form Network  host_ncp1
    Host Should Open Network  host_ncp1
    ${host2_id}=              Host Should Join Network  host_ncp2

    On Off Read Should Be Received  host_ncp1  host_ncp2  ${host2_id}
    On Off Read Should Be Received  host_ncp2  host_ncp1  ${host1_id}
