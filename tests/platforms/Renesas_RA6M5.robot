*** Variables ***
${URL}                              https://dl.antmicro.com/projects/renode
${AGT_ELF}                          renesas_ra6m5--agt.elf-s_303444-613fbe7bc11ecbc13afa7a8a907682bbbb2a3458
${HELLO_WORLD_ELF}                  ra6m5-hello_world.elf-s_310112-5e896556c868826bc8d25d695202ebe0beed7df2
${AWS_SCI_ICP10101_ELF}             renesas_ra6m5--aws-icp10101.elf-s_795916-3d68631f0fdfc3838fdba768d3a6d46312707ae3
${AWS_SCI_HS3001_ELF}               renesas_ra6m5--aws-hs3001.elf-s_758320-642c83fb428d4ccc1e35c2908178de232744dbad
${AWS_ZMOD4510_ELF}                 renesas_ra6m5--aws-zmod4510.elf-s_807176-4b4d580be7d9876f822205349432d3ea68172a17
${AWS_ZMOD4410_ELF}                 renesas_ra6m5--aws-zmod4410.elf-s_808224-8d79f1a1ff242d00131c12298f64420df21bc1d3

${RA6M5_REPL}                       platforms/cpus/renesas-r7fa6m5b.repl
${CK_BOARD_REPL}                    platforms/boards/renesas_ck_ra6m5_sensors_example.repl

${LED_REPL}                         SEPARATOR=\n
...                                 """
...                                 led: Miscellaneous.LED @ port6 10
...
...                                 port6:
...                                 ${SPACE*4}10 -> led@0
...                                 """

${BUTTON_REPL}                      SEPARATOR=\n
...                                 """
...                                 button: Miscellaneous.Button @ port8 4
...                                 ${SPACE*4}-> port8@4
...                                 """

*** Keywords ***
Create Machine
    [Arguments]                     ${bin}  ${repl}
    Execute Command                 using sysbus
    Execute Command                 mach create "ra6m5"

    Execute Command                 machine LoadPlatformDescription @${repl}

    Execute Command                 set bin @${URL}/${bin}
    Execute Command                 macro reset "sysbus LoadELF $bin"
    Execute Command                 runMacro $reset

Prepare Machine
    [Arguments]                     ${bin}
    Create Machine                  ${bin}  ${RA6M5_REPL}

Prepare Machine With IIC Sensors
    [Arguments]                     ${bin}
    Create Machine                  ${bin}  ${CK_BOARD_REPL}

Prepare Segger RTT
    Execute Command                 machine CreateVirtualConsole "segger_rtt"
    Execute Command                 include @scripts/single-node/renesas-segger-rtt.py
    Execute Command                 setup_segger_rtt sysbus.segger_rtt
    Create Terminal Tester          sysbus.segger_rtt

Prepare LED Tester
    Execute Command                 machine LoadPlatformDescriptionFromString ${LED_REPL}
    Create Led Tester               sysbus.port6.led

Prepare UART Tester
    Create Terminal Tester          sysbus.sci0

*** Test Cases ***
Should Run Periodically Blink LED
    Prepare Machine                 ${AGT_ELF}
    Prepare LED Tester
    Prepare Segger RTT

    Execute Command                 agt0 IRQ AddStateChangedHook "Antmicro.Renode.Logging.Logger.Log(LogLevel.Error, 'AGT0 ' + str(state))"
    # Timeout is only used for checking whether the IRQ has been handled
    Create Log Tester               0.001

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
    Wait For Log Entry              AGT0 True  level=Error  pauseEmulation=true  timeout=0.011
    Wait For Log Entry              AGT0 False  level=Error  pauseEmulation=true
    # move to the begining of a True state
    Assert Led State                True  timeout=0.01  pauseEmulation=true
    # Run test for 5 cycles
    Assert Led Is Blinking          testDuration=0.05  onDuration=0.005  offDuration=0.005  tolerance=0.2  pauseEmulation=true
    Assert Led State                True  timeout=0.005  pauseEmulation=true

    # Stop timers, clear log tester history and check whether the periodic timer stops
    Write Line To Uart              waitForEcho=false
    Wait For Line On Uart           Periodic timer stopped. Enter any key to start timers.  pauseEmulation=true
    Assert And Hold Led State       True  0.0  0.05

Should Run Hello World Demo
    Prepare Machine                 ${HELLO_WORLD_ELF}
    Execute Command                 machine LoadPlatformDescriptionFromString ${BUTTON_REPL}
    Prepare UART Tester

    Start Emulation
    Wait For Line On Uart           Hello world!
    Wait For Line On Uart           Blinking available LEDs with 1Hz frequency: P1546, P1545, P1537, P1538, P1539, P1541
    Wait For Line On Uart           LEDS OFF
    Wait For Line On Uart           LEDS ON
    Wait For Line On Uart           LEDS OFF
    Wait For Line On Uart           LEDS ON

    # Test GPIO IRQ, button (PORT8.4) allows to toggle blinking

    # Stop blinking
    Execute Command                 port8.button PressAndRelease
    Wait For Line On Uart           Blinking has been disabled
    # LEDS OFF and LEDS ON messages shouldn't be printed anymore
    Should Not Be On Uart           LEDS OFF  timeout=1
    Should Not Be On Uart           LEDS ON  timeout=1

    # Star blinking again
    Execute Command                 port8.button PressAndRelease
    Wait For Line On Uart           Blinking has been enabled
    Wait For Line On Uart           LEDS OFF
    Wait For Line On Uart           LEDS ON
    Wait For Line On Uart           LEDS OFF
    Wait For Line On Uart           LEDS ON

Should Get Correct Temperature Readouts From ICP10101
    Prepare Machine With IIC Sensors  ${AWS_SCI_ICP10101_ELF}
    Prepare SEGGER_RTT

    Start Emulation
    Wait For Line On Uart           Renesas FSP Application Project
    Wait For Line On Uart           I2C bus setup success
    Wait For Line On Uart           ICP Sensor Data
    Wait For Line On Uart           Temperature -000.000
    Wait For Line On Uart           Pressure\\s+ 29999.820  treatAsRegex=true

    Execute Command                 sysbus.sci0.barometer DefaultTemperature 13.5
    Execute Command                 sysbus.sci0.barometer DefaultPressure 40000
    Wait For Line On Uart           Temperature\\s+013.498  treatAsRegex=true
    Wait For Line On Uart           Pressure\\s+ 39999.929  treatAsRegex=true

Should Get Correct Readouts from the HS3001

    Prepare Machine With IIC Sensors  ${AWS_SCI_HS3001_ELF}
    Prepare SEGGER RTT

    # Due to rounding precision, some errors in the measured values are expected
    Wait For Line On Uart           HS3001 sensor setup success
    Wait For Line On Uart           HS3001 Sensor Data
    Wait For Line On Uart           Temperature:\\s+000.000  treatAsRegex=true
    Wait For Line On Uart           Humidity:\\s+000.000  treatAsRegex=true

    Execute Command                 sysbus.sci0.hs3001 DefaultTemperature 13.5
    Execute Command                 sysbus.sci0.hs3001 DefaultHumidity 50
    Wait For Line On Uart           Temperature:\\s+013.500  treatAsRegex=true
    Wait For Line On Uart           Humidity:\\s+050.099  treatAsRegex=true

    Execute Command                 sysbus.sci0.hs3001 DefaultTemperature -40
    Wait For Line On Uart           Temperature:\\s-039.950  treatAsRegex=true
    Wait For Line On Uart           Humidity:\\s+050.099  treatAsRegex=true

    Execute Command                 sysbus.sci0.hs3001 DefaultTemperature 125
    Execute Command                 sysbus.sci0.hs3001 DefaultHumidity 100
    Wait For Line On Uart           Temperature:\\s+125.000  treatAsRegex=true
    Wait For Line On Uart           Humidity:\\s+100.000  treatAsRegex=true

Should Read From The ZMOD4510 Sensor
    Prepare Machine With IIC Sensors           ${AWS_ZMOD4510_ELF}
    Prepare SEGGER_RTT

    Wait For Line On Uart           ZMOD4510 sensor setup success
    # Sensor readouts depend on the "InitConfigurationRValue", "Rvalue" and "Configuration".
    # This test uses the default values, but it can be set using those properties
    # As the algorithm for calculating the final result is proprietary, we expose a way of providing the complete RField input vector
    Wait For Line On Uart           OAQ: 231.935
    Wait For Line On Uart           OAQ: 099.132

Should Read From The ZMOD4410 Sensor
    Prepare Machine With IIC Sensors           ${AWS_ZMOD4410_ELF}
    Prepare SEGGER_RTT

    Wait For Line On Uart         ZMOD4410 sensor setup success
    # Sensor readouts depend on the "InitConfigurationRValue", "Rvalue" , "ProductionData" and "Configuration".
    # This test uses the default values, but it can be set using those properties
    # As the algorithm for calculating the final result is proprietary, we expose a way of providing the complete RField input vector
    Wait For Line On Uart         TVOC: 000.014
    Wait For Line On Uart         ETOH: 000.007
    Wait For Line On Uart         ECO2: 401.176
    # Readouts should soon stabilize
    Wait For Line On Uart         TVOC: 000.015
    Wait For Line On Uart         ETOH: 000.008
    Wait For Line On Uart         ECO2: 404.523
