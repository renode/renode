*** Keywords ***
Create Platform
    Execute Command            using sysbus
    Execute Command            mach create
    # This line must use the "path" notation to handle paths with spaces
    Execute Command            machine LoadPlatformDescription "${CURDIR}${/}nexys4ddr_litex_vexriscv.repl"
    Execute Command            sysbus LoadBinary @https://dl.antmicro.com/projects/renode/nexys4ddr_litex_vexriscv--LiteX_BIOS.bin-s_24596-e36b0274a43f416295c6150f0f6fe9070c248761 0x0
    Execute Command            machine SdCardFromFile @https://dl.antmicro.com/projects/renode/fat16_sdcard.image-s_64000000-8a919aa2199e1a1cf086e67546b539295d2d9d8f spisdcard 0x100000000 False

    Execute Command            cpu PC 0x0


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

    Provides                   booted-image

Should List Readme File
    Requires                   booted-image

    Write Line To Uart         spisdcardboot

    Wait For Line On Uart      SD Card via SPI Initialising
    Wait For Line On Uart      Read FAT16 Boot Sector
    Wait For Line On Uart      [mkfs.fat]
    Wait For Line On Uart      Root Directory
    Wait For Line On Uart      File 1 [README${SPACE*2}.TXT]
