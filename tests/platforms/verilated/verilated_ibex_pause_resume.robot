*** Variables ***
${URI}                          @https://dl.antmicro.com/projects/renode
${UART}                         sysbus.uart
${CPU_IBEX_NATIVE_LINUX}        ${URI}/libVcpu_ibex-Linux-x86_64-13112907851.so-s_2251128-ab2dcb1801188d7f934bdeafa93f9c1edc60ad39
${CPU_IBEX_NATIVE_WINDOWS}      ${URI}/libVcpu_ibex-Windows-x86_64-13112907851.dll-s_3426669-58d11ffc81ea755c1d1151e6b33fc13164bb13d5
${CPU_IBEX_NATIVE_MACOS}        ${URI}/libVcpu_ibex-macOS-x86_64-13112907851.dylib-s_336528-7677f09f18bfb2937ad2bffdd63ed7d76bb15d56

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/verilated/verilated_ibex.repl
    Execute Command                 sysbus.cpu SimulationFilePathLinux ${CPU_IBEX_NATIVE_LINUX}
    Execute Command                 sysbus.cpu SimulationFilePathWindows ${CPU_IBEX_NATIVE_WINDOWS}
    Execute Command                 sysbus.cpu SimulationFilePathMacOS ${CPU_IBEX_NATIVE_MACOS}
    Execute Command                 logLevel 3
    Execute Command                 $bios=@https://dl.antmicro.com/projects/renode/litex_ibex--bios.bin-s_20712-80d064cf8ab28801b78c0e5a63cac4830016f6c8
    Execute Command                 showAnalyzer ${UART}
    Execute Command                 sysbus LoadBinary $bios 0x0
    Execute Command                 cpu PC 0x0
    Create Terminal Tester          ${UART}
    Start Emulation

Get Virtual Time
    ${out}=  Execute Command        emulation GetTimeSourceInfo
    ${match}=  Get Regexp Matches   ${out}      Elapsed Virtual Time: 00:00:([0-9]+).([0-9]+)     1  2
    ${mc}=  Convert To Integer      ${match[0][1]}
    ${se}=  Convert To Integer      ${match[0][0]}
    ${t}=   Evaluate                ${mc} + ${se} * 1000000
    RETURN  ${t}

Sleep And Measure
    ${t1}=  Get Virtual Time
    Sleep                       4s
    ${t2}=  Get Virtual Time
    Should Be Equal             ${t1}  ${t2}


*** Test Cases ***
Should Pause And Resume
    [Tags]                          skip_host_arm
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!  pauseEmulation=true
    Sleep And Measure
    Execute Command             start
    Wait For Line On Uart       CPU:\\s+Ibex               treatAsRegex=true

Should Pause And Resume Cpu
    [Tags]                          skip_host_arm
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!
    Execute Command             cpu Pause
    Sleep And Measure
    Execute Command             cpu Resume
    Wait For Line On Uart       CPU:\\s+Ibex               treatAsRegex=true

Should Enter Single Step Blocking
    [Tags]                          skip_host_arm
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!
    Execute Command             cpu ExecutionMode SingleStep
    Sleep And Measure
    Execute Command             cpu ExecutionMode Continuous
    Wait For Line On Uart       CPU:\\s+Ibex               treatAsRegex=true

Should Enter Single Step Non Blocking
    [Tags]                          skip_host_arm
    Create Machine
    Execute Command             emulation SingleStepBlocking false

    Wait For Line On Uart       Build your hardware, easily!
    Execute Command             cpu ExecutionMode SingleStep
    ${t1}=  Get Virtual Time
    Test If Uart Is Idle        4
    ${t2}=  Get Virtual Time
    Should Be True              ${t2} - ${t1} >= 4000000
    Execute Command             cpu ExecutionMode Continuous
    Wait For Line On Uart       CPU:\\s+Ibex               treatAsRegex=true

Should Reset
    [Tags]                          skip_host_arm
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!

    Execute Command             cpu Reset
    Execute Command             cpu PC 0x0
    Execute Command             cpu Resume

    Wait For Line On Uart       Build your hardware, easily!
