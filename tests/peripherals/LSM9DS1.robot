*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

${LSM9DS1}=     SEPARATOR=
...  """                                                 ${\n}
...  using "platforms/cpus/nrf52840.repl"                ${\n}
...                                                      ${\n}
...  lsm9ds1_imu: Sensors.LSM9DS1_IMU @ twi0 0x6b        ${\n}
...                                                      ${\n}
...  lsm9ds1_mag: Sensors.LSM9DS1_Magnetic @ twi0 0x1e   ${\n}
...  """

*** Keywords ***
Create Machine
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString ${LSM9DS1}

    Execute Command          sysbus LoadELF ${URI}/arduino_nano_33_ble--tf_magic_wand.elf-s_7482772-5722cd8b1dd7b040366cbc259f5175b62aa4496c

*** Test Cases ***
Should Detect RING Motion
    Create Machine
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.twi0.lsm9ds1_imu FeedAccelerationSample @${CURDIR}/circle_rotated.data

    Start Emulation
    Wait For Line On Uart     Magic starts
    Wait For Line On Uart     RING:

Should Detect SLOPE Motion
    Create Machine
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.twi0.lsm9ds1_imu FeedAccelerationSample @${CURDIR}/angle_rotated.data

    Start Emulation
    Wait For Line On Uart     Magic starts
    Wait For Line On Uart     SLOPE:


