
*** Variables ***
${UART}                       sysbus.lpuart6

*** Test Cases ***
Run Example EchoBoth
    Execute Command           set bin @https://gist.githubusercontent.com/xndcn/b76f45c4ce2e2537975a0e72c1415ceb/raw/b881439670b2955a9935bf08e9a68b20719fd96f/EchoBoth.ino.hex
    Execute Command           include @scripts/single-node/teensy-41.resc

    Execute Command           showAnalyzer ${UART}
    Create Terminal Tester    ${UART}

    Start Emulation

    Write To Uart             Hello
    Wait For Line On Uart     UART received:72
    Wait For Line On Uart     UART received:101
    Wait For Line On Uart     UART received:108
    Wait For Line On Uart     UART received:108
    Wait For Line On Uart     UART received:111

