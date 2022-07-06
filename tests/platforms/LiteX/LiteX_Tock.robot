*** Test Cases ***
Should Run Tock
    Execute Command             include @scripts/single-node/litex_vexriscv_tock.resc
    Create Terminal Tester      sysbus.uart

    Start Emulation
    Wait For Line On Uart       LiteX+VexRiscv on ArtyA7: initialization complete, entering main loop.

    Wait For Line On Uart       D1 says hello
    Wait For Line On Uart       D2 says hello

    Wait For Line On Uart       D1 says hello
    Wait For Line On Uart       D2 says hello

    Wait For Line On Uart       D1 says hello
    Wait For Line On Uart       D2 says hello
