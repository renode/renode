*** Variables ***
${URI}                         @https://dl.antmicro.com/projects/renode
${UART}                        sysbus.uart
${CPU_IBEX_NATIVE_LINUX}       ${URI}/libVcpu_ibex-Linux-x86_64-12904733885.so-s_2251128-ee84935737438cde45d07e29650c3770e680c5a3
${CPU_IBEX_NATIVE_WINDOWS}     ${URI}/libVcpu_ibex-Windows-x86_64-12904733885.dll-s_3426636-7318c5592dcf2a48e7fce8bb13a175ee1cfdd0f4
${CPU_IBEX_NATIVE_MACOS}       ${URI}/libVcpu_ibex-macOS-x86_64-12904733885.dylib-s_336528-bb23d4db50f720a118047b7c21ded5bf395ae849


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
