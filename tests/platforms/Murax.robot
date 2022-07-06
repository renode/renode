*** Keywords ***
Create Murax
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @platforms/cpus/murax_vexriscv.repl

    Execute Command            sysbus LoadELF @https://dl.antmicro.com/projects/renode/murax--demo.elf-s_26952-7635fc30d0a3ed10c5b7cba622131b02d103f629
    Execute Command            sysbus.cpu MTVEC 0x80000020

    # this is a hack to allow handling interrupts at all; this should be fixed after #13326
    Execute Command            sysbus.cpu SetMachineIrqMask 0xffffffff


*** Test Cases ***
Echo On Uart
    Create Murax
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    # 'A' is written by the software at startup
    Write Char On Uart         n
    Write Char On Uart         t

    Wait For Prompt On Uart    Ant

Timer Blinking Led
    [Tags]                     non_critical
    Create Murax
    Execute Command            machine LoadPlatformDescriptionFromString "gpioA: { 7 -> led@0 }; led: Miscellaneous.LED @ gpioA 7"
    Execute Command            emulation CreateLEDTester "lt" sysbus.gpioA.led

    Execute Command            lt AssertState False

    Start Emulation

    Execute Command            lt AssertState True 1
    ${ts}=  Execute Command    machine GetTimeSourceInfo
    Should Contain             ${ts}      Elapsed Virtual Time: 00:00:01.

    Execute Command            lt AssertState False 1
    ${ts}=  Execute Command    machine GetTimeSourceInfo
    Should Contain             ${ts}      Elapsed Virtual Time: 00:00:02.

