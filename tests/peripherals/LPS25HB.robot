*** Variables ***
${PLATFORM}                         platforms/boards/nucleo_h753zi.repl
${BIN}                              @https://dl.antmicro.com/projects/renode/nucleo_h753zi--zephyr-samples_sensor_pressure_polling.elf-s_794076-b36b2685743abaf24da564d8fc5152ae2dcbb344
${UART}                             sysbus.usart3
${SENSOR}                           sysbus.i2c1.lps25hb
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/LPS25HB-samples.csv

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString "lps25hb: Sensors.LPS25HB @ i2c1 0x5D"
    Execute Command                 sysbus LoadELF @${BIN}
    Execute Command                 cpu EnableZephyrMode
    Create Terminal Tester          ${UART}

Set Environment
    [Arguments]                     ${temperature}=0.00  ${pressure}=1013.25
    Execute Command                 ${SENSOR} Temperature ${temperature}
    Execute Command                 ${SENSOR} Pressure ${pressure}

Check Environment
    [Arguments]                     ${temperature}=0.74  ${pressure}=1013.25
    ${pressure}=                    Evaluate  "{:.6f}".format(float(${pressure})/10.0)  # hPa to kPa conversion
    Wait For Line On Uart           .* temp ${temperature} Cel, pressure ${pressure} kPa, .*  treatAsRegex=true  timeout=0.1

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "temperature:temp::0"
    ...                             "--map", "pressure:pressure::0"
    ...                             "--start-time", "70000000"  # The binary starts polling the sensor around 70ms mark
    ...                             "--frequency", "25"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

Read Registers
    [Arguments]                     ${address}  ${count}=1
    Execute Command                 allowPrivates true
    Execute Command                 ${SENSOR} currentAddress ${address}
    Execute Command                 ${SENSOR} autoIncrement true

    ${read_script}=                 Catenate  SEPARATOR=\n
    ...                             import sys
    ...                             sensor = self.Machine["${SENSOR}"]
    ...                             data = sensor.Read(${count})
    ...                             sys.stdout.write("[" + ", ".join("0x%02X" % b for b in data) + "]")
    ${value}=                       Execute Command  python """${read_script}"""

    Execute Command                 ${SENSOR} FinishTransmission
    RETURN                          ${value}

*** Test Cases ***
Should Read Temperature And Pressure
    Create Machine

    # Due the finite precision of the sensor, and a overflow in Zephyr implementation,
    # we don't always expect the exact same values as the ones that where set

    Wait For Line On Uart           .* Booting Zephyr OS build .*  treatAsRegex=true

    # Initial register values
    Check Environment               temperature=42.50  pressure=0

    Set Environment                 temperature=100.0
    Check Environment               temperature=100.31

    Set Environment                 pressure=1013.25
    Check Environment               pressure=1013.25

    Set Environment                 temperature=-10.0
    Check Environment               temperature=-9.31

    Set Environment                 pressure=1000
    # Sensor should reject the values as they are outside of supported range
    Set Environment                 pressure=200
    Check Environment               pressure=1000

    Set Environment                 pressure=1300
    Check Environment               pressure=1000

    Set Environment                 temperature=100

    Set Environment                 temperature=-200
    Check Environment               temperature=100.31

    Set Environment                 temperature=200
    Check Environment               temperature=100.31

Should Correctly Calculate Pressure
    Create Machine

    ${expected_pressure}=           Set Variable  1023.346923828125
    Execute Command                 ${SENSOR} Pressure ${expected_pressure}
    ${pressure_getter}=             Execute Command  ${SENSOR} Pressure
    Should Be Equal As Numbers      ${pressure_getter}  ${expected_pressure}

    # Values taken from LPS25HB datasheet, figure 5
    ${pressure_bytes}=              Read Registers  0x28  3
    Should Be Equal As Strings      ${pressure_bytes}  [0x8D, 0xF5, 0x3F]

Should Read Samples From RESD
    Create Machine

    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}

    # Explicitly set temperature and pressure before loading RESD.
    # Sensor will default to these values after RESD stream ends.
    Set Environment                 temperature=42.50  pressure=1013.25

    Wait For Line On Uart           .* Booting Zephyr OS build .*  treatAsRegex=true

    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${resd_path}
    Execute Command                 ${SENSOR} FeedPressureSamplesFromRESD @${resd_path}

    Check Environment               temperature=25.90  pressure=1013.25
    Check Environment               temperature=100.31  pressure=300.00
    Check Environment               temperature=-9.31  pressure=400.00

    # Sensor should go back to set values after the RESD file finishes
    Check Environment               temperature=42.50  pressure=1013.25
    Check Environment               temperature=42.50  pressure=1013.25
