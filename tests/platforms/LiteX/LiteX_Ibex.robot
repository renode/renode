*** Variables ***
${UART}                        sysbus.uart

*** Test Cases ***
Should Boot
    Execute Command            i @scripts/single-node/litex_ibex.resc
    Create Terminal Tester     ${UART}

    Start Emulation

    Wait For Line On Uart      BIOS CRC passed
    Wait For Line On Uart      CPU:\\s+Ibex               treatAsRegex=true

    Wait For Line On Uart      Press Q or ESC to abort boot completely.
    # send Q
    Send Key To Uart           0x51
    
    Wait For Prompt On Uart    litex>

    Provides                   boot-finished

Should Display Help
    Requires                   boot-finished

    Write Line To Uart         help
    Wait For Line On Uart      LiteX BIOS, available commands:
