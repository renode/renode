*** Variables ***
${AGT_ELF}                          https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--agt.elf-s_390120-5dfd54a412e405b4527aba3b32e9590e668fbfcf

*** Keywords ***
Prepare Machine
    [Arguments]                     ${elf}
    Execute Command                 using sysbus
    Execute Command                 mach create "ra8m1"

    Execute Command                 machine LoadPlatformDescription @platforms/boards/ek-ra8m1.repl

    Execute Command                 set bin @${elf}
    Execute Command                 macro reset "sysbus LoadELF $bin"
    Execute Command                 runMacro $reset

Prepare Segger RTT
    [Arguments]                     ${pauseEmulation}=true
    Execute Command                 machine CreateVirtualConsole "segger_rtt"
    Execute Command                 include @scripts/single-node/renesas-segger-rtt.py
    Execute Command                 setup_segger_rtt sysbus.segger_rtt
    Create Terminal Tester          sysbus.segger_rtt  defaultPauseEmulation=${pauseEmulation}

Prepare LED Tester
    Create Led Tester               sysbus.port6.led_blue

*** Test Cases ***
Should Run Periodically Blink LED
    Prepare Machine                 ${AGT_ELF}
    Prepare LED Tester
    Prepare Segger RTT

    Execute Command                 agt0 IRQ AddStateChangedHook "Antmicro.Renode.Logging.Logger.Log(LogLevel.Error, 'AGT0 ' + str(state))"
    # Timeout is only used for checking whether the IRQ has been handled
    Create Log Tester               0.001  defaultPauseEmulation=true

    # Configuration is roughly in ms
    Wait For Prompt On Uart         One-shot mode:
    Write Line To Uart              10  waitForEcho=false
    Wait For Line On Uart           Time period for one-shot mode timer: 10

    Wait For Prompt On Uart         Periodic mode:
    Write Line To Uart              5  waitForEcho=false
    Wait For Line On Uart           Time period for periodic mode timer: 5

    Wait For Prompt On Uart         Enter any key to start or stop the timers
    Write Line To Uart              waitForEcho=false

    # Timeout is extended by an additional 1ms to account for rounding errors
    Wait For Log Entry              AGT0 True  level=Error  timeout=0.011
    Wait For Log Entry              AGT0 False  level=Error
    # move to the beginning of a True state
    Assert Led State                True  timeout=0.01  pauseEmulation=true
    # Run test for 5 cycles
    Assert Led Is Blinking          testDuration=0.05  onDuration=0.005  offDuration=0.005  tolerance=0.2  pauseEmulation=true
    Assert Led State                True  timeout=0.005  pauseEmulation=true

    # Stop timers, clear log tester history and check whether the periodic timer stops
    Write Line To Uart              waitForEcho=false
    Wait For Line On Uart           Periodic timer stopped. Enter any key to start timers.
    Assert And Hold Led State       True  0.0  0.05
