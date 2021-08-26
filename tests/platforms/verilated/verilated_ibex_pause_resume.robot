*** Settings ***
Suite Setup                     Setup
Suite Teardown                  Teardown
Test Setup                      Reset Emulation
Test Teardown                   Test Teardown
Resource                        ${RENODEKEYWORDS}

*** Variables ***
${UART}                         sysbus.uart

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/verilated/verilated_ibex.repl
    Execute Command                 sysbus.cpu SimulationFilePathLinux @https://dl.antmicro.com/projects/renode/verilated-ibex--libVtop-s_2214528-ebb048cb40ded91b7ddce15a4a9c303f18f36998
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
    [return]  ${t}

Sleep And Measure
    ${t1}=  Get Virtual Time
    Sleep                       4s
    ${t2}=  Get Virtual Time
    Should Be Equal             ${t1}  ${t2}


*** Test Cases ***
Should Pause And Resume
    # For now we build verilated Ibex only for Linux
    [Tags]                      skip_osx  skip_windows
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!
    Execute Command             pause
    Sleep And Measure
    Execute Command             start
    Wait For Line On Uart       CPU:\\s+Ibex               treatAsRegex=true

Should Pause And Resume Cpu
    # For now we build verilated Ibex only for Linux
    [Tags]                      skip_osx  skip_windows
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!
    Execute Command             cpu Pause
    Sleep And Measure
    Execute Command             cpu Resume
    Wait For Line On Uart       CPU:\\s+Ibex               treatAsRegex=true

Should Enter Single Step Blocking
    # For now we build verilated Ibex only for Linux
    [Tags]                      skip_osx  skip_windows
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!
    Execute Command             cpu ExecutionMode SingleStepBlocking
    Sleep And Measure
    Execute Command             cpu ExecutionMode Continuous
    Wait For Line On Uart       CPU:\\s+Ibex               treatAsRegex=true

Should Enter Single Step Non Blocking
    # For now we build verilated Ibex only for Linux
    [Tags]                      skip_osx  skip_windows
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!
    Execute Command             cpu ExecutionMode SingleStepNonBlocking
    ${t1}=  Get Virtual Time
    Test If Uart Is Idle        4
    ${t2}=  Get Virtual Time
    Should Be True              ${t2} - ${t1} >= 4000000
    Execute Command             cpu ExecutionMode Continuous
    Wait For Line On Uart       CPU:\\s+Ibex               treatAsRegex=true

Should Reset
    # For now we build verilated Ibex only for Linux
    [Tags]                      skip_osx  skip_windows
    Create Machine

    Wait For Line On Uart       Build your hardware, easily!

    Execute Command             cpu Reset
    Execute Command             cpu PC 0x0
    Execute Command             cpu Resume

    Wait For Line On Uart       Build your hardware, easily!
