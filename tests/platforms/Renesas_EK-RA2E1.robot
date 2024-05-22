*** Keywords ***
Prepare Machine
    Execute Command             include @scripts/single-node/ek-ra2e1.resc

*** Test Cases ***
Should Run Periodicaly Blink LED
    Prepare Machine
    Create Led Tester           sysbus.port9.led_blue
    Create Terminal Tester      sysbus.segger_rtt

    Execute Command             agt0 IRQ AddStateChangedHook "Antmicro.Renode.Logging.Logger.Log(LogLevel.Error, 'AGT0 ' + str(state))"
    # Timeout is only used for checking whether the IRQ has been handled
    Create Log Tester           0.001

    # Configuration is roughly in ms
    Wait For Prompt On Uart     One-shot mode:
    Write Line To Uart          10                                                      waitForEcho=false
    Wait For Line On Uart       Time period for one-shot mode timer: 10

    Wait For Prompt On Uart     Periodic mode:
    Write Line To Uart          5                                                       waitForEcho=false
    Wait For Line On Uart       Time period for periodic mode timer: 5

    Wait For Prompt On Uart     Enter any key to start or stop the timers
    Write Line To Uart                                                                  waitForEcho=false

    # Timeout is extended by an additional 1ms to account for rounding errors
    Wait For Log Entry          AGT0 True   level=Error    pauseEmulation=true  timeout=0.011
    Wait For Log Entry          AGT0 False  level=Error    pauseEmulation=true
    # move to the begining of a True state
    Assert Led State            True        timeout=0.01   pauseEmulation=true
    # Run test for 5 cycles
    Assert Led Is Blinking      testDuration=0.05  onDuration=0.005  offDuration=0.005  tolerance=0.2  pauseEmulation=true
    Assert Led State            True        timeout=0.005  pauseEmulation=true

    # Stop timers, clear log tester history and check whether the periodic timer stops
    Write Line To Uart                                                                  waitForEcho=false
    Wait For Line On Uart       Periodic timer stopped. Enter any key to start timers.  pauseEmulation=true
    Assert And Hold Led State   True  0.0  0.05
