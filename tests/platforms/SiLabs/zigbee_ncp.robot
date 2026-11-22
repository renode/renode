*** Settings ***
Documentation                 The Zigbee host gateway is an x86-64 Linux binary talking to the NCP over a PTY.
Resource                      common/zigbee.resource
Library                       Process
Library                       common/host_process.py
Test Tags                     exclude_windows  exclude_osx  exclude_host_aarch64
Test Teardown                 Run Keywords  Terminate Host Processes  AND  Renode Test Teardown

*** Variables ***
${PROMPT}                     zigbee_z3_gateway>
${NCP_ELF}                    ${FIRMWARE_URL}/xg24_zigbee_ncp_uart_hw_v2025.6.1.out-s_5274788-d5111cb67c2fd30fbb5651ddfd5c8138bdca3044
${HOST_BINARY}                ${FIRMWARE_URL}/unix_zigbee_z3_gateway_v2025.6.1-s_866688-2bb69c08c2e7197b340096ab1eed67684cc4fe80
${EXTERNAL_CONTROL_LIB}       ${CURDIR}/../../../tools/external_control_client/lib
# The external control servers the gateways read their time from cannot be saved in a snapshot
${CREATE_SNAPSHOT_ON_FAIL}     False

*** Keywords ***
Download Host Binary
    [Documentation]           Downloads the gateway through the Renode file cache and makes an executable copy of it.
    ${cached}=                Download File  ${HOST_BINARY}
    ${dir}=                   Allocate Temporary Directory  zigbee_gateway
    ${r}=                     Run Process  install  -m  755  ${cached}  ${dir}/zigbee_z3_gateway
    Should Be Equal As Integers  ${r.rc}  0  msg=install failed: ${r.stderr}
    Set Test Variable         ${HOST_PATH}  ${dir}/zigbee_z3_gateway

Build Time Override Library
    [Documentation]           Builds librenode_api.so with the virtual time override. Preloaded into a gateway,
    ...                       it makes the gateway's clock follow the emulation's virtual time, so the gateway's
    ...                       timeouts match the NCP. Sanitizers would stop it from being preloaded.
    ${build}=                 Allocate Temporary Directory  time_override
    ${r}=                     Run Process  cmake  -DRENODE_API_TIME_OVERRIDE\=ON  -DRENODE_API_SANITIZERS\=OFF
    ...                       ${EXTERNAL_CONTROL_LIB}  cwd=${build}
    Should Be Equal As Integers  ${r.rc}  0  msg=cmake failed: ${r.stderr}
    ${r}=                     Run Process  cmake  --build  ${build}
    Should Be Equal As Integers  ${r.rc}  0  msg=cmake failed: ${r.stderr}
    Set Test Variable         ${TIME_OVERRIDE_LIB}  ${build}/librenode_api.so

Create NCP With Host
    [Documentation]           Creates an NCP board and starts a host gateway connected to its UART over a PTY.
    ...                       The gateway reads its clock from an external control server on ${control_port}.
    [Arguments]               ${name}  ${control_port}
    Create Node               ${name}  brd4186c  ${NCP_ELF}  usart0
    # The gateway rejects long serial port names
    ${pty}=                   Set Variable  /tmp/sim_${name}
    Execute Command           emulation CreateUartPtyTerminal "pty_${name}" "${pty}" true
    Execute Command           connector Connect sysbus.usart0 pty_${name}
    Execute Command           emulation CreateExternalControlServer "time_${name}" ${control_port}
    Launch Host Process       host_${name}  ${HOST_PATH}  -p  ${pty}
    ...                       renode_port=${control_port}  preload=${TIME_OVERRIDE_LIB}
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
    Download Host Binary
    Build Time Override Library
    Create Emulation
    Create NCP With Host      ncp1  3347
    Create NCP With Host      ncp2  3348

    ${host1_id}=              Host Should Form Network  host_ncp1
    Host Should Open Network  host_ncp1
    ${host2_id}=              Host Should Join Network  host_ncp2

    On Off Read Should Be Received  host_ncp1  host_ncp2  ${host2_id}
    On Off Read Should Be Received  host_ncp2  host_ncp1  ${host1_id}
