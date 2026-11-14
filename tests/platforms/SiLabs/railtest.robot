*** Settings ***
Resource                      common/silabs.resource
Test Template                 Railtest Should Exchange Packets

*** Keywords ***
Send Packet
    [Arguments]               ${tx}  ${rx}  ${expect_rx}
    Send                      ${tx}  tx 1
    IF  ${expect_rx}
        Wait For              ${rx}  \\(rxPacket\\)  endline=${True}
    ELSE
        Should Not Receive    ${rx}  \\(rxPacket\\)
    END
    Wait For                  ${tx}  \\(txEnd\\)  endline=${True}

Enable Rx
    [Arguments]               ${node}  ${enable}
    IF  ${enable}
        Send                  ${node}  rx 1
        Wait For              ${node}  \\{Rx:Enabled\\}\\{Idle:Disabled\\}  endline=${True}
    ELSE
        Send                  ${node}  rx 0
        Wait For              ${node}  \\{Rx:Disabled\\}\\{Idle:Enabled\\}  endline=${True}
    END

Set Channel
    [Arguments]               ${node}  ${channel}
    Send                      ${node}  setChannel ${channel}
    Wait For                  ${node}  \\{channel:${channel}\\}  endline=${True}

Radio State Should Be
    [Arguments]               ${node}  ${state}
    Send                      ${node}  getRadioState
    Wait For                  ${node}  radioState:${state}  endline=${True}

Configure 802154 Mode
    [Arguments]               ${node}
    Send                      ${node}  enable802154 rx 100 192 864
    Wait For                  ${node}  \\{idleTiming:100\\}\\{turnaroundTime:192\\}\\{ackTimeout:864\\}
    Send                      ${node}  config2p4GHz802154
    Wait For                  ${node}  \\{802.15.4:Enabled\\}
    Send                      ${node}  acceptFrames 1 1 1 1
    Wait For                  ${node}  \\{CommandFrame:Enabled\\}\\{AckFrame:Enabled\\}\\{DataFrame:Enabled\\}\\{BeaconFrame:Enabled\\}
    Send                      ${node}  setPromiscuousMode 0
    Wait For                  ${node}  \\{PromiscuousMode:Disabled\\}

Railtest Should Exchange Packets
    [Arguments]               ${board}  ${uart}  ${elf}
    Create Emulation
    ${node1}=                 Create Node  node1  ${board}  ${elf}  ${uart}  timeout=1
    ${node2}=                 Create Node  node2  ${board}  ${elf}  ${uart}  timeout=1
    Wait For                  ${node1}  >
    Wait For                  ${node2}  >

    # Basic communication
    Radio State Should Be     ${node1}  Rx
    Radio State Should Be     ${node2}  Rx

    # Nodes on the same channel receive each other's packets
    Set Channel               ${node1}  5
    Set Channel               ${node2}  5
    Send Packet               ${node1}  ${node2}  ${True}
    Send Packet               ${node2}  ${node1}  ${True}

    # Nodes on different channels don't
    Set Channel               ${node2}  7
    Send Packet               ${node1}  ${node2}  ${False}
    Send Packet               ${node2}  ${node1}  ${False}

    Set Channel               ${node2}  5
    Send Packet               ${node1}  ${node2}  ${True}
    Send Packet               ${node2}  ${node1}  ${True}

    # A node with the receiver off doesn't receive
    Enable Rx                 ${node2}  ${False}
    Radio State Should Be     ${node2}  Idle
    Send Packet               ${node1}  ${node2}  ${False}

    # Auto ACK: node 1 receives, node 2 transmits and waits for the ACK
    Enable Rx                 ${node1}  ${False}
    Configure 802154 Mode     ${node1}
    Set Channel               ${node1}  24
    Send                      ${node1}  setpanid802154 0x5555 0
    Wait For                  ${node1}  \\{802.15.4PanId:Success\\}
    Send                      ${node1}  setshortaddr802154 0xAAAA 0
    Wait For                  ${node1}  \\{802.15.4ShortAddress:Success\\}
    Enable Rx                 ${node1}  ${True}

    Enable Rx                 ${node2}  ${False}
    Configure 802154 Mode     ${node2}
    Set Channel               ${node2}  24
    Send                      ${node2}  configTxOptions 1
    Wait For                  ${node2}  \\{waitForAck:True\\}

    Send                      ${node2}  settxpayload 0 14 0x23 0x88 0xbe 0x55 0x55 0xAA 0xAA 0x55 0x55 0xAA 0xAA 0x04
    Send                      ${node2}  tx 1
    Wait For                  ${node2}  \\(rxPacket\\).*\\{isAck:True\\}  endline=${True}

*** Test Cases ***            BOARD     UART     ELF
Should Exchange Packets On xG22
    brd4182a  eusart0  ${FIRMWARE_URL}/xg22_railtest_10_14_26.out-s_3939232-6ee8d67eb5d43a54117813abe412ff5344bea27a

Should Exchange Packets On xG24
    brd4186c  eusart0  ${FIRMWARE_URL}/xg24_railtest_10_14_26.out-s_4728736-6777770bb5e1cdc939b9dad14163d7a329234be3

Should Exchange Packets On xG26
    brd4116a  eusart0  ${FIRMWARE_URL}/xg26_railtest_10_14_26.out-s_4558656-939066bd0364a1c8cde7093d49f59b155333f3ca

Should Exchange Packets On SiXG301
    brd4407a  eusart0  ${FIRMWARE_URL}/sixg301_railtest_10_14_26.out-s_4524880-bf9e0ef605430c9446d98740dae7f4f7c248a6cb
