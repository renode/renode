*** Variables ***
# The ELF variable must be set from command line to the OpenThread FTD CLI ELF file to be used. 
${URI}                          @https://artifactory.silabs.net/artifactory/renode-production/prebuilt/xg24
${ELF}                          ${URI}/ot-cli-ftd.out
${BOARD}                        brd4186c
${QUANTUM_TIME}                 0.000050
${RNG_SEED}                     0
${UART}                         usart0
${DEFAULT_UART_TIMEOUT}         10
${PROMPT}                       >

*** Keywords ***
Initial Setup
    Execute Command             emulation SetGlobalSerialExecution true
    IF  ${RNG_SEED} > 0
        Execute Command         emulation SetSeed ${RNG_SEED}
    END
    ${RNG_SEED}=                Execute Command  emulation GetSeed
    Log To Console              RNG SEED: ${RNG_SEED}
    Execute Command             emulation SetQuantum "${QUANTUM_TIME}"
    Execute Command             emulation SetAdvanceImmediately true
    Execute Command             emulation CreateIEEE802_15_4Medium "wireless"
    Set Default Uart Timeout    ${DEFAULT_UART_TIMEOUT}
    Execute Command             logLevel 3

Create Node
    [Arguments]  ${machine_name}
    [Return]     ${tester_id}
    Execute Command             mach clear
    Execute Command             mach create "${machine_name}"
    Execute Command             machine LoadPlatformDescription @platforms/boards/silabs/${BOARD}.repl
    Execute Command             sysbus LoadELF @${ELF}
    Execute Command             sysbus LogAllPeripheralsAccess false
    Execute Command             connector Connect sysbus.radio wireless
    ${tester_id}=               Create Terminal Tester  sysbus.${UART}  machine=${machine_name}  defaultPauseEmulation=true
    # This command togehter with using the "--enable-xwt" option when launching renote-test 
    # pops up a UART shell for each node and allows to see the nodes CLI activity.
    #Execute Command             showAnalyzer ${UART}

Leader Start
    [Arguments]  ${tester}
    [Return]     ${key.line}
    Write Line To Uart          dataset init new  testerId=${tester}
    Wait For Line On Uart       Done  testerId=${tester}

    Write Line To Uart          dataset commit active  testerId=${tester}
    Wait For Line On Uart       Done  testerId=${tester}

    Write Line To Uart          dataset networkkey  testerId=${tester}
    ${key}                      Wait For Line On Uart  ^.{32}$  testerId=${tester}  treatAsRegex=true  timeout=5
    Log                         parsed key ${key.line}
    Wait For Line On Uart       Done  testerId=${tester}

    Write Line To Uart          ifconfig up  testerId=${tester}
    Wait For Line On Uart       Done  testerId=${tester}

    Write Line To Uart          thread start  testerId=${tester}
    Wait For Line On Uart       Role detached -> leader  testerId=${tester}  timeout=30

    Write Line To Uart          state  testerId=${tester}
    Wait For Line On Uart       leader  testerId=${tester}
    Wait For Line On Uart       Done  testerId=${tester}

Router Start
    [Arguments]  ${tester}  ${network_key}
    Write Line To Uart          dataset networkkey ${network_key}  testerId=${tester}
    Wait For Line On Uart       Done  testerId=${tester}

    Write Line To Uart          dataset commit active  testerId=${tester}
    Wait For Line On Uart       Done  testerId=${tester}

    Write Line To Uart          ifconfig up  testerId=${tester}
    Wait For Line On Uart       Done  testerId=${tester}

    Write Line To Uart          thread start  testerId=${tester}
    Wait For Line On Uart       Role detached -> child  testerId=${tester}  timeout=30

*** Test Cases ***
Open Thread FTD Basic Test
    Initial Setup

    ${NODE1_TESTER_ID}=         Create Node  node1
    ${NODE2_TESTER_ID}=         Create Node  node2

    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE1_TESTER_ID}
    Wait For Prompt On Uart     ${PROMPT}  testerId=${NODE2_TESTER_ID}

    ${network_key}              Leader Start  ${NODE1_TESTER_ID}

    Router Start                ${NODE2_TESTER_ID}  ${network_key}