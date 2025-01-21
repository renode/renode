*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${UART}                             sysbus.uart
${CPU_IBEX_NATIVE_LINUX}            ${URI}/libVcpu_ibex-Linux-x86_64-12746432362.so-s_2224440-fb03313c1ba631156fcbbb5593a4f66e4c5fe459
${CPU_IBEX_NATIVE_WINDOWS}          ${URI}/libVcpu_ibex-Windows-x86_64-12746432362.dll-s_3401444-3e4e24fdc95d7436b490c95285169b3748ed2b76
${CPU_IBEX_NATIVE_MACOS}            ${URI}/libVcpu_ibex-macOS-x86_64-12746432362.dylib-s_316064-ca204a33af0e742a326cf3cc407608caed5b225e

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
    Requires                        ecall
    Check Register By Name          MCAUSE  0xb
    Check Register By Name          MEPC    0x86
    Execute Command                 cpu ExecutionMode Continuous
    Provides                        continuous-mode  Reexecution

Should Print Hello On Uart
    Requires                        continuous-mode
    Wait For Line On Uart           hello
    Provides                        hello  Reexecution

Should Print Hello On Uart Again
    Requires                        hello
    Wait For Line On Uart           hello
