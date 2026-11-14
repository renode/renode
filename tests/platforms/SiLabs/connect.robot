*** Settings ***
Resource                        common/silabs.resource

*** Variables ***
# The defaults can be overridden, for example:
#   renode-test --variable ELF:path_or_url/connect_soc_mac_mode_device.out this_test.robot
${ELF}                          ${FIRMWARE_URL}/xg24_connect_soc_mac_mode_device_3_4_25.out-s_3599272-2686b4a0410b3d69c96716a3e1a6e9255e511554
${BOARD}                        brd4186c
${UART}                         eusart0
${RNG_SEED}                     0
${PROMPT}                       >
${PAN_ID}                       0xABCD
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
    Create Emulation
    IF  ${RNG_SEED} > 0
        Execute Command         emulation SetSeed ${RNG_SEED}
    END

Create Connect Node
    [Arguments]                 ${name}  ${short_id}
    ${tester}=                  Create Node  ${name}  ${BOARD}  ${ELF}  ${UART}
    &{node}=                    Create Dictionary  tester=${tester}  short_id=${short_id}
    RETURN                      ${node}

Read Node Long Id
    [Arguments]                 ${node}
    Send                        ${node.tester}  info
    ${line}=                    Wait For  ${node.tester}  Node Long id:  endline=${True}
    Set To Dictionary           ${node}  long_id=${line}[-16:]

Commission Network
    [Arguments]                 ${node}
    Send                        ${node.tester}  commission 6 ${node.short_id} ${PAN_ID} ${POWER} ${CHANNEL}
    Wait For                    ${node.tester}  Node parameters commissioned
    Send                        ${node.tester}  info
    FOR  ${line}  IN  Network state: 0x02  Node type: 0x06  Node id: ${node.short_id}  Pan id: ${PAN_ID}  Channel: ${CHANNEL}
        Wait For                ${node.tester}  ${line}
    END

Set Security
    [Arguments]                 ${node}  ${enable}
    Send                        ${node.tester}  set_options ${{ '0x03' if ${enable} else '0x02' }}
    Wait For                    ${node.tester}  Send options set:

Enable Security
    [Arguments]                 ${node}  ${remote}
    Send                        ${node.tester}  set_key {${KEY}}
    Wait For                    ${node.tester}  Security key set successful
    Set Security                ${node}  True
    Send                        ${node.tester}  set_security_mapping ${remote.short_id} {${remote.long_id}}
    Wait For                    ${node.tester}  Security mapping set

Send Test Message
    [Arguments]                 ${addr_mask}  ${tx}  ${rx}
    ${source}=                  Set Variable  ${tx.short_id} {${tx.long_id}}
    ${destination}=             Set Variable  ${rx.short_id} {${rx.long_id}}
    Send                        ${tx.tester}  send ${addr_mask} ${source} ${destination} ${PAN_ID} ${PAN_ID} {${TEST_PAYLOAD}}
    Wait For                    ${tx.tester}  MAC frame submitted
    Wait For                    ${rx.tester}  MAC RX: Data from.*:{ ${TEST_PAYLOAD}}
    Should Not Receive          ${tx.tester}  MAC TX:  timeout=0.25

Exchange Test Messages
    [Arguments]                 ${node1}  ${node2}
    FOR  ${mask}  IN  ${SHORT_SHORT_MASK}  ${LONG_SHORT_MASK}  ${SHORT_LONG_MASK}  ${LONG_LONG_MASK}
        Send Test Message       ${mask}  ${node1}  ${node2}
        Send Test Message       ${mask}  ${node2}  ${node1}
    END

*** Test Cases ***
Should Exchange MAC Mode Messages
    Initial Setup
    ${node1}=                   Create Connect Node  node1  0x1111
    ${node2}=                   Create Connect Node  node2  0x2222
    FOR  ${node}  IN  ${node1}  ${node2}
        Wait For                ${node.tester}  ${PROMPT}
    END
    Read Node Long Id           ${node1}
    Read Node Long Id           ${node2}
    Commission Network          ${node1}
    Commission Network          ${node2}

    Set Security                ${node1}  False
    Set Security                ${node2}  False
    Exchange Test Messages      ${node1}  ${node2}

    Enable Security             ${node1}  ${node2}
    Enable Security             ${node2}  ${node1}
    Exchange Test Messages      ${node1}  ${node2}
