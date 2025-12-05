*** Settings ***
Library                             ${CURDIR}/gdb_library.py

*** Variables ***
${PLATFORM}                         platforms/cpus/stm32f4.repl
${BIN_URL}                          https://dl.antmicro.com/projects/renode/nucleo_f401re--zephyr-dht_polling.elf-s_651648-b107cceed1ebc23c894d983a6e519a6e494aee88
${UART}                             sysbus.usart2
${SENSOR}                           sysbus.i2c1.hs3001
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/../../peripherals/HS3001-samples.csv
${GDB_REMOTE_PORT}                  3340

*** Keywords ***
Download Bin File
    ${x}=                           Download File  ${BIN_URL}
    RETURN                          ${x}

Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString "hs3001: Sensors.HS3001 @ i2c1 0x44"
    Execute Command                 sysbus LoadELF @${BIN_URL}
    # Execute Command                 logLevel -1 ${SENSOR}
    Create Terminal Tester          ${UART}
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Check And Run Gdb
    [Arguments]                     ${name}  ${bin}
    ${res}=                         Start Gdb  ${name}
    Run Keyword If                  '${res}' != 'OK'
    ...                             Fail  ${name} not found  skipped

    Command Gdb                     target remote :${GDB_REMOTE_PORT}  timeout=10
    Command Gdb                     file ${bin}

Set Enviroment
    [Arguments]                     ${temperature}=0.00  ${humidity}=0.00
    Execute Command                 ${SENSOR} Temperature ${temperature}
    Execute Command                 ${SENSOR} Humidity ${humidity}

Check Enviroment
    [Arguments]                     ${temperature}=0.00  ${humidity}=0.00
    # The '\xc2\xb0' escape sequence is the unicode character: '°'
    Command Gdb                     continue
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
Should Read Samples From RESD
    ${bin}=                         Download Bin File
    ${RESD}=                        Create RESD File  ${SAMPLES_CSV}
    Create Machine
    Execute Command                 reverseExecMode true
    Execute Command                 autoSave true 1.0

    # Explicitly set temperature and humidity before loading RESD.
    # Sensor will default to these values after RESD stream ends.
    Set Enviroment                  temperature=25.56  humidity=30.39
    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${RESD}
    Execute Command                 ${SENSOR} FeedHumiditySamplesFromRESD @${RESD}
    Execute Command                 showAnalyzer ${UART}
    Check And Run Gdb               name=arm-none-eabi-gdb  bin=${bin}

    Command Gdb                     break printk

    # Start
    Command Gdb                     continue

    Command Gdb                     continue
    Wait For Line On Uart           *** Booting Zephyr OS build zephyr-v3.5.0-3142-gaf0336ed1922 ***

    Check Enviroment                temperature=-9.-99  humidity=0.00
    Check Enviroment                temperature=0.00  humidity=20.00
    Check Enviroment                temperature=4.99  humidity=40.05

    Command Gdb                     reverse-continue 2
    Create Terminal Tester          ${UART}
    Check Enviroment                temperature=0.00  humidity=20.00
    Check Enviroment                temperature=4.99  humidity=40.05

    Check Enviroment                temperature=10.00  humidity=60.01
    Check Enviroment                temperature=15.00  humidity=80.31
    # There is a bug in RESD implementation which makes the last sample appear twice
    Check Enviroment                temperature=15.00  humidity=80.31

    # Sensor should go back to the default values after the RESD file finishes
    Check Enviroment                temperature=25.56  humidity=30.39
    Check Enviroment                temperature=25.56  humidity=30.39
