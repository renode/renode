*** Variables ***
${UART}                       sysbus.lpuart2

*** Test Cases ***
Should Run Shell Module
    Execute Command           i @scripts/single-node/nxp-s32k388_zephyr.resc
    Create Terminal Tester    ${UART}

    Wait For Prompt On Uart   uart:~$
    Write Line To Uart        demo board
    Wait For Line On Uart     s32k388/virtual_board
    
