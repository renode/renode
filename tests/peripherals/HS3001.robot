*** Variables ***
${PLATFROM}                         platforms/cpus/stm32f4.repl
${BIN}                              https://dl.antmicro.com/projects/renode/nucleo_f401re--zephyr-dht_polling.elf-s_651648-b107cceed1ebc23c894d983a6e519a6e494aee88
${UART}                             sysbus.usart2
${SENSOR}                           sysbus.i2c1.hs3001
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/HS3001-samples.csv

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFROM}
    Execute Command                 machine LoadPlatformDescriptionFromString "hs3001: Sensors.HS3001 @ i2c1 0x44"
    Execute Command                 sysbus LoadELF @${BIN}
    Create Terminal Tester          ${UART}

Set Enviroment
    [Arguments]                     ${temperature}=0.00  ${humidity}=0.00
    Execute Command                 ${SENSOR} Temperature ${temperature}
    Execute Command                 ${SENSOR} Humidity ${humidity}

Check Enviroment
    [Arguments]                     ${temperature}=0.00  ${humidity}=0.00
    # The '\xc2\xb0' escape sequence is the unicode character: '°'
    Wait For Line On Uart           temp is ${temperature} \xc2\xb0C humidity is ${humidity} %RH

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "temperature:temp::0"
    ...                             "--map", "humidity:humidity::0"
    ...                             "--start-time", "0"
    ...                             "--frequency", "1"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***
Should Read Temperature And Humidity
    Create Machine

    # Due the finite precision of the sensor we don't allways expect the exact same
    # values as the ones that where set

    Check Enviroment                temperature=0.00  humidity=0.00

    Set Enviroment                  temperature=25.00
    Check Enviroment                temperature=25.01

    Set Enviroment                  humidity=50.00
    Check Enviroment                humidity=50.10

    Set Enviroment                  temperature=12.32  humidity=33.71
    Check Enviroment                temperature=12.33  humidity=33.71

    Set Enviroment                  temperature=-16.67  humidity=92.01
    Check Enviroment                temperature=-16.-66  humidity=92.04

    Set Enviroment                  temperature=88.02  humidity=8.50
    Check Enviroment                temperature=88.08  humidity=8.50

Should Read Samples From RESD
    Create Machine

    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}
    # Explicitly set temperature and humidity before loading RESD.
    # Sensor will default to these values after RESD stream ends.
    Set Enviroment                  temperature=25.56  humidity=30.39
    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${resd_path}
    Execute Command                 ${SENSOR} FeedHumiditySamplesFromRESD @${resd_path}

    Check Enviroment                temperature=-9.-99  humidity=0.00
    Check Enviroment                temperature=0.00  humidity=20.00
    Check Enviroment                temperature=4.99  humidity=40.05
    Check Enviroment                temperature=10.00  humidity=60.01
    Check Enviroment                temperature=15.00  humidity=80.31
    # Sensor should go back to the default values after the RESD file finishes
    Check Enviroment                temperature=25.56  humidity=30.39
    Check Enviroment                temperature=25.56  humidity=30.39
