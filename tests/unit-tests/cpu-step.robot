*** Variables ***
${URI}                   @https://dl.antmicro.com/projects/renode


*** Keywords ***
Create Machine
    [Arguments]    ${step_blocking}=false
    Execute Command             using sysbus
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescription @platforms/cpus/sifive-fu540.repl

    Execute Command             sysbus LoadELF ${URI}/hifive-unleashed--bbl.elf-s_17219640-c7e1b920bf81be4062f467d9ecf689dbf7f29c7a
    Execute Command             sysbus LoadFdt ${URI}/hifive-unleashed--devicetree.dtb-s_10532-70cd4fc9f3b4df929eba6e6f22d02e6ce4c17bd1 0x81000000 "earlyconsole mem=256M@0x80000000"
    Execute Command             e51 SetRegister 11 0x81000000

    Execute Command             emulation SingleStepBlocking ${step_blocking}
    Execute Command             u54_1 ExecutionMode SingleStep

    Create Terminal Tester      sysbus.uart0

${cpu} PC ${should:(Should|Shouldn't)} Be Equal To ${pc_expected}
    ${pc}=  Execute Command     ${cpu} PC
    IF    "${should}" == "Should"
        Should Be Equal As Integers    ${pc}    ${pc_expected}
    ELSE
        Should Not Be Equal As Integers    ${pc}    ${pc_expected}
    END

SingleStep Should Be Blocking
    ${isBlocking}=  Execute Command    emulation SingleStepBlocking
    Should Be True                     ${isBlocking}

*** Test Cases ***
Should Start Execution With One Core In SingleStepNonBlocking
    Create Machine
    Execute Command             start
    Wait For Line On Uart       smp: Bringing up secondary CPUs


Should Step Core In SingleStepNonBlocking
    Create Machine
    Execute Command             start
    Wait For Line On Uart       smp: Bringing up secondary CPUs

    ${x}=  Execute Command      u54_1 PC
    Should Contain              ${x}  0x80000000

    Execute Command             u54_1 Step

    ${x}=  Execute Command      u54_1 PC
    Should Contain              ${x}  0x800001f8


Should Step Core In SingleStepNonBlocking Over Quantum Limit
    Create Machine
    Execute Command             u54_1 PerformanceInMips 1
    Execute Command             machine SetQuantum "00:00:00.000100"
    Execute Command             start
    Wait For Line On Uart       smp: Bringing up secondary CPUs

    # InstructionsPerQuantum = MIPS * Quantum =  10^6 * 10^-4 = 100  
    # Every Quant (time allowance) will consist of a maximum of 100 instructions
    # Thereby stepping by 101 steps, guarantees that the next Quantum will need to be given

    ${x}=  Execute Command      u54_1 Step 101
    Should Contain              ${x}  0x0000000080001C1C

Step Should Be Blocking By Default
    SingleStep Should Be Blocking

Step Should Be Blocking After Deserialization
    # Let's change to make sure the value isn't serialized.
    Execute Command             emulation SingleStepBlocking false

    ${tmp_file}=                Allocate Temporary File
    Execute Command             Save @${tmp_file}
    Execute Command             Load @${tmp_file}

    SingleStep Should Be Blocking

Test SingleStepBlocking Change After Blocking Steps
    Create Machine              step_blocking=True

    # Let's do a single step; PCs of other cores change on the first step.
    Execute Command             u54_1 Step

    # Let's keep PCs for two other cores.
    ${pc_e51}=
    ...    Execute Command      e51 PC
    ${pc_u54_2}=
    ...    Execute Command      u54_2 PC

    Execute Command             u54_1 Step 10

    # Let's make sure PCs are the same.
    e51 PC Should Be Equal To ${pc_e51}
    u54_2 PC Should Be Equal To ${pc_u54_2}

    # Now make SingleStep non-blocking without any other changes.
    Execute Command             emulation SingleStepBlocking false

    # Other cores should be able to reach it.
    Wait For Line On Uart       smp: Bringing up secondary CPUs

Should Step Multiple CPUs Alternately
    Create Machine              step_blocking=True
    Execute Command             u54_1 ExecutionMode Continuous
    Wait For Line On Uart       smp: Brought up 1 node, 4 CPUs
    Execute Command             e51 Step
    Execute Command             u54_1 Step

Should Handle Muliple Single Step CPUs In Serial Execution
    Create Machine              step_blocking=True
    Execute Command             u54_1 ExecutionMode Continuous
    Wait For Line On Uart       smp: Brought up 1 node, 4 CPUs
    Execute Command             emulation SetGlobalSerialExecution true
    Execute Command             u54_1 ExecutionMode SingleStep
    Execute Command             e51 Step
    Execute Command             u54_1 Step

Should Step Over Time Quantum With Multiple CPUs Active
    Create Machine              step_blocking=True
    Execute Command             u54_1 ExecutionMode Continuous
    Execute Command             emulation SetGlobalSerialExecution true
    Wait For Line On Uart       smp: Brought up 1 node, 4 CPUs      pauseEmulation=true
    Execute Command             emulation SetQuantum "00:00:00.000000050"
    Execute Command             emulation RunToNearestSyncPoint

    ${tsInfo}=                  Execute Command  emulation GetTimeSourceInfo
    Should Contain              ${tsInfo}   Elapsed Virtual Time: 00:00:00.243100000

    Execute Command             e51 Step 6

    ${tsInfo}=                  Execute Command  emulation GetTimeSourceInfo
    Should Contain              ${tsInfo}   Elapsed Virtual Time: 00:00:00.243100060
