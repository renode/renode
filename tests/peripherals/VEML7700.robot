*** Variables ***
${PLATFORM}                         platforms/boards/nucleo_h753zi.repl
${BIN}                              https://dl.antmicro.com/projects/renode/nucleo_h753zi--zephyr-samples_sensor_light_polling.elf-s_599280-f102efd2fb21d8f68de76386291728850712f935
${UART}                             sysbus.usart3
${SENSOR}                           sysbus.i2c1.als
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/veml7700-samples.csv

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString "als: Sensors.VEML7700 @ i2c1 0x10"
    Execute Command                 sysbus LoadELF @${BIN}
    Create Terminal Tester          ${UART}

Set Enviroment
    [Arguments]                     ${illuminance}
    Execute Command                 ${SENSOR} Illuminance ${illuminance}

Check Enviroment
    [Arguments]                     ${illuminance}
    Wait For Line On Uart           lux: ${illuminance}

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "illuminance:illuminance::0"
    ...                             "--start-time", "0"
    ...                             "--frequency", "1"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

Create Timestamped RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "illuminance:illuminance::0"
    ...                             "--start-time", "0"
    ...                             "--timestamp", "timestamp"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***
Should Read Illuminance
    Create Machine

    Check Enviroment                illuminance=0

    # The closest VEML7700 illuminance value for any lux value is usually slightly under the true value,
    # and Zephyr rounds down to the nearest lux
    Set Enviroment                  illuminance=500
    Check Enviroment                illuminance=499

    Set Enviroment                  illuminance=30
    Check Enviroment                illuminance=29

    Set Enviroment                  illuminance=10000.5
    Check Enviroment                illuminance=10000

Should Read Samples From RESD
    Create Machine

    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}
    Execute Command                 ${SENSOR} FeedIlluminanceSamplesFromRESD @${resd_path}

    Check Enviroment                0
    Check Enviroment                499
    Check Enviroment                12000
    Check Enviroment                12000

Should Read Samples From Timestamped RESD
    Create Machine

    ${resd_path}=                   Create Timestamped RESD File  ${SAMPLES_CSV}
    Execute Command                 ${SENSOR} FeedIlluminanceSamplesFromRESD @${resd_path}

    Check Enviroment                0
    Check Enviroment                499
    Check Enviroment                12000
    Check Enviroment                12000
