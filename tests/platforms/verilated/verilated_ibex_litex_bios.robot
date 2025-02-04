*** Variables ***
${URI}                         @https://dl.antmicro.com/projects/renode
${UART}                        sysbus.uart
${CPU_IBEX_NATIVE_LINUX}       ${URI}/libVcpu_ibex-Linux-x86_64-13112907851.so-s_2251128-ab2dcb1801188d7f934bdeafa93f9c1edc60ad39
${CPU_IBEX_NATIVE_WINDOWS}     ${URI}/libVcpu_ibex-Windows-x86_64-13112907851.dll-s_3426669-58d11ffc81ea755c1d1151e6b33fc13164bb13d5
${CPU_IBEX_NATIVE_MACOS}       ${URI}/libVcpu_ibex-macOS-x86_64-13112907851.dylib-s_336528-7677f09f18bfb2937ad2bffdd63ed7d76bb15d56


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
