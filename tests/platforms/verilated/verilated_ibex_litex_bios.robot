*** Variables ***
${URI}                         @https://dl.antmicro.com/projects/renode
${UART}                        sysbus.uart
${CPU_IBEX_NATIVE_LINUX}       ${URI}/verilated-ibex--libVtop-s_2214528-ebb048cb40ded91b7ddce15a4a9c303f18f36998
${CPU_IBEX_NATIVE_WINDOWS}     ${URI}/verilated-ibex--libVtop.dll-s_3253532-6f580a2d9bf4f525d5e5e6432d0cb1ff4efa9c75
${CPU_IBEX_NATIVE_MACOS}       ${URI}/verilated-ibex--libVtop.dylib-s_329984-1446a5b2d8a92b894bf1b78d16c30cd443c28527

*** Test Cases ***
Should Boot
    Execute Command            \$cpuLinux?=${CPU_IBEX_NATIVE_LINUX}
    Execute Command            \$cpuWindows?=${CPU_IBEX_NATIVE_WINDOWS}
    Execute Command            \$cpuMacOS?=${CPU_IBEX_NATIVE_MACOS}
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
