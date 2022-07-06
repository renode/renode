*** Test Cases ***
Download File Over TFTP
    Execute Command             using sysbus
    Execute Command             mach create "litex-vexriscv"
    Execute Command             machine LoadPlatformDescription "${CURDIR}/litex_vexriscv.repl"
    Execute Command             sysbus LoadBinary @https://dl.antmicro.com/projects/renode/bios.bin-s_27076-9b28166a445deb24d5d3547871ae0de8365ba4d0 0x0
    Execute Command             cpu PC 0x0

    Execute Command             emulation CreateSwitch "switch"
    Execute Command             connector Connect ethmac switch

    Execute Command             emulation CreateNetworkServer "server" "192.168.100.100"
    Execute Command             connector Connect server switch
    Execute Command             server StartTFTP 6069
    Execute Command             server.tftp ServeFile @https://dl.antmicro.com/projects/renode/litex_vexriscv-micropython.bin-s_218608-db594ec6a9a75d77d2475afd714b6c28fb6e6498 "boot.bin"

    Create Terminal Tester      sysbus.uart
    Execute Command             showAnalyzer sysbus.uart
    Start Emulation

    Wait For Line On Uart      Press Q or ESC to abort boot completely.
    # send Q
    Send Key To Uart           0x51 
    
    Wait For Prompt On Uart    litex> 
    Write Line To Uart         netboot

    Wait For Line On Uart      Downloaded 218608 bytes from boot.bin over TFTP to 0x40000000
    Wait For Line On Uart      MicroPython v1.9.4-1431

    Wait For Prompt On Uart    >>>

    Write Line To Uart         2 + 3
    Wait For Line On Uart      5

