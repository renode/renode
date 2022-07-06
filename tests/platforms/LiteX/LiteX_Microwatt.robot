*** Variables ***
${UART}                       sysbus.uart
${URI}                        @https://dl.antmicro.com/projects/renode
${BIOS}                       litex_microwatt--bios.bin-s_31172-0833ddddcf3d4aff1adcac22ac536c9c15f7c269

*** Keywords ***
Create Platform
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/litex_microwatt.repl

    Execute Command           sysbus LoadBinary ${URI}/${BIOS} 0x0
    Execute Command           sysbus.cpu PC 0x0

*** Test Cases ***
Should Boot
    Create Platform
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Line On Uart      Press Q or ESC to abort boot completely.
    # send Q
    Send Key To Uart           0x51
    
    Wait For Prompt On Uart    litex>

    Provides                   boot-finished

Should Display Help
    Requires                   boot-finished

    Write Line To Uart         help
    Wait For Line On Uart      LiteX BIOS, available commands:
