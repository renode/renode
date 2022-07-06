*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/hifive_unleashed.resc
${UART}                       sysbus.uart0

*** Keywords ***
Prepare Machine
    # we use special FDT that contains spi sensors
    Execute Command           \$fdt?=@https://dl.antmicro.com/projects/renode/hifive-unleashed--devicetree-tests.dtb-s_8718-ba79c50f59ec31c6317ba31d1eeebee2b4fb3d89
    Execute Script            ${SCRIPT}

    # attach SPI sensor
    Execute Command           machine LoadPlatformDescriptionFromString "lm74_1: Sensors.TI_LM74 @ qspi1 0x0"
    Execute Command           machine LoadPlatformDescriptionFromString "lm74_2: Sensors.TI_LM74 @ qspi1 0x1"

    # attach I2C sensors
    Execute Command           machine LoadPlatformDescriptionFromString "si7021: Sensors.SI70xx @ i2c 0x40 { model: Model.SI7021 }"

    # create gpio analyzer and connect pwm0 to it
    Execute Command           machine LoadPlatformDescriptionFromString "pt: PWMTester @ pwm0 2"
    Execute Command           machine LoadPlatformDescriptionFromString "pwm0: { 2 -> pt@0 }"

*** Test Cases ***
Should Boot Linux
    [Documentation]           Boots Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  interrupts
    Prepare Machine

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Prompt On Uart   buildroot login
    Write Line To Uart        root
    Wait For Prompt On Uart   Password
    Write Line To Uart        root             waitForEcho=false
    Wait For Prompt On Uart   \#

    # This platform must use an old approach as it fails to deserialize on Windows and macOS
    Provides                  booted-linux  Reexecution

Should Ls
    [Documentation]           Tests shell responsiveness in Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  interrupts
    Requires                  booted-linux

    Write Line To Uart        ls /
    Wait For Line On Uart     proc

Should Read Temperature From SPI sensors
    [Documentation]           Reads temperature from SPI sensor in Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  spi  sensors
    Requires                  booted-linux

    Execute Command           qspi1.lm74_1 Temperature 36.5
    Execute Command           qspi1.lm74_2 Temperature 73

    Write Line To Uart        cd /sys/class/spi_master/spi0/spi0.0/hwmon/hwmon0
    Write Line To Uart        cat temp1_input
    Wait For Line On Uart     36500

    Write Line To Uart        cd /sys/class/spi_master/spi0/spi0.1/hwmon/hwmon1
    Write Line To Uart        cat temp1_input
    Wait For Line On Uart     73000

Should Detect I2C sensor
    [Documentation]           Tests I2C controller in Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  i2c
    Requires                  booted-linux

    Write Line To Uart        i2cdetect 0
    Wait For Prompt On Uart   Continue? [y/N]
    Write Line To Uart        y

    Wait For Line On Uart     40: 40 --

Should Read Temperature From I2C sensor
    [Documentation]           Reads temperature from I2C sensor in Linux on SiFive Freedom U540 platform.
    [Tags]                    linux  uart  i2c  sensors
    Requires                  booted-linux

    Execute Command           i2c.si7021 Temperature 36.6

    Write Line To Uart        echo "si7020 0x40" > /sys/class/i2c-dev/i2c-0/device/new_device
    Wait For Line On Uart     Instantiated device si7020 at 0x40

    Write Line To Uart        cd /sys/class/i2c-dev/i2c-0/device/0-0040/iio:device0
    # here we read a RAW value from the device
    # warning: the driver uses different equation to calculate the actual value than the documentation says, so it will differ from what we set in the peripheral
    Write Line To Uart        cat in_temp_raw
    Wait For Line On Uart     7780

# there is some bug in PWM implementation or the PWM tester and this tests fails non-deterministically
Should Generate Proper PWM Pulses
    [Tags]                    non_critical
    Requires                  booted-linux

    Write Line To Uart        echo 5 > /sys/class/leds/netdev/brightness
    Execute Command           pwm0.pt Reset
    Sleep                     3
    ${hp}=  Execute Command   pwm0.pt HighPercentage
    ${hpn}=  Convert To Number  ${hp}
    Should Be True            ${hpn} < 10
    Should Be True            ${hpn} > 0

    Write Line To Uart        echo 127 > /sys/class/leds/netdev/brightness
    Execute Command           pwm0.pt Reset
    Sleep                     3
    ${hp}=  Execute Command   pwm0.pt HighPercentage
    ${hpn}=  Convert To Number  ${hp}
    Should Be True            ${hpn} < 55
    Should Be True            ${hpn} > 45

    Write Line To Uart        echo 250 > /sys/class/leds/netdev/brightness
    Execute Command           pwm0.pt Reset
    Sleep                     3
    ${hp}=  Execute Command   pwm0.pt HighPercentage
    ${hpn}=  Convert To Number  ${hp}
    Should Be True            ${hpn} < 100
    Should Be True            ${hpn} > 90

Should Ping Linux
    Execute Command           emulation CreateSwitch "switch"

    Execute Command           $name="unleashed-1"
    Prepare Machine
    Execute Command           connector Connect ethernet switch
    ${u1}=                    Create Terminal Tester    ${UART}     machine=unleashed-1

    Execute Command           mach clear
    Execute Command           $name="unleashed-2"
    Prepare Machine
    Execute Command           connector Connect ethernet switch
    ${u2}=                    Create Terminal Tester    ${UART}     machine=unleashed-2
    Execute Command           mach clear

    Start Emulation

    Wait For Prompt On Uart   buildroot login                                   testerId=${u1}
    Write Line To Uart        root                                              testerId=${u1}
    Wait For Prompt On Uart   Password                                          testerId=${u1}
    Write Line To Uart        root                         waitForEcho=false    testerId=${u1}

    Wait For Prompt On Uart   buildroot login                                   testerId=${u2}
    Write Line To Uart        root                                              testerId=${u2}
    Wait For Prompt On Uart   Password                                          testerId=${u2}
    Write Line To Uart        root                         waitForEcho=false    testerId=${u2}

    Write Line To Uart        ifconfig eth0 hw ether 02:01:03:05:04:06          testerId=${u1}
    Write Line To Uart        ifconfig eth0 192.168.0.1 netmask 255.255.255.0   testerId=${u1}
    Write Line To Uart        ifconfig eth0 192.168.0.2 netmask 255.255.255.0   testerId=${u2}

    Write Line To Uart        ping 192.168.0.1                                  testerId=${u2}
    Wait For Line On Uart     64 bytes from 192.168.0.1                         testerId=${u2}

