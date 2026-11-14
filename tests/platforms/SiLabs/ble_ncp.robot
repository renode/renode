*** Settings ***
Documentation                 Requires the pybgapi package (pip install "pybgapi==1.3.*").
Resource                      common/silabs.resource
Library                       common/bgapi_lib.py
Test Template                 BLE NCP Nodes Should Connect
Test Teardown                 Run Keywords  Close All Host Connections  AND  Renode Test Teardown

*** Variables ***
${QUANTUM_TIME}               0.000010

*** Keywords ***
Create NCP Node
    [Documentation]           Creates an NCP board with its UART served on a socket and returns the
    ...                       BGAPI host connection to it.
    [Arguments]               ${name}  ${board}  ${elf}  ${port}
    Create Node               ${name}  ${board}  ${elf}  eusart0
    Execute Command           emulation CreateServerSocketTerminal ${port} "cli_${name}" false
    Execute Command           connector Connect sysbus.eusart0 cli_${name}
    ${host}=                  Open Host Connection  ${port}
    RETURN                    ${host}

Connection Should Stay Open
    [Arguments]               ${host1}  ${host2}
    Assert No Connection Closed Event  ${host1}
    Assert No Connection Closed Event  ${host2}

BLE NCP Nodes Should Connect
    [Arguments]               ${board}  ${elf}  ${increase_security}=${True}
    Create Emulation
    ${host1}=                 Create NCP Node  ncp1  ${board}  ${elf}  3451
    ${host2}=                 Create NCP Node  ncp2  ${board}  ${elf}  3452
    Wait For Boot Event       ${host1}
    Wait For Boot Event       ${host2}
    Cmd Hello                 ${host1}
    Cmd Hello                 ${host2}
    ${node1_address}=         Cmd Get Identity Address  ${host1}

    # Node 1 advertises, node 2 connects to it
    ${adv_handle}=            Cmd Legacy Advertiser Create Set  ${host1}
    Cmd Legacy Advertiser Generate Data  ${host1}  ${adv_handle}  ${2}
    Cmd Legacy Advertiser Start  ${host1}  ${adv_handle}  ${2}
    Cmd Connection Open       ${host2}  ${node1_address}  ${0}
    Wait For Connection Opened Event  ${host1}
    ${node2_connection}=      Wait For Connection Opened Event  ${host2}
    Connection Should Stay Open  ${host1}  ${host2}
    Execute Command           emulation RunFor "1"
    Connection Should Stay Open  ${host1}  ${host2}

    IF  ${increase_security}
        Cmd Increase Security  ${host2}  ${node2_connection}
        Wait For Security Increased Events  ${host1}
        Wait For Security Increased Events  ${host2}
    END
    Execute Command           emulation RunFor "3"
    Connection Should Stay Open  ${host1}  ${host2}

*** Test Cases ***            BOARD     ELF      INCREASE_SECURITY
Should Connect On xG22
    # Increasing security needs the CRYPTOACC PKCTRL block, which is not modelled for xG22
    brd4182a  ${FIRMWARE_URL}/xg22_bt_ncp_10_15_26.out-s_8142184-4ce15990b63ad8a3311744bb0d54c426212c0ce6  ${False}

Should Connect On xG24
    brd4186c  ${FIRMWARE_URL}/xg24_bt_ncp_freertos_10_15_26.out-s_8528044-dfb99b5be20da5d34157568b9ebef7a12bb01791

Should Connect On xG26
    brd4116a  ${FIRMWARE_URL}/xg26_bt_ncp_freertos_10_15_26.out-s_8567860-fcb37adb86b289f0545c40256d02b25782ef41ca

Should Connect On SiXG301
    brd4407a  ${FIRMWARE_URL}/sixg301_bt_ncp_freertos_10_15_26.out-s_8735196-df54367bdfd4b917acdbcdd7d89c451c88869891
