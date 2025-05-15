*** Test Cases ***
Should Run Pigweed Bluetooth Advertiser
    Execute Command                 include @scripts/multi-node/imxrt500_nrf52840_pigweed_bt_advertiser.resc

    ${beacon_tester}=               Create Terminal Tester          sysbus.flexcomm12  machine=beacon_host
    ${observer_tester}=             Create Terminal Tester          sysbus.uart0  machine=observer_host

    Wait For Line On Uart           INF${SPACE*2}System init                                    testerId=${beacon_tester}
    Wait For Line On Uart           INF${SPACE*2}Registering RPC services                       testerId=${beacon_tester}
    Wait For Line On Uart           INF${SPACE*2}Starting threads                               testerId=${beacon_tester}
    Wait For Line On Uart           INF${SPACE*2}Running RPC server                             testerId=${beacon_tester}
    Wait For Line On Uart           INF${SPACE*2}Hello from bluetooth thread!                   testerId=${beacon_tester}  timeout=60
    Wait For Line On Uart           DBG${SPACE*2}initializing Transport                         testerId=${beacon_tester}
    Wait For Line On Uart           DBG${SPACE*2}CommandChannel initialized                     testerId=${beacon_tester}
    Wait For Line On Uart           INF${SPACE*2}Transport initialized                          testerId=${beacon_tester}
    Wait For Line On Uart           INF${SPACE*2}Beacon started, advertising as [0-9A-F:]+      testerId=${beacon_tester}  treatAsRegex=true

    Wait For Line On Uart           Device found: [0-9A-F:]+ \\(random\\) \\(RSSI -10\\), type 2, AD data len 28  testerId=${observer_tester}  treatAsRegex=true
