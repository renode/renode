*** Variables ***
${PLATFORM}                         platforms/boards/nucleo_h753zi.repl
${BIN}                              https://dl.antmicro.com/projects/renode/nucleo_h753zi--zephyr-ina228.elf-s_759988-169383ab8780027b435f6d7ed4289188247949da
${UART}                             sysbus.usart3
${SENSOR}                           sysbus.i2c1.ina228
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/INA228-samples.csv

*** Keywords ***
Should Be Equal Within Tolerance
    [Arguments]                     ${value0}  ${value1}  ${tolerance}
    ${diff}=                        Evaluate  abs(${value0} - ${value1})
    Should Be True                  ${diff} <= ${tolerance}

Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString "ina228: Sensors.INA228 @ i2c1 0x40"
    Execute Command                 showAnalyzer sysbus.usart3
    Execute Command                 sysbus LoadELF @${BIN}
    Create Terminal Tester          ${UART}

Check Environment
    [Arguments]                     ${shuntvoltage}  ${busvoltage}  ${temperature}  ${current}  ${power}  ${energy}  ${charge}

    ${ina228_line_pattern}=         Catenate
    ...                             Shunt: (-?\\d+\\.\\d+) \\[V\\] --
    ...                             Bus: (-?\\d+\\.\\d+) \\[V\\] --
    ...                             Current: (-?\\d+\\.\\d+) \\[A\\] --
    ...                             Power: (-?\\d+\\.\\d+) \\[W\\] --
    ...                             Temp: (-?\\d+\\.\\d+) \\[C\\] --
    ...                             Energy: (-?\\d+\\.\\d+) \\[J\\] --
    ...                             Charge: (-?\\d+\\.\\d+) \\[C\\]
    ${result}=                      Wait For Line On Uart  ${ina228_line_pattern}  treatAsRegex=true  timeout=3

    ${actual_shuntvoltage}=         Set Variable  ${result.Groups[0]}
    ${actual_busvoltage}=           Set Variable  ${result.Groups[1]}
    ${actual_current}=              Set Variable  ${result.Groups[2]}
    ${actual_power}=                Set Variable  ${result.Groups[3]}
    ${actual_temperature}=          Set Variable  ${result.Groups[4]}
    ${actual_energy}=               Set Variable  ${result.Groups[5]}
    ${actual_charge}=               Set Variable  ${result.Groups[6]}

    Should Be Equal Within Tolerance  ${shuntvoltage}  ${actual_shuntvoltage}  tolerance=0.01
    Should Be Equal Within Tolerance  ${busvoltage}  ${actual_busvoltage}  tolerance=0.1
    Should Be Equal Within Tolerance  ${current}  ${actual_current}  tolerance=0.1
    Should Be Equal Within Tolerance  ${power}  ${actual_power}  tolerance=1.0
    Should Be Equal Within Tolerance  ${temperature}  ${actual_temperature}  tolerance=0.1
    Should Be Equal Within Tolerance  ${energy}  ${actual_energy}  tolerance=10.0
    Should Be Equal Within Tolerance  ${charge}  ${actual_charge}  tolerance=0.1

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "voltage:shuntvoltage::0"
    ...                             "--map", "voltage:busvoltage::1"
    ...                             "--map", "temperature:temperature::0"
    ...                             "--start-time", "1000000000"
    ...                             "--frequency", "0.5"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

Create Timestamped RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "voltage:shuntvoltage::0"
    ...                             "--map", "voltage:busvoltage::1"
    ...                             "--map", "temperature:temperature::0"
    ...                             "--timestamp", "timestamp"
    ...                             "--start-time", "1000000000"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***
Should Read Samples From RESD
    Create Machine

    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}

    Wait For Line On Uart           .* Booting Zephyr OS build .*  treatAsRegex=true
    Check Environment               shuntvoltage=0.00  busvoltage=0.00  temperature=0.00  current=0.00  power=0.00  energy=0.00  charge=0.00

    Execute Command                 ${SENSOR} FeedShuntVoltageSamplesFromRESD @${resd_path} 0
    Execute Command                 ${SENSOR} FeedBusVoltageSamplesFromRESD @${resd_path} 1
    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${resd_path}

    Check Environment               shuntvoltage=0.097  busvoltage=48.00  temperature=25.00  current=6.00  power=288.17  energy=288.29  charge=6.01
    Check Environment               shuntvoltage=0.048  busvoltage=52.00  temperature=-10.00  current=3.00  power=156.09  energy=444.27  charge=9.00
    Check Environment               shuntvoltage=0.016  busvoltage=44.00  temperature=85.00  current=1.00  power=44.29  energy=200.00  charge=4.00

Should Read Samples From Timestamped RESD
    Create Machine

    ${resd_path}=                   Create Timestamped RESD File  ${SAMPLES_CSV}

    Wait For Line On Uart           .* Booting Zephyr OS build .*  treatAsRegex=true
    Check Environment               shuntvoltage=0.00  busvoltage=0.00  temperature=0.00  current=0.00  power=0.00  energy=0.00  charge=0.00

    Execute Command                 ${SENSOR} FeedShuntVoltageSamplesFromRESD @${resd_path} 0
    Execute Command                 ${SENSOR} FeedBusVoltageSamplesFromRESD @${resd_path} 1
    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${resd_path}

    Check Environment               shuntvoltage=0.097  busvoltage=48.00  temperature=25.00  current=6.00  power=288.17  energy=288.29  charge=6.01
    Check Environment               shuntvoltage=0.048  busvoltage=52.00  temperature=-10.00  current=3.00  power=156.09  energy=444.27  charge=9.00
    Check Environment               shuntvoltage=0.016  busvoltage=44.00  temperature=85.00  current=1.00  power=44.29  energy=200.00  charge=4.00
