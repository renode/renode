*** Variables ***
${URL}                  https://dl.antmicro.com/projects/renode
${AGT_ELF}              renesas_ra6m5--agt.elf-s_303444-613fbe7bc11ecbc13afa7a8a907682bbbb2a3458
${HELLO_WORLD_ELF}      ra6m5-hello_world.elf-s_310112-5e896556c868826bc8d25d695202ebe0beed7df2
${AWS_SCI_I2C_ELF}      renesas_ra6m5--aws.elf-s_795908-8da7d7d21c633826e0b6a98ff841007212ad99c9

${ICP_101XX_REPL}       "barometer: Sensors.ICP_101xx @ sci0 0x44"

${LED_REPL}             SEPARATOR=\n
...  """
...  led: Miscellaneous.LED @ port6 10
...
...  port6:
...  ${SPACE*4}10 -> led@0
...  """

${BUTTON_REPL}          SEPARATOR=\n
...  """
...  button: Miscellaneous.Button @ port8 4
...  ${SPACE*4}-> port8@4
...  """

*** Keywords ***
Prepare Machine
    [Arguments]                 ${bin}
    Execute Command             using sysbus
    Execute Command             mach create "ra6m5"

    Execute Command             machine LoadPlatformDescription @platforms/cpus/renesas-r7fa6m5b.repl

    Execute Command             set bin @${URL}/${bin}
    Execute Command             macro reset "sysbus LoadELF $bin"
    Execute Command             runMacro $reset

Prepare Segger RTT
    Execute Command             machine CreateVirtualConsole "segger_rtt"
    Execute Command             include @scripts/single-node/renesas-segger-rtt.py
    Execute Command             setup_segger_rtt sysbus.segger_rtt
    Create Terminal Tester      sysbus.segger_rtt

Prepare LED Tester
    Execute Command             machine LoadPlatformDescriptionFromString ${LED_REPL}
    Create Led Tester           sysbus.port6.led

Prepare ICP_10101 Sensor
    # This is not a part of the platform, as on the physical board ICP sensor is connected to the I2C peripheral rather than the SCI in I2C mode
    Execute Command             machine LoadPlatformDescriptionFromString ${ICP_101XX_REPL}

Prepare UART Tester
    Create Terminal Tester      sysbus.sci0

*** Test Cases ***
Should Run Periodically Blink LED
    Prepare Machine             ${AGT_ELF}
    Prepare LED Tester
    Prepare Segger RTT

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

Should Run Hello World Demo
    Prepare Machine             ${HELLO_WORLD_ELF}
    Execute Command             machine LoadPlatformDescriptionFromString ${BUTTON_REPL}
    Prepare UART Tester

    Start Emulation
    Wait For Line On Uart       Hello world!
    Wait For Line On Uart       Blinking available LEDs with 1Hz frequency: P1546, P1545, P1537, P1538, P1539, P1541
    Wait For Line On Uart       LEDS OFF
    Wait For Line On Uart       LEDS ON
    Wait For Line On Uart       LEDS OFF
    Wait For Line On Uart       LEDS ON

    # Test GPIO IRQ, button (PORT8.4) allows to toggle blinking

    # Stop blinking
    Execute Command             port8.button PressAndRelease
    Wait For Line On Uart       Blinking has been disabled
    # LEDS OFF and LEDS ON messages shouldn't be printed anymore
    Should Not Be On Uart       LEDS OFF   timeout=1
    Should Not Be On Uart       LEDS ON   timeout=1

    # Star blinking again
    Execute Command             port8.button PressAndRelease
    Wait For Line On Uart       Blinking has been enabled
    Wait For Line On Uart       LEDS OFF
    Wait For Line On Uart       LEDS ON
    Wait For Line On Uart       LEDS OFF
    Wait For Line On Uart       LEDS ON

Should Get Correct Temperature Readouts From ICP10101
    Prepare Machine            ${AWS_SCI_I2C_ELF}
    Prepare ICP_10101 Sensor
    Prepare SEGGER_RTT

    Start Emulation
    Wait For Line On Uart           Renesas FSP Application Project
    Wait For Line On Uart           I2C bus setup success
    Wait For Line On Uart           ICP Sensor Data
    Wait For Line On Uart           Temperature -000.000

    Execute Command                 sysbus.sci0.barometer DefaultTemperature 13.5
    Wait For Line On Uart           Temperature\\s+013.498  treatAsRegex=true
