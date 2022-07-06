*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords **
Create Platform
    [Arguments]               ${elf}

    Execute Command           mach create "max32650"
    Execute Command           machine LoadPlatformDescription @platforms/boards/max32652-evkit.repl
    Execute Command           sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Should return temperature from TMP103 over I2C
    Create Platform           max32650-i2c_tmp103.elf-s_1036416-199a0f445f8bd65dd11b1f867f4848e732016892
    Execute Command           machine LoadPlatformDescriptionFromString "tmp103: Sensors.TMP103 @ i2c1 0x70"

    Create Terminal Tester    ${UART}

    # Set temperature to 29C
    Execute Command           sysbus.i2c1.tmp103 Temperature 29

    Start Emulation
    Wait For Line On Uart     Temperature: 29C
