*** Settings ***
Resource                        bgapi_library.robot

*** Variables ***
${URI}                          @https://dl.antmicro.com/projects/renode
${ELF}                          ${URI}/bt_ncp_freertos.out
${EFR32_COMMON_SCRIPT}          scripts/complex/SiLabs/efr32_common.resc
${UART}                         eusart0
${BOARD}                        brd4186c
${QUANTUM_TIME}                 0.000020
${RNG_SEED}                     0

*** Keywords ***
Initial Setup
    Execute Script              ${EFR32_COMMON_SCRIPT}
    Execute Command             emulation SetGlobalSerialExecution true
    Execute Command             emulation SetQuantum "${QUANTUM_TIME}"
    Execute Command             emulation SetAdvanceImmediately true
    IF  ${RNG_SEED} > 0
        Execute Command         emulation SetSeed ${RNG_SEED}
    END
    ${RNG_SEED}=                Execute Command  emulation GetSeed
    Log To Console              RNG SEED: ${RNG_SEED}
    Execute Command             emulation CreateBLEMedium "wireless"
    Execute Command             logLevel 3

Create Node
    [Arguments]  ${machine_name}  ${port}
    Execute Command             mach clear
    Execute Command             mach create "${machine_name}"
    Execute Command             machine LoadPlatformDescription @platforms/boards/silabs/${BOARD}.repl
    Execute Command             sysbus LoadELF @${ELF}
    Execute Command             sysbus.cpu VectorTableOffset `sysbus GetSymbolAddress "__Vectors"`
    Execute Command             sysbus LogAllPeripheralsAccess false
    Execute Command             connector Connect sysbus.radio wireless
    Execute Command             emulation CreateServerSocketTerminal ${port} 'pty_${machine_name}' false
    Execute Command             connector Connect sysbus.${UART} pty_${machine_name}
    Execute Command             logLevel 3
    ${ret}=                     Ble Open Host Connection  ${port}
    RETURN                      ${ret}

*** Test Cases ***
BLE Test
    Initial Setup

    ${NODE1_TESTER_ID}=         Create Node  node1  3451
    ${NODE2_TESTER_ID}=         Create Node  node2  3452
    
    Ble Wait For Boot Event     ${NODE1_TESTER_ID}
    Ble Wait For Boot Event     ${NODE2_TESTER_ID}

    Ble Hello                   ${NODE1_TESTER_ID}
    Ble Hello                   ${NODE2_TESTER_ID}

    ${NODE1_ADDRESS}=           Ble Get Address  ${NODE1_TESTER_ID}
    ${NODE2_ADDRESS}=           Ble Get Address  ${NODE2_TESTER_ID}

    # Node 1 start advertising
    ${node1_adv_handle}=        Ble Legacy Advertiser Create Set  ${NODE1_TESTER_ID}
    Ble Legacy Advertiser Generate Data  ${node1_adv_handle}  2  ${NODE1_TESTER_ID}
    Ble Legacy Advertiser Start  ${node1_adv_handle}  2  ${NODE1_TESTER_ID}
    Ble Assert Event Queue Is Empty  ${NODE1_TESTER_ID}

    # Node 2 establish a connection to Node1
    Ble Connection Open         ${NODE1_ADDRESS}  0  ${NODE2_TESTER_ID}
    ${node1_conn_handle}=       Ble Wait For Connection Opened Event  ${NODE1_TESTER_ID}
    ${node2_conn_handle}=       Ble Wait For Connection Opened Event  ${NODE2_TESTER_ID}

    Ble Assert No Connection Closed Event  ${NODE1_TESTER_ID}
    Ble Assert No Connection Closed Event  ${NODE2_TESTER_ID}

    # Let some time pass and check that the connection is still open
    Execute Command        emulation RunFor "3"

    Ble Assert No Connection Closed Event  ${NODE1_TESTER_ID}
    Ble Assert No Connection Closed Event  ${NODE2_TESTER_ID}
