*** Variables ***
${UART}                        sysbus.uart

*** Test Cases ***
Should Boot
    Execute Command            i @scripts/single-node/verilated_ibex.resc
    Create Terminal Tester     ${UART}

    Start Emulation

    Wait For Line On Uart      BIOS CRC passed
    Wait For Line On Uart      CPU:\\s+Ibex               treatAsRegex=true

    Wait For Line On Uart      Press Q or ESC to abort boot completely.    timeout=3600
    # send Q
    Send Key To Uart           0x51
    
    Wait For Prompt On Uart    litex>
    WriteCharDelay             0.1
    Write Line To Uart         help
    Wait For Line On Uart      LiteX BIOS, available commands:
