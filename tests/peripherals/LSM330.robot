*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

${LSM330}=     SEPARATOR=
...  """                                                 ${\n}
...  using "platforms/cpus/nrf52840.repl"                ${\n}
...                                                      ${\n}
...  lsm330_a: Sensors.LSM330_Accelerometer @ twi0 0x1d  ${\n}
...                                                      ${\n}
...  lsm330_g: Sensors.LSM330_Gyroscope @ twi0 0x6a      ${\n}
...  """

*** Keywords ***
Create Machine
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString ${LSM330}

    Execute Command          sysbus LoadELF ${URI}/nano33ble--LSM330.arduino.mbed.elf-s_3002380-fb992eb29148d2cf83ff43b1255024364f1e3d79

*** Test Cases ***
Should Read Acceleration
    Create Machine
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.twi0.lsm330_a AccelerationX 1
    Execute Command           sysbus.twi0.lsm330_a AccelerationY -1
    Execute Command           sysbus.twi0.lsm330_a AccelerationZ 2

    Start Emulation

    # those are raw values read from sensor's registers 
    # (this is how the original Arduino sample works)
    Wait For Line On Uart     Acceleration in X-Axis : 16383
    Wait For Line On Uart     Acceleration in Y-Axis : 49153
    Wait For Line On Uart     Acceleration in Z-Axis : 32766

Should Read Rotation
    Create Machine
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.twi0.lsm330_g AngularRateX 100 
    Execute Command           sysbus.twi0.lsm330_g AngularRateY -100 
    Execute Command           sysbus.twi0.lsm330_g AngularRateZ 250

    Start Emulation

    # those are raw values read from sensor's registers 
    # (this is how the original Arduino sample works)
    Wait For Line On Uart     X-Axis of Rotation :1300
    Wait For Line On Uart     Y-Axis of Rotation :52536
    Wait For Line On Uart     Z-Axis of Rotation :32500

