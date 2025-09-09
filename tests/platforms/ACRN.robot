*** Variables ***
${UART}                       sysbus.uart
${SCRIPT_ZEPHYR}              @scripts/single-node/acrn_x86_64-zephyr.resc

*** Test Cases ***
Should Run Zephyr hello_world Sample
    Execute Command           include ${SCRIPT_ZEPHYR}
    Create Terminal Tester    ${UART}
    Wait For Line On Uart     Hello World! acrn
