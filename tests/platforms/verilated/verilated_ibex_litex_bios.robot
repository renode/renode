*** Variables ***
${URI}                         @https://dl.antmicro.com/projects/renode
${UART}                        sysbus.uart
${CPU_IBEX_NATIVE_LINUX}       ${URI}/libVcpu_ibex-Linux-x86_64-10267006380.so-s_2224472-d6ea2673d9e1f9a912f7cd96fcc8c0efdff937be
${CPU_IBEX_NATIVE_WINDOWS}     ${URI}/libVcpu_ibex-Windows-x86_64-10267006380.dll-s_3392612-4aa33470a0038709c264745daa170a8cee95a76e
${CPU_IBEX_NATIVE_MACOS}       ${URI}/libVcpu_ibex-macOS-x86_64-10267006380.dylib-s_316064-e60c296740d38ca6e8e4811dd98309ba6d6ca7e2

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
