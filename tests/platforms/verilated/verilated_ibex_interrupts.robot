*** Variables ***
${UART}                             sysbus.uart

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/verilated/verilated_ibex.repl
    Execute Command                 sysbus.cpu SimulationFilePathLinux @https://dl.antmicro.com/projects/renode/verilated-ibex--libVtop-s_2214528-ebb048cb40ded91b7ddce15a4a9c303f18f36998
    Execute Command                 sysbus.cpu SimulationFilePathWindows @https://dl.antmicro.com/projects/renode/verilated-ibex--libVtop.dll-s_3253532-6f580a2d9bf4f525d5e5e6432d0cb1ff4efa9c75
    Execute Command                 sysbus.cpu SimulationFilePathMacOS @https://dl.antmicro.com/projects/renode/verilated-ibex--libVtop.dylib-s_329984-1446a5b2d8a92b894bf1b78d16c30cd443c28527
    Execute Command                 logLevel 3
    Execute Command                 $c_example=@https://dl.antmicro.com/projects/renode/verilated-ibex--c_example.elf-s_5956-ea5ae45679b4070cd21933b9602bbcfd80302c93
    Execute Command                 showAnalyzer ${UART}
    Execute Command                 sysbus LoadELF $c_example
    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Create Terminal Tester          ${UART}
    Start Emulation

Check Register By Name
    [Arguments]                     ${register}     ${x}
    ${value}=  Execute Command      cpu ${register}
    ${valuen}=  Convert To Integer  ${value}
    ${xn}=  Convert To Integer      ${x}            16
    Should Be True                  ${valuen} == ${xn}

Check Register
    [Arguments]                     ${register}     ${x}
    ${value}=  Execute Command      cpu GetRegisterUnsafe ${register}
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
