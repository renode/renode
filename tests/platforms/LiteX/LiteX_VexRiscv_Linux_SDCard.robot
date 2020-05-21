*** Settings ***
Library                       Process
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${RENODEKEYWORDS}


*** Variables ***
${SHELL_PROMPT}                $

*** Keywords ***
Create Platform
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @${CURDIR}/litex_linux_vexriscv_sdcard.repl

    Execute Command            set kernel @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--kernel.bin-s_5795844-5856fe16d705aaeb09f2d2ae397f89f27ad672c7
    Execute Command            set rootfs @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--rootfs.cpio-s_4064768-3107c4884136bce0fccb40193416da6b179fd8cd
    Execute Command            set device_tree @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--rv32.dtb-s_4881-7438efa7d1bdf60f21643e7804688c1830b31672
    Execute Command            set emulator @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--emulator.bin-s_9584-51b9c133e1938e3b2cec63601a942cc580d93945

    Execute Command            sysbus LoadBinary $kernel 0x40000000
    Execute Command            sysbus LoadBinary $rootfs 0x40800000
    Execute Command            sysbus LoadBinary $device_tree 0x41000000
    Execute Command            sysbus LoadBinary $emulator 0x41100000

    Execute Command            cpu PC 0x41100000

    Execute Command            machine SdCardFromFile @https://dl.antmicro.com/projects/renode/fat16_sdcard.image-s_64000000-8a919aa2199e1a1cf086e67546b539295d2d9d8f mmc_controller False 64000000 "sdcard"

*** Test Cases ***
Should Boot
    Create Platform
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Line On Uart      litex-mmc f000a000.mmc: Setting clk freq to: 10000000
    Wait For Line On Uart      mmc0: new SD card at address 0000
    Wait For Line On Uart      blk_queue_max_hw_sectors: set to minimum 8
    Wait For Line On Uart      blk_queue_max_segment_size: set to minimum 4096
    Wait For Line On Uart      mmcblk0: mmc0:0000 RENOD 61.0 MiB 
    Wait For Line On Uart      mmcblk0: p1

    Wait For Prompt On Uart    buildroot login:
    Write Line To Uart         root

    Wait For Line On Uart      root login on 'console'

    Write Line To Uart         export PS1="$ "

    Provides                   booted-image

Should Mount Filesystem
    Requires                   booted-image

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         mount /dev/mmcblk0p1 /mnt

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         ls /mnt
    Wait For Line On Uart      readme.txt

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         cat /mnt/readme.txt
    Wait For Line On Uart      This is a test file

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         echo "This is a write test" > /mnt/readme2.txt

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         ls /mnt
    Wait For Line On Uart      readme2.txt

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         sync

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         umount /mnt

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         mount /dev/mmcblk0p1 /mnt

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         ls /mnt
    Wait For Line On Uart      readme2.txt

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         cat /mnt/readme2.txt
    Wait For Line On Uart      This is a write test

