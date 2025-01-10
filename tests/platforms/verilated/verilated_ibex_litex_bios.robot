*** Variables ***
${URI}                         @https://dl.antmicro.com/projects/renode
${UART}                        sysbus.uart
${CPU_IBEX_NATIVE_LINUX}       ${URI}/libVcpu_ibex-Linux-x86_64-12746432362.so-s_2224440-fb03313c1ba631156fcbbb5593a4f66e4c5fe459
${CPU_IBEX_NATIVE_WINDOWS}     ${URI}/libVcpu_ibex-Windows-x86_64-12746432362.dll-s_3401444-3e4e24fdc95d7436b490c95285169b3748ed2b76
${CPU_IBEX_NATIVE_MACOS}       ${URI}/libVcpu_ibex-macOS-x86_64-12746432362.dylib-s_316064-ca204a33af0e742a326cf3cc407608caed5b225e


*** Test Cases ***
Should Boot
    [Tags]                          skip_host_arm
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
