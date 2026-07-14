*** Variables ***
${PLATFORM}                         platforms/boards/nucleo_h753zi.repl
${BIN}                              https://dl.antmicro.com/projects/renode/nucleo_h753zi--zephyr-samples_sensor_lsm6dso.elf-s_828372-b3da65fa9bf47012ff9f7b9206b2e73b392ca795
${UART}                             sysbus.usart3
${SENSOR}                           sysbus.i2c1.lsm6dso
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/LSM6DSO-samples.csv

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}
    Execute Command                 machine LoadPlatformDescriptionFromString "lsm6dso: Sensors.LSM6DSO_IMU @ i2c1 0x6A"
    Execute Command                 sysbus LoadELF @${BIN}
    Execute Command                 cpu EnableZephyrMode
    Create Terminal Tester          ${UART}

Feed Acceleration
    [Arguments]                     ${x}  ${y}  ${z}
    Execute Command                 ${SENSOR} FeedAccelerationSample ${x} ${y} ${z}

Feed Angular Rate
    [Arguments]                     ${x}  ${y}  ${z}
    Execute Command                 ${SENSOR} FeedAngularRateSample ${x} ${y} ${z}

Wait For Acceleration Line
    [Arguments]                     ${x}=0  ${y}=0  ${z}=0
    ${x}=                           Evaluate  "{:.6f}".format(float(${x}))
    ${y}=                           Evaluate  "{:.6f}".format(float(${y}))
    ${z}=                           Evaluate  "{:.6f}".format(float(${z}))

    Wait For Line On Uart           accel x:${x} ms/2 y:${y} ms/2 z:${z} ms/2  treatAsRegex=true  timeout=2

Wait For Angular Rate Line
    [Arguments]                     ${x}=0  ${y}=0  ${z}=0
    ${x}=                           Evaluate  "{:.6f}".format(float(${x}))
    ${y}=                           Evaluate  "{:.6f}".format(float(${y}))
    ${z}=                           Evaluate  "{:.6f}".format(float(${z}))

    Wait For Line On Uart           gyro x:${x} rad/s y:${y} rad/s z:${z} rad/s  treatAsRegex=true  timeout=2

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "angular_rate:gyro_x,gyro_y,gyro_z:x,y,z"
    ...                             "--map", "acceleration:accel_x,accel_y,accel_z:x,y,z"
    ...                             "--start-time", "100000000"  # The binary starts polling the sensor around 70ms mark
    ...                             "--frequency", "12"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***
Should Read Acceleration and Gyroscope Via I2C
    Create Machine

    Wait For Line On Uart           .* Booting Zephyr OS build .*  treatAsRegex=true

    # Initial register values
    Wait For Acceleration Line      x=0  y=0  z=0
    Wait For Angular Rate Line      x=0  y=0  z=0

    Feed Acceleration               1  -1  0
    Wait For Acceleration Line      9.801001  -9.801001  0

    Feed Angular Rate               100  200  300
    Wait For Angular Rate Line      1.745852  3.490483  5.236335

Should Read Samples From RESD
    Create Machine
    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}

    Wait For Line On Uart           .* Booting Zephyr OS build .*  treatAsRegex=true

    Wait For Acceleration Line      x=0  y=0  z=0
    Wait For Angular Rate Line      x=0  y=0  z=0

    Execute Command                 ${SENSOR} FeedAccelerationSamplesFromRESD @${resd_path}
    Execute Command                 ${SENSOR} FeedAngularRateSamplesFromRESD @${resd_path}

    Wait For Acceleration Line      9.801001  19.601404  4.900500
    Wait For Angular Rate Line      5.000541  9.999861  5.000541

    Wait For Acceleration Line      14.701502  14.701502  4.900500
    Wait For Angular Rate Line      9.999861  5.000541  15.000403

    Wait For Acceleration Line      19.601404  9.801001  4.900500
    Wait For Angular Rate Line      1.500284  15.000403  9.999861

    # After stream finishes, peripheral should fall back to default values
    Wait For Acceleration Line      0  0  0
    Wait For Angular Rate Line      0  0  0
