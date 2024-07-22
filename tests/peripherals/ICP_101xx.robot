*** Variables ***
${SCRIPT}                           scripts/single-node/zedboard.resc
${BIN}                              https://dl.antmicro.com/projects/renode/zynq-interface-tests-icp10101-vmlinux-s_14145184-faf7b152d8913a54efee567c701b4f8a494d72ea
${DTB}                              https://dl.antmicro.com/projects/renode/zynq-linux-icp10101.dtb-s_11796-15666b09e3900565b3c5c31bbf08f8b2ecab1e93
${UART}                             sysbus.uart0
${SENSOR}                           sysbus.i2c0.barometer
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/ICP_101xx-samples.csv
${PROMPT}                           \#${SPACE}

*** Keywords ***
Create Machine
    Execute Command                 set bin @${BIN}
    Execute Command                 set dtb @${DTB}
    Execute Command                 include @${SCRIPT}

    Execute Command                 machine LoadPlatformDescriptionFromString "barometer: Sensors.ICP_101xx @ i2c0 0x50"

    # Wait for Linux to boot up
    Create Terminal Tester          ${UART}           defaultPauseEmulation=True
    Wait For Prompt On Uart         buildroot login:  timeout=25
    Write Line To Uart              root
    Wait For Prompt On Uart         ${PROMPT}

Set Enviroment
    [Arguments]                     ${temperature}  ${pressure}
    Execute Command                 ${SENSOR} DefaultTemperature ${temperature}
    Execute Command                 ${SENSOR} DefaultPressure ${pressure}

Check Enviroment
    # temperature read is in miliCelsius, pressure in kiloPascals
    [Arguments]                     ${temperature}  ${pressure}
    Write Line To Uart              cd /sys/bus/i2c/devices/0-0050/iio:device1/
    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              echo "`cat in_temp_offset` + `cat in_temp_raw` * `cat in_temp_scale`" | bc

    Wait For Line On Uart           ${temperature}

    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              cat in_pressure_input

    Wait For Line On Uart           ${pressure}

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "temperature:temp::0"
    ...                             "--map", "pressure:pres::0"
    # Offset since Linux manages to boot-up and display the first measurement, minus 0.03 second, to be sure the change will be seen
    # Note that for different Linux build, this time might be different, and the tests will fail
    ...                             "--start-time", "5_290_000_000"
    ...                             "--frequency", "10"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***

Should Boot And Login
    Create Machine

    Provides                        booted-linux

Should Read Temperature And Pressure
    Requires                        booted-linux

    # The values set and received from the sensor will not match 1:1, 
    # since the sensor has finite precision, but they fit within sensor's accuracy range

    Check Enviroment                temperature=-.306624  pressure=29.999993

    Set Enviroment                  temperature=25.00            pressure=30000
    Check Enviroment                temperature=24998.929632     pressure=29.999998

    Set Enviroment                  temperature=25.00            pressure=68219
    Check Enviroment                temperature=24998.929632     pressure=68.218994

    Set Enviroment                  temperature=37.82            pressure=101237
    Check Enviroment                temperature=37818.982320     pressure=101.236999

Should Read Temperature And Pressure From RESD
    Requires                        booted-linux
    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}

    Execute Command                 ${SENSOR} FeedTemperatureSamplesFromRESD @${resd_path}
    Execute Command                 ${SENSOR} FeedPressureSamplesFromRESD @${resd_path}

    # Pressure will fluctuate a bit, since its calculation depends on the temperature
    # these are very much dependent on a specific software build, because the samples need to be fed and read-out at strict intervals
    # if the soft changes, frequency and start-time in RESD might need to change as well
    Check Enviroment                temperature=-21002.121744    pressure=29.999976
    Check Enviroment                temperature=-.306624         pressure=29.999993
    Check Enviroment                temperature=4998.472512      pressure=52.911995
    Check Enviroment                temperature=9999.921936      pressure=101.450998
    Check Enviroment                temperature=54999.615312     pressure=72.520999
