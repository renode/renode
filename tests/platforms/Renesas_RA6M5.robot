*** Variables ***
${URL}                              https://dl.antmicro.com/projects/renode
${AGT_ELF}                          ${URL}/renesas_ra6m5--agt.elf-s_303444-613fbe7bc11ecbc13afa7a8a907682bbbb2a3458
${HELLO_WORLD_ELF}                  ${URL}/ra6m5-hello_world.elf-s_310112-5e896556c868826bc8d25d695202ebe0beed7df2
${AWS_SCI_ICP10101_ELF}             ${URL}/renesas_ra6m5--aws-icp10101.elf-s_795916-3d68631f0fdfc3838fdba768d3a6d46312707ae3
${AWS_SCI_HS3001_ELF}               ${URL}/renesas_ra6m5--aws-hs3001.elf-s_758320-642c83fb428d4ccc1e35c2908178de232744dbad
${AWS_ZMOD4510_ELF}                 ${URL}/renesas_ra6m5--aws-zmod4510.elf-s_807176-4b4d580be7d9876f822205349432d3ea68172a17
${AWS_ZMOD4410_ELF}                 ${URL}/renesas_ra6m5--aws-zmod4410.elf-s_808224-8d79f1a1ff242d00131c12298f64420df21bc1d3
${SCI_SPI_ELF}                      ${URL}/renesas_ra6m5--sci_spi.elf-s_346192-72cd95f5c506423a29f654be7fb7471b3b230ed0
${AWS_ICM20948_ELF}                 ${URL}/renesas_ra6m5--aws-icm20948.elf-s_799636-492407caeb09cadd9b5bab867955ce9dc6d7229e
# SCI_UART demo is slightly modified version with additional printfs for better testability
${SCI_UART_ELF}                     ${URL}/renesas_ra6m5--sci_uart.elf-s_413420-158250896f48de6bf28e409c99cdda0b2b21e43e
${IIC_MASTER_ELF}                   ${URL}/renesas_ra6m5--iic_master.elf-s_322744-232a1bea524059a7170c97c7fa698c5efff39f03
${AWS_CC_ELF}                       ${URL}/renesas_ra6m5--aws.elf-s_1022068-eb223bcbec23d091f52980a36dea325060d046f7

${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${ICM20948_SAMPLES_CSV}             ${CURDIR}/ICM20948-samples.csv

${RA6M5_REPL}                       platforms/cpus/renesas-r7fa6m5b.repl
${CK_BOARD_REPL}                    platforms/boards/renesas-ck_ra6m5.repl
${CK_SCI_SENSORS_BOARD_REPL}        @tests/platforms/renesas-ck_ra6m5-sensors_example.repl

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

    Execute Command                 set bin @${bin}
    Execute Command                 macro reset "sysbus LoadELF $bin"
    Execute Command                 runMacro $reset

Prepare Machine
    [Arguments]                     ${bin}
    Create Machine                  ${bin}  ${RA6M5_REPL}

Prepare Machine With SCI Sensors Board
    [Arguments]                     ${bin}
    Create Machine                  ${bin}  ${CK_SCI_SENSORS_BOARD_REPL}

Prepare Machine With CK Board
    [Arguments]                     ${bin}
    Create Machine                  ${bin}  ${CK_BOARD_REPL}

Prepare Segger RTT
    [Arguments]                     ${with_has_key}=False  ${with_read}=False
    Execute Command                 machine CreateVirtualConsole "segger_rtt"
    Execute Command                 include @scripts/single-node/renesas-segger-rtt.py
    Execute Command                 setup_segger_rtt sysbus.segger_rtt ${with_has_key} ${with_read}
    Create Terminal Tester          sysbus.segger_rtt

Prepare LED Tester
    Execute Command                 machine LoadPlatformDescriptionFromString ${LED_REPL}
    Create Led Tester               sysbus.port6.led

Prepare UART Tester
    Create Terminal Tester          sysbus.sci0

Create ICM20948 RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "angular_rate:angular_rate_x,angular_rate_y,angular_rate_z:x,y,z"
    ...                             "--map", "acceleration:acceleration_x,acceleration_y,acceleration_z:x,y,z"
    ...                             "--map", "magnetic_flux_density:magnetic_flux_density_x,magnetic_flux_density_y,magnetic_flux_density_z:x,y,z"
    ...                             "--start-time", "200000000"
    ...                             "--frequency", "5"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***
Should Run Periodically Blink LED
    Prepare Machine                 ${AGT_ELF}
    Prepare LED Tester
    Prepare Segger RTT              with_has_key=True  with_read=True

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
    Prepare Machine With SCI Sensors Board  ${AWS_SCI_ICP10101_ELF}
    Prepare SEGGER_RTT

    Start Emulation
    Wait For Line On Uart           Renesas FSP Application Project
    Wait For Line On Uart           I2C bus setup success
    Wait For Line On Uart           ICP Sensor Data
    Wait For Line On Uart           Temperature -000.000
    Wait For Line On Uart           Pressure\\s+ 29999.820  treatAsRegex=true

    Execute Command                 sysbus.sci0.barometer_sci DefaultTemperature 13.5
    Execute Command                 sysbus.sci0.barometer_sci DefaultPressure 40000
    Wait For Line On Uart           Temperature\\s+013.498  treatAsRegex=true
    Wait For Line On Uart           Pressure\\s+ 39999.929  treatAsRegex=true

Should Get Correct Readouts from the HS3001

    Prepare Machine With SCI Sensors Board  ${AWS_SCI_HS3001_ELF}
    Prepare SEGGER RTT

    # Due to rounding precision, some errors in the measured values are expected
    Wait For Line On Uart           HS3001 sensor setup success
    Wait For Line On Uart           HS3001 Sensor Data
    Wait For Line On Uart           Temperature:\\s+000.000  treatAsRegex=true
    Wait For Line On Uart           Humidity:\\s+000.000  treatAsRegex=true

    Execute Command                 sysbus.sci0.hs3001_sci Temperature 13.5
    Execute Command                 sysbus.sci0.hs3001_sci Humidity 50
    Wait For Line On Uart           Temperature:\\s+013.500  treatAsRegex=true
    Wait For Line On Uart           Humidity:\\s+050.099  treatAsRegex=true

    Execute Command                 sysbus.sci0.hs3001_sci Temperature -40
    Wait For Line On Uart           Temperature:\\s-039.950  treatAsRegex=true
    Wait For Line On Uart           Humidity:\\s+050.099  treatAsRegex=true

    Execute Command                 sysbus.sci0.hs3001_sci Temperature 125
    Execute Command                 sysbus.sci0.hs3001_sci Humidity 100
    Wait For Line On Uart           Temperature:\\s+125.000  treatAsRegex=true
    Wait For Line On Uart           Humidity:\\s+100.000  treatAsRegex=true

Should Read From The ZMOD4510 Sensor
    Prepare Machine With SCI Sensors Board           ${AWS_ZMOD4510_ELF}
    Prepare SEGGER_RTT

    Wait For Line On Uart           ZMOD4510 sensor setup success
    # Sensor readouts depend on the "InitConfigurationRValue", "Rvalue" and "Configuration".
    # This test uses the default values, but it can be set using those properties
    # As the algorithm for calculating the final result is proprietary, we expose a way of providing the complete RField input vector
    Wait For Line On Uart           OAQ: 231.935
    Wait For Line On Uart           OAQ: 099.132

Should Read From The ZMOD4410 Sensor
    Prepare Machine With SCI Sensors Board           ${AWS_ZMOD4410_ELF}
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

Should Read Temperature From SPI Sensor
    Prepare Machine                 ${SCI_SPI_ELF}
    Prepare Segger RTT

    # Sample expects the MAX31723PMB1 temperature sensor which there is no model for in Renode
    Execute Command                 machine LoadPlatformDescriptionFromString "sensor: Sensors.GenericSPISensor @ sci0"

    # Sensor initialization values
    Execute Command                 sci0.sensor FeedSample 0x80
    Execute Command                 sci0.sensor FeedSample 0x6
    Execute Command                 sci0.sensor FeedSample 0x0

    # Temperature of 15 °C
    Execute Command                 sci0.sensor FeedSample 0x0
    Execute Command                 sci0.sensor FeedSample 0xF
    Execute Command                 sci0.sensor FeedSample 0x0

    # Temperature of 10 °C
    Execute Command                 sci0.sensor FeedSample 0x0
    Execute Command                 sci0.sensor FeedSample 0xA
    Execute Command                 sci0.sensor FeedSample 0x0

    # Temperature of 2 °C
    Execute Command                 sci0.sensor FeedSample 0x0
    Execute Command                 sci0.sensor FeedSample 0x2
    Execute Command                 sci0.sensor FeedSample 0x0

    Wait For Line On Uart           Temperature:${SPACE*2}15.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}10.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}2.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}0.000000 *C

Should Read And Write On UART
    Prepare Machine                 ${SCI_UART_ELF}

    Create Terminal Tester          sysbus.sci0

    Wait For Line On Uart           Starting UART demo

    Write Line To Uart              56  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 56
    Wait For Line On Uart           Set next value

    Write Line To Uart              1  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 1
    Wait For Line On Uart           Set next value

    Write Line To Uart              100  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 100
    Wait For Line On Uart           Set next value

    Write Line To Uart              371  waitForEcho=false
    Wait For Line On Uart           Invalid input. Input range is from 1 - 100

    Write Line To Uart              74  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 74
    Wait For Line On Uart           Set next value

Should Read Default Values From ICM20948
    Prepare Machine With SCI Sensors Board  ${AWS_ICM20948_ELF}
    Prepare Segger RTT

    Execute Command                 sci0.icm_sci DefaultAccelerationX 0.3183098861837907
    Execute Command                 sci0.icm_sci DefaultAccelerationY 1.618033988749895
    Execute Command                 sci0.icm_sci DefaultAccelerationZ -0.36787944117144233

    Execute Command                 sci0.icm_sci DefaultAngularRateX 10.604
    Execute Command                 sci0.icm_sci DefaultAngularRateY 200.002
    Execute Command                 sci0.icm_sci DefaultAngularRateZ -3.1

    Execute Command                 sysbus.sci0.icm_sci.magnetometer_sci DefaultMagneticFluxDensityX 150
    Execute Command                 sysbus.sci0.icm_sci.magnetometer_sci DefaultMagneticFluxDensityY 300
    Execute Command                 sysbus.sci0.icm_sci.magnetometer_sci DefaultMagneticFluxDensityZ 450

    Wait For Line On Uart           ICM Sensor Data
    Wait For Line On Uart           AccX 000.318
    Wait For Line On Uart           AccY 001.618
    Wait For Line On Uart           AccZ -000.367

    Wait For Line On Uart           GyrX 010.597
    Wait For Line On Uart           GyrY 199.890
    Wait For Line On Uart           GyrZ -003.097

    Wait For Line On Uart           MagX 000.149
    Wait For Line On Uart           MagY 000.298
    Wait For Line On Uart           MagZ 000.448


Should Read Values From ICM20948 Fed From RESD File
    Prepare Machine With SCI Sensors Board  ${AWS_ICM20948_ELF}
    Prepare Segger RTT

    ${resd_path}=                   Create ICM20948 RESD File  ${ICM20948_SAMPLES_CSV}
    Execute Command                 sysbus.sci0.icm_sci FeedAccelerationSamplesFromRESD @${resd_path}
    Execute Command                 sysbus.sci0.icm_sci FeedAngularRateSamplesFromRESD @${resd_path}
    Execute Command                 sysbus.sci0.icm_sci.magnetometer_sci FeedMagneticSamplesFromRESD @${resd_path}

    Wait For Line On Uart           ICM Sensor Data
    Wait For Line On Uart           AccX 000.001
    Wait For Line On Uart           AccY 001.002
    Wait For Line On Uart           AccZ -004.000

    Wait For Line On Uart           GyrX 249.862
    Wait For Line On Uart           GyrY -249.862
    Wait For Line On Uart           GyrZ 003.143

    Wait For Line On Uart           MagX 000.149
    Wait For Line On Uart           MagY 000.298
    Wait For Line On Uart           MagZ 000.448

    Wait For Line On Uart           ICM Sensor Data
    Wait For Line On Uart           AccX 000.002
    Wait For Line On Uart           AccY 000.998
    Wait For Line On Uart           AccZ 003.999

    Wait For Line On Uart           GyrX 243.499
    Wait For Line On Uart           GyrY -249.549
    Wait For Line On Uart           GyrZ 003.280

    Wait For Line On Uart           MagX 000.298
    Wait For Line On Uart           MagY 000.448
    Wait For Line On Uart           MagZ 000.597

Should Communicate Over IIC
    Prepare Machine                 ${IIC_MASTER_ELF}
    Execute Command                 machine LoadPlatformDescriptionFromString "adxl345: Sensors.ADXL345 @ iic1 0x1D"
    Prepare Segger RTT

    # Sample displays raw data from the sensor, so printed values are different from loaded samples
    Execute Command                 iic1.adxl345 FeedSample 1000 1000 1000
    Wait For Line On Uart           X-axis = 250.00, Y-axis = 250.00, Z-axis = 250.00

    Execute Command                 iic1.adxl345 FeedSample 2000 3000 4000
    Wait For Line On Uart           X-axis = 500.00, Y-axis = 750.00, Z-axis = 1000.00

    Execute Command                 iic1.adxl345 FeedSample 1468 745 8921
    Wait For Line On Uart           X-axis = 367.00, Y-axis = 186.00, Z-axis = 2230.00
    
    Execute Command                 iic1.adxl345 FeedSample 3912 8888 5456
    Wait For Line On Uart           X-axis = 978.00, Y-axis = 2222.00, Z-axis = 1364.00
    
    Execute Command                 iic1.adxl345 FeedSample 0 5000 0
    Wait For Line On Uart           X-axis = 0.00, Y-axis = 1250.00, Z-axis = 0.00

    Wait For Line On Uart           X-axis = 0.00, Y-axis = 0.00, Z-axis = 0.00 

CK IIC Board Should Work
    Prepare Machine With CK Board   ${AWS_CC_ELF}
    Prepare Segger RTT

    Execute Command                 sysbus.iic0.hs3001 Temperature 13.5
    Execute Command                 sysbus.iic0.hs3001 Humidity 50

    Execute Command                 sysbus.iic0.barometer DefaultTemperature 13.5
    Execute Command                 sysbus.iic0.barometer DefaultPressure 40000

    Execute Command                 sysbus.iic0.icm DefaultAccelerationX 0.3183098861837907
    Execute Command                 sysbus.iic0.icm DefaultAccelerationY 1.618033988749895
    Execute Command                 sysbus.iic0.icm DefaultAccelerationZ -0.36787944117144233

    Execute Command                 sysbus.iic0.icm DefaultAngularRateX 10.604
    Execute Command                 sysbus.iic0.icm DefaultAngularRateY 200.002
    Execute Command                 sysbus.iic0.icm DefaultAngularRateZ -3.1

    Execute Command                 sysbus.iic0.icm.magnetometer DefaultMagneticFluxDensityX 150
    Execute Command                 sysbus.iic0.icm.magnetometer DefaultMagneticFluxDensityY 300
    Execute Command                 sysbus.iic0.icm.magnetometer DefaultMagneticFluxDensityZ 450

    Wait For Line On Uart           IAQ Sensor Data
    Wait For Line On Uart           TVOC: 000.015
    Wait For Line On Uart           ETOH: 000.008
    Wait For Line On Uart           ECO2: 404.384

    Wait For Line On Uart           OAQ Sensor Data 
    Wait For Line On Uart           OAQ: 231.935

    Wait For Line On Uart           HS3001 Sensor Data 
    Wait For Line On Uart           Humidity: 050.099
    Wait For Line On Uart           Temperature: 013.500

    Wait For Line On Uart           ICM Sensor Data
    Wait For Line On Uart           AccX 000.318
    Wait For Line On Uart           AccY 001.618
    Wait For Line On Uart           AccZ -000.367

    Wait For Line On Uart           GyrX 010.597
    Wait For Line On Uart           GyrY 199.890
    Wait For Line On Uart           GyrZ -003.097

    Wait For Line On Uart           MagX 000.149
    Wait For Line On Uart           MagY 000.298
    Wait For Line On Uart           MagZ 000.448

    Wait For Line On Uart           ICP Sensor Data
    Wait For Line On Uart           Temperature: 013.498
    Wait For Line On Uart           Pressure: 39999.929
