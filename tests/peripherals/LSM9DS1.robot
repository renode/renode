*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/arduino_nano_33_ble.repl

    Execute Command          sysbus LoadELF ${URI}/arduino_nano_33_ble--tf_magic_wand.elf-s_7482772-5722cd8b1dd7b040366cbc259f5175b62aa4496c

*** Test Cases ***
Should Detect RING Motion
    Create Machine
    Create Terminal Tester    ${UART}

    # This line must use the "path" notation to handle paths with spaces
    Execute Command           sysbus.twi0.lsm9ds1_imu FeedAccelerationSample "${CURDIR}${/}circle_rotated.data"

    Start Emulation
    Wait For Line On Uart     Magic starts
    Wait For Line On Uart     RING:

Should Detect SLOPE Motion
    Create Machine
    Create Terminal Tester    ${UART}

    # This line must use the "path" notation to handle paths with spaces
    Execute Command           sysbus.twi0.lsm9ds1_imu FeedAccelerationSample "${CURDIR}${/}angle_rotated.data"

    Start Emulation
    Wait For Line On Uart     Magic starts
    Wait For Line On Uart     SLOPE:


