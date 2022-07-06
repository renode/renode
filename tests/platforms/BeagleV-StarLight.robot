*** Test Cases ***
Should Print Help
    Execute Command          include @scripts/single-node/beaglev_starlight.resc
    Create Terminal Tester   sysbus.uart3  1

    Start Emulation

    Wait For Line On Uart    OpenSBI v0.9
    Wait For Line On Uart    Platform Name\\s+: StarFive     treatAsRegex=true

    Wait For Line On Uart    U-Boot 2021.01

    Wait For Prompt On Uart  dwmac.10020000
    # send Enter press
    Send Key To Uart         0xD

    Wait For Prompt On Uart  StarFive #
    Write Line To Uart       help

    Wait For Line On Uart    base\\s+ - print or set address offset       treatAsRegex=true
    Wait For Line On Uart    cp\\s+ - memory copy                         treatAsRegex=true
    Wait For Line On Uart    unlz4\\s+ - lz4 uncompress a memory region   treatAsRegex=true

