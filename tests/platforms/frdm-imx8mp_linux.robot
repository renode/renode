*** Test Cases ***
Should Boot Linux
    [Timeout]                     NONE
    Execute Command               include @scripts/single-node/nxp-imx8mplus_linux.resc
    Create Terminal Tester        sysbus.uart2  timeout=120

    Wait For Line On Uart         ==== Hello World! Linux i.MX 8M Plus ====
    Wait For Prompt On Uart       \#${SPACE}
    Write Line To Uart            uname -a
    Wait For Line On Uart         Linux
