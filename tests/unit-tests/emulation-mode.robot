
*** Test Cases ***
UART Should Fail On High Quantum
    Execute Command          include @scripts/single-node/miv.resc
    Execute Command          emulation SetGlobalQuantum "10"
    Execute Command          emulation Mode SynchronizedIO

    Create Terminal Tester   sysbus.uart  timeout=1
    Start Emulation

    Wait For Prompt On Uart  uart
    Write Line To Uart       help  waitForEcho=false
    Test If Uart Is Idle     5

UART Should Respond On High Quantum
    Execute Command          include @scripts/single-node/miv.resc
    Execute Command          emulation SetGlobalQuantum "10"
    Execute Command          emulation Mode SynchronizedTimers

    Create Terminal Tester   sysbus.uart  timeout=1
    Start Emulation

    Wait For Prompt On Uart  uart
    Write Line To Uart       help
    Wait For Line On Uart    Please press the <Tab> button to see all available commands.
