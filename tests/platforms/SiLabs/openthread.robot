*** Settings ***
Resource                      common/silabs.resource
Test Template                 OpenThread Nodes Should Ping And Connect Over CoAPS

*** Variables ***
${PROMPT}                     >${SPACE}
${CSL_PERIOD}                 500000
${CSL_TIMEOUT}                30
${IPV6_ADDRESS}               ([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}
${XG24_ELF}                   ${FIRMWARE_URL}/xg24_ot-cli-ftd_5_18_26.out-s_48131528-93c9791ff91102c0c8aa9a0ffccee1573083b122
${SIXG301_ELF}                ${FIRMWARE_URL}/sixg301_ot-cli-ftd_5_18_26.out-s_48714832-a24304a33ca0f85022f49fe224b960f0f0f64416

*** Keywords ***
Wait For Boot
    [Arguments]               ${node}
    Wait For                  ${node}  Reset info:
    Wait For                  ${node}  Extended Reset info:
    Send                      ${node}  ${EMPTY}
    Wait For                  ${node}  ${PROMPT}

Run Command
    [Arguments]               ${node}  ${command}
    Send                      ${node}  ${command}
    Wait For                  ${node}  Done

Query Dataset
    [Arguments]               ${node}  ${field}  ${pattern}
    Send                      ${node}  dataset ${field}
    ${value}=                 Wait For  ${node}  ${pattern}  endline=${True}
    Wait For                  ${node}  Done
    RETURN                    ${value}

Start Leader
    [Arguments]               ${node}
    Run Command               ${node}  dataset init new
    Run Command               ${node}  dataset commit active
    Run Command               ${node}  ifconfig up
    Send                      ${node}  thread start
    Wait For                  ${node}  Role detached -> leader
    Send                      ${node}  state
    Wait For                  ${node}  leader
    Wait For                  ${node}  Done
    ${key}=                   Query Dataset  ${node}  networkkey  ^[0-9a-fA-F]{32}$
    ${channel}=               Query Dataset  ${node}  channel  ^\\d{1,2}$
    ${panid}=                 Query Dataset  ${node}  panid  ^0x[0-9a-fA-F]{4}$
    RETURN                    ${key}  ${channel}  ${panid}

Start Child
    [Documentation]           Joins as a sleepy end device with CSL enabled and waits until it becomes a child.
    [Arguments]               ${node}  ${key}  ${channel}  ${panid}
    Run Command               ${node}  csl period ${CSL_PERIOD}
    Run Command               ${node}  csl timeout ${CSL_TIMEOUT}
    Run Command               ${node}  mode -
    Run Command               ${node}  dataset channel ${channel}
    Run Command               ${node}  dataset panid ${panid}
    Run Command               ${node}  dataset networkkey ${key}
    Run Command               ${node}  dataset commit active
    Run Command               ${node}  ifconfig up
    Send                      ${node}  thread start
    Wait For                  ${node}  Role detached -> child  timeout=30

Get IPv6 Address
    [Documentation]           The ot-cli "> " prompt has no trailing newline and can glue onto the next
    ...                       line, so the address is matched anywhere on the line.
    [Arguments]               ${node}
    Send                      ${node}  ipaddr linklocal
    ${line}=                  Wait For  ${node}  .*${IPV6_ADDRESS}  endline=${True}
    Wait For                  ${node}  Done
    RETURN                    ${{re.search($IPV6_ADDRESS, $line).group(0)}}

Ping Should Succeed
    [Arguments]               ${pinger}  ${pinged}
    ${address}=               Get IPv6 Address  ${pinged}
    Send                      ${pinger}  ping ${address}
    Wait For                  ${pinger}  1 packets transmitted, 1 packets received
    Wait For                  ${pinger}  Done

CoAPS Should Connect
    [Arguments]               ${server}  ${client}
    Run Command               ${server}  coaps x509
    Run Command               ${server}  coaps start
    Run Command               ${server}  coaps resource testsecure42
    ${address}=               Get IPv6 Address  ${server}
    Run Command               ${client}  coaps x509
    Run Command               ${client}  coaps start
    Send                      ${client}  coaps connect ${address}
    Wait For                  ${server}  coaps connected
    Wait For                  ${client}  coaps connected

OpenThread Nodes Should Ping And Connect Over CoAPS
    [Arguments]               ${board1}  ${uart1}  ${elf1}  ${board2}=${board1}  ${uart2}=${uart1}  ${elf2}=${elf1}
    Create Emulation
    ${node1}=                 Create Node  node1  ${board1}  ${elf1}  ${uart1}
    ${node2}=                 Create Node  node2  ${board2}  ${elf2}  ${uart2}
    Wait For Boot             ${node1}
    Wait For Boot             ${node2}

    ${key}  ${channel}  ${panid}=  Start Leader  ${node1}
    Start Child               ${node2}  ${key}  ${channel}  ${panid}

    Ping Should Succeed       ${node1}  ${node2}
    Ping Should Succeed       ${node2}  ${node1}
    CoAPS Should Connect      ${node1}  ${node2}

*** Test Cases ***            BOARD1    UART1    ELF1     BOARD2    UART2    ELF2
Should Ping And Connect Over CoAPS On xG24
    brd4186c  usart0  ${XG24_ELF}

Should Ping And Connect Over CoAPS On SiXG301
    brd4407a  eusart0  ${SIXG301_ELF}

Should Ping And Connect Over CoAPS Between xG24 And SiXG301
    brd4186c  usart0  ${XG24_ELF}  brd4407a  eusart0  ${SIXG301_ELF}
