*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${UART}                             sysbus.uart
${CPU_IBEX_NATIVE_LINUX}            ${URI}/libVcpu_ibex-Linux-x86_64-13112907851.so-s_2251128-ab2dcb1801188d7f934bdeafa93f9c1edc60ad39
${CPU_IBEX_NATIVE_WINDOWS}          ${URI}/libVcpu_ibex-Windows-x86_64-13112907851.dll-s_3426669-58d11ffc81ea755c1d1151e6b33fc13164bb13d5
${CPU_IBEX_NATIVE_MACOS}            ${URI}/libVcpu_ibex-macOS-x86_64-13112907851.dylib-s_336528-7677f09f18bfb2937ad2bffdd63ed7d76bb15d56

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/verilated/verilated_ibex.repl
    Execute Command                 sysbus.cpu SimulationFilePathLinux ${CPU_IBEX_NATIVE_LINUX}
    Execute Command                 sysbus.cpu SimulationFilePathWindows ${CPU_IBEX_NATIVE_WINDOWS}
    Execute Command                 sysbus.cpu SimulationFilePathMacOS ${CPU_IBEX_NATIVE_MACOS}
    Execute Command                 logLevel 3
    Execute Command                 $c_example=@https://dl.antmicro.com/projects/renode/verilated-ibex--c_example.elf-s_5956-ea5ae45679b4070cd21933b9602bbcfd80302c93
    Execute Command                 showAnalyzer ${UART}
    Execute Command                 sysbus LoadELF $c_example
    Create Terminal Tester          ${UART}

Check Register By Name
    [Arguments]                     ${register}     ${x}
    ${value}=  Execute Command      cpu ${register}
    ${valuen}=  Convert To Integer  ${value}
    ${xn}=  Convert To Integer      ${x}            16
    Should Be True                  ${valuen} == ${xn}

Check Register
    [Arguments]                     ${register}     ${x}
    ${value}=  Execute Command      cpu GetRegister ${register}
    ${valuen}=  Convert To Integer  ${value}
    ${xn}=  Convert To Integer      ${x}            16
    Should Be True                  ${valuen} == ${xn}

Set Register By Name
    [Arguments]                     ${register}     ${x}
    Execute Command                 cpu ${register} ${x}

Step
    Execute Command                 cpu Step

*** Test Cases ***
Should Read Write Registers
    [Tags]                          skip_host_arm
    Create Machine

    # start
    Check Register By Name          PC  0x80
    Step

    # first instruction
    Check Register By Name          PC  0x82
    Check register                  2   0xfffffff0
    Check register                  8   0x0
    Step

    # second instruction
    Check Register By Name          PC  0x84
    Check register                  2   0xfffffff0
    Check register                  8   0x0
    
    # jump to begin
    Set Register By Name            PC  0x80
    Check Register By Name          PC  0x80
    Step
    Check Register By Name          PC  0x82
    Step
    Check Register By Name          PC  0x84
    Step
    Check Register By Name          PC  0x86
    Step

    Provides                        ecall  Reexecution

Should Be In Machine Mode
    [Tags]                          skip_host_arm
    Requires                        ecall
    Check Register By Name          MCAUSE  0xb
    Check Register By Name          MEPC    0x86
    Execute Command                 cpu ExecutionMode Continuous
    Provides                        continuous-mode  Reexecution

Should Print Hello On Uart
    [Tags]                          skip_host_arm
    Requires                        continuous-mode
    Wait For Line On Uart           hello
    Provides                        hello  Reexecution

Should Print Hello On Uart Again
    [Tags]                          skip_host_arm
    Requires                        hello
    Wait For Line On Uart           hello
