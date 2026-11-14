*** Settings ***
Resource                      common/zigbee.resource
Test Template                 Zigbee Nodes Should Form Network And Exchange Messages

*** Variables ***
${PROMPT}                     z3_light
${JOIN_COMPLETE}              Join network complete: 0x00
@{STUBS}                      sl_zigbee_af_main_init_cb  sl_zigbee_af_stack_status_cb
${XG22_ELF}                   ${FIRMWARE_URL}/xg22_zigbee_z3_light_7_17_25.out-s_5996716-654947f88efddd078a267507d9b4258494e31b7d
${XG24_ELF}                   ${FIRMWARE_URL}/xg24_zigbee_z3_light_v2025.6.2.out-s_6376000-824a413a8f1c1e805426cb9e3b698f90bbe6c96d
${SIXG301_ELF}                ${FIRMWARE_URL}/sixg301_zigbee_z3_light_8_11_26.out-s_8758500-561b447944812dbc54afeaa3732a2b3417a8cb91

*** Keywords ***
Zigbee Nodes Should Form Network And Exchange Messages
    [Arguments]               ${board1}  ${elf1}  ${board2}=${board1}  ${elf2}=${elf1}
    Create Emulation
    # The CLI runs in its own OS task, so command echo can interleave with other output
    ${node1}=                 Create Node  node1  ${board1}  ${elf1}  eusart0  @{STUBS}  waitForEcho=false
    ${node2}=                 Create Node  node2  ${board2}  ${elf2}  eusart0  @{STUBS}  waitForEcho=false
    Wait For                  ${node1}  ${PROMPT}
    Wait For                  ${node2}  ${PROMPT}

    ${node1_id}=              Form Network  ${node1}
    Open Network              ${node1}
    ${node2_id}=              Join Network  ${node2}  ${JOIN_COMPLETE}

    # Nodes are expected to stay joined across a reset
    Send                      ${node1}  reset
    Send                      ${node2}  reset
    Wait For                  ${node1}  ${PROMPT}
    Wait For                  ${node2}  ${PROMPT}
    # Let the network stabilize
    Execute Command           emulation RunFor "10"

    Throughput Should Be At Least 80 Percent  ${node1}  ${node2_id}
    Throughput Should Be At Least 80 Percent  ${node2}  ${node1_id}

    Leave Network             ${node1}
    Leave Network             ${node2}

    ${node2_id}=              Form Network  ${node2}
    Open Network              ${node2}
    ${node1_id}=              Join Network  ${node1}  ${JOIN_COMPLETE}

    Throughput Should Be At Least 80 Percent  ${node1}  ${node2_id}
    Throughput Should Be At Least 80 Percent  ${node2}  ${node1_id}

*** Test Cases ***            BOARD1    ELF1     BOARD2    ELF2
Should Form Network And Exchange Messages On xG22
    brd4182a  ${XG22_ELF}

Should Form Network And Exchange Messages On xG24
    brd4186c  ${XG24_ELF}

Should Form Network And Exchange Messages On SiXG301
    brd4407a  ${SIXG301_ELF}

Should Form Network And Exchange Messages Between xG24 And SiXG301
    brd4186c  ${XG24_ELF}  brd4407a  ${SIXG301_ELF}
