*** Variables ***
${PLATFORM}                         platforms/cpus/stm32f4.repl
${BIN}                              https://dl.antmicro.com/projects/renode/nucleo_f401re--zephyr-dht_polling.elf-s_651648-b107cceed1ebc23c894d983a6e519a6e494aee88
${UART}                             sysbus.usart2
${SENSOR}                           sysbus.i2c1.hs3001
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${RENODETOOLS}/../tests/peripherals/HS3001-samples.csv

*** Keywords ***
Create Machine
    Execute Command                 include @${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString "hs3001: Sensors.HS3001 @ i2c1 0x44"
    Execute Command                 sysbus LoadELF @${BIN}
    Create Terminal Tester          ${UART}

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "temperature:temp"
    ...                             "--map", "humidity:humidity"
    ...                             "--start-time", "0"
    ...                             "--frequency", "1"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

Set Environment
    [Arguments]                     ${temperature}=0.00  ${humidity}=0.00
    Execute Command                 ${SENSOR} Temperature ${temperature}
    Execute Command                 ${SENSOR} Humidity ${humidity}

Check Environment
    [Arguments]                     ${temperature}=0.00  ${humidity}=0.00
    # The '\xc2\xb0' escape sequence is the unicode character: '°'
    Wait For Line On Uart           temp is ${temperature} \xc2\xb0C humidity is ${humidity} %RH

*** Test Cases ***
Should Save/Load RESD Without Starting
    Create Machine

    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}
    ${temp_save}=                   Allocate Temporary File

    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${resd_path}
    Execute Command                 ${SENSOR} FeedHumiditySamplesFromRESD @${resd_path}

    Execute Command                 Save @${temp_save}
    Execute Command                 Load @${temp_save}

Should Save RESD While Streaming
    Create Machine

    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}

    Set Environment                 temperature=25.56  humidity=30.39

    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${resd_path}
    Execute Command                 ${SENSOR} FeedHumiditySamplesFromRESD @${resd_path}

    Check Environment               temperature=-9.-99  humidity=0.00
    Check Environment               temperature=0.00  humidity=20.00
    Check Environment               temperature=4.99  humidity=40.05

    Provides                        saved-while-streaming

Should Load RESD While Streaming
    Requires                        saved-while-streaming
    Create Terminal Tester          ${UART}

    Check Environment               temperature=10.00  humidity=60.01
    Check Environment               temperature=15.00  humidity=80.31
    # Sensor should go back to the default values after the RESD file finishes
    Check Environment               temperature=25.56  humidity=30.39

Should Save/Load RESD After Streamed
    Create Machine

    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}
    ${temp_save}=                   Allocate Temporary File

    Set Environment                 temperature=25.56  humidity=30.39

    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${resd_path}
    Execute Command                 ${SENSOR} FeedHumiditySamplesFromRESD @${resd_path}

    Check Environment               temperature=-9.-99  humidity=0.00
    Check Environment               temperature=0.00  humidity=20.00
    Check Environment               temperature=4.99  humidity=40.05
    Check Environment               temperature=10.00  humidity=60.01
    Check Environment               temperature=15.00  humidity=80.31
    # Sensor should go back to the default values after the RESD file finishes
    Check Environment               temperature=25.56  humidity=30.39

    Execute Command                 Save @${temp_save}
    Execute Command                 Load @${temp_save}
    Create Terminal Tester          ${UART}

    Check Environment               temperature=25.56  humidity=30.39
