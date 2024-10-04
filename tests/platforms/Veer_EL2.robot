*** Variables ***
${UART}                       sysbus.htif
${SCRIPT_ROT13}               @scripts/single-node/veer_el2-tock.resc

*** Test Cases ***
Should Run Tock Rot13 Sample
    Execute Command           include ${SCRIPT_ROT13}
    Create Terminal Tester    ${UART}
    Wait For Line On Uart     12: Uryyb Jbeyq!
    Wait For Line On Uart     12: Hello World!

