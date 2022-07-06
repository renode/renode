*** Variables ***
${SHELL_PROMPT}                $

*** Keywords ***
Create Platform
    Execute Command            using sysbus
    Execute Command            mach create
    # This line must use the "path" notation to handle paths with spaces
    Execute Command            machine LoadPlatformDescription "${CURDIR}${/}litex_linux_vexriscv.repl"

    Execute Command            set kernel @https://dl.antmicro.com/projects/renode/litex_linux_vexriscv--kernel.bin-s_4578292-f63a4736100b5ff79a8d72429c1b79718ec7a446
    Execute Command            set rootfs @https://dl.antmicro.com/projects/renode/litex_linux_vexriscv--rootfs.cpio-s_4163584-c44ad487ba1f73c00430a1bb108ceef84007274f
    Execute Command            set device_tree @https://dl.antmicro.com/projects/renode/litex_linux_vexriscv--rv32.dtb-s_2609-9a915b47b8e31d0d3f268c4a297dc0b0555e8cd0
    Execute Command            set emulator @https://dl.antmicro.com/projects/renode/litex_vexriscv--emulator.bin-s_9028-796a4227b806997c6629462fdf0dcae73de06929

    Execute Command            sysbus LoadBinary $emulator 0x20000000
    Execute Command            sysbus LoadBinary $kernel 0xc0000000
    Execute Command            sysbus LoadBinary $rootfs 0xc0800000
    Execute Command            sysbus LoadBinary $device_tree 0xc1000000

    Execute Command            cpu PC 0x20000000

*** Test Cases ***
Should Boot
    Create Platform
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Prompt On Uart    buildroot login:
    Write Line To Uart         root

    Wait For Line On Uart      root login on 'console'

    Write Line To Uart         export PS1="$ "

    Provides                   booted-image

Should Control LED
    Requires                   booted-image

    Execute Command            emulation CreateLEDTester "led_tester" gpio_out.led
    Execute Command            led_tester AssertState false

    Write Line To Uart         cd /sys/class/gpio
    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         echo 508 > export
    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         cd gpio508
    Wait For Prompt On Uart    ${SHELL_PROMPT}

    Execute Command            led_tester AssertState false
    Write Line To Uart         echo 1 > value
    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Execute Command            led_tester AssertState true

    Write Line To Uart         echo 0 > value
    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Execute Command            led_tester AssertState false

Should Read Button
    Requires                   booted-image

    Write Line To Uart         cd /sys/class/gpio
    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         echo 504 > export
    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         cd gpio504
    Wait For Prompt On Uart    ${SHELL_PROMPT}

    Write Line To Uart         cat value
    Wait For Line On Uart      0
    Wait For Prompt On Uart    ${SHELL_PROMPT}

    Execute Command            gpio_in.button Toggle
    Write Line To Uart         cat value
    Wait For Line On Uart      1
    Wait For Prompt On Uart    ${SHELL_PROMPT}

    Execute Command            gpio_in.button Toggle
    Write Line To Uart         cat value
    Wait For Line On Uart      0
    Wait For Prompt On Uart    ${SHELL_PROMPT}

Should Handle SPI
    Requires                   booted-image

    Write Line To Uart         spidev_test -D /dev/spidev0.0 --speed 1000000
    Wait For Line On Uart      spi mode: 0x0
    Wait For Line On Uart      bits per word: 8
    Wait For Line On Uart      max speed: 1000000 Hz (1000 KHz)
    Wait For Line On Uart      RX | FF FF FF FF FF FF 40 00 00 00 00 95 FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF F0 0D

Should Handle I2C
    Requires                   booted-image

    Write Line To Uart         i2cdetect -y 0

    Wait For Line On Uart      00:${SPACE*10}-- -- UU -- -- -- -- -- -- -- -- -- --
    Wait For Line On Uart      10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    Wait For Line On Uart      20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    Wait For Line On Uart      30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    Wait For Line On Uart      40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    Wait For Line On Uart      50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    Wait For Line On Uart      60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    Wait For Line On Uart      70: -- -- -- -- -- -- -- --

    Write Line To Uart         cd /sys/class/i2c-dev/i2c-0/device/0-0005/iio:device0

    Write Line To Uart         cat in_temp_raw
    Wait For Line On Uart      4384
    Wait For Prompt On Uart    ${SHELL_PROMPT}

    Execute Command            i2c.si7021 Temperature 36
    Write Line To Uart         cat in_temp_raw
    Wait For Line On Uart      7705
    Wait For Prompt On Uart    ${SHELL_PROMPT}

