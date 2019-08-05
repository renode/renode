*** Settings ***
Library                       Process
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${RENODEKEYWORDS}

*** Keywords ***
Create Platform
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @${CURDIR}/litex_linux_vexriscv.repl

    Execute Command            set kernel @https://antmicro.com/projects/renode/litex_linux_vexriscv--kernel.bin-s_4402492-63e4ad768e0aca4831bb95704f335f0152357e3b
    Execute Command            set rootfs @https://antmicro.com/projects/renode/litex_linux_vexriscv--rootfs.cpio-s_4071424-a3995f05549010596e955558f19f0e2e1e25ce3b
    Execute Command            set device_tree @https://antmicro.com/projects/renode/litex_linux_vexriscv--rv32.dtb-s_2297-74742abc8cb2aea59b7e7d1dffa43f7f837ec48c
    Execute Command            set emulator @https://antmicro.com/projects/renode/litex_vexriscv--emulator.bin-s_9028-796a4227b806997c6629462fdf0dcae73de06929

    Execute Command            sysbus LoadBinary $emulator 0x20000000
    Execute Command            sysbus LoadBinary $kernel 0xc0000000
    Execute Command            sysbus LoadBinary $rootfs 0xc0800000
    Execute Command            sysbus LoadBinary $device_tree 0xc1000000

    Execute Command            cpu PC 0x20000000

*** Test Cases ***
Should Boot
    Create Platform
    Create Terminal Tester     sysbus.uart  prompt=buildroot login:
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Prompt On Uart
    Write Line To Uart         root

    Wait For Line On Uart      root login on 'console'

    Write Line To Uart         export PS1="$ "
    Set New Prompt For Uart    $

    Provides                   booted-image

Should Control LED
    Requires                   booted-image

    Execute Command            emulation CreateLEDTester "led_tester" gpio_out.led
    Execute Command            led_tester AssertState false

    Write Line To Uart         cd /sys/class/gpio
    Wait For Prompt On Uart
    Write Line To Uart         echo 508 > export
    Wait For Prompt On Uart
    Write Line To Uart         cd gpio508
    Wait For Prompt On Uart

    Execute Command            led_tester AssertState false
    Write Line To Uart         echo 1 > value
    Wait For Prompt On Uart
    Execute Command            led_tester AssertState true

    Write Line To Uart         echo 0 > value
    Wait For Prompt On Uart
    Execute Command            led_tester AssertState false

Should Read Button
    Requires                   booted-image

    Write Line To Uart         cd /sys/class/gpio
    Wait For Prompt On Uart
    Write Line To Uart         echo 504 > export
    Wait For Prompt On Uart
    Write Line To Uart         cd gpio504
    Wait For Prompt On Uart

    Write Line To Uart         cat value
    Wait For Line On Uart      0
    Wait For Prompt On Uart

    Execute Command            gpio_in.button Toggle
    Write Line To Uart         cat value
    Wait For Line On Uart      1
    Wait For Prompt On Uart

    Execute Command            gpio_in.button Toggle
    Write Line To Uart         cat value
    Wait For Line On Uart      0
    Wait For Prompt On Uart

Should Handle SPI
    Requires                   booted-image

    Write Line To Uart         spidev_test -D /dev/spidev0.0 --speed 1000000
    Wait For Line On Uart      spi mode: 0x0
    Wait For Line On Uart      bits per word: 8
    Wait For Line On Uart      max speed: 1000000 Hz (1000 KHz)
    Wait For Line On Uart      RX | FF FF FF FF FF FF 40 00 00 00 00 95 FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF F0 0D

