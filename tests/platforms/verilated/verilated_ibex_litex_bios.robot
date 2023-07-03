*** Variables ***
${URI}                         @https://dl.antmicro.com/projects/renode
${UART}                        sysbus.uart
${BIOS}                        ${URI}/litex_ibex--bios.bin-s_20712-80d064cf8ab28801b78c0e5a63cac4830016f6c8
${CPU_IBEX_NATIVE_LINUX}       ${URI}/verilated-ibex--libVtop-s_2214528-ebb048cb40ded91b7ddce15a4a9c303f18f36998
${CPU_IBEX_NATIVE_WINDOWS}     ${URI}/verilated-ibex--libVtop.dll-s_3253532-6f580a2d9bf4f525d5e5e6432d0cb1ff4efa9c75
${CPU_IBEX_NATIVE_MACOS}       ${URI}/verilated-ibex--libVtop.dylib-s_329984-1446a5b2d8a92b894bf1b78d16c30cd443c28527

*** Test Cases ***
Should Boot
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @platforms/cpus/verilated/verilated_ibex.repl
    Execute Command            sysbus.cpu SimulationFilePathLinux ${CPU_IBEX_NATIVE_LINUX}
    Execute Command            sysbus.cpu SimulationFilePathWindows ${CPU_IBEX_NATIVE_WINDOWS}
    Execute Command            sysbus.cpu SimulationFilePathMacOS ${CPU_IBEX_NATIVE_MACOS}
    Execute Command            sysbus LoadBinary ${BIOS} 0x0
    Execute Command            sysbus.cpu PC 0x0
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
