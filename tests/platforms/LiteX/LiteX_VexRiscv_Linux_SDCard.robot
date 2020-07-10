*** Settings ***
Library                       Process
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}


*** Variables ***
${SHELL_PROMPT}                $

*** Keywords ***
Create Platform
    [Arguments]                ${device_tree}        ${sdcard_image}
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @platforms/cpus/litex_linux_vexriscv_sdcard.repl

    Execute Command            set device_tree @https://dl.antmicro.com/projects/renode/${device_tree}

    Execute Command            set kernel @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--kernel.bin-s_5787652-2115891ba50b339ae0d8b5ece999fc685791fbbc
    Execute Command            set emulator @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--emulator.bin-s_9584-51b9c133e1938e3b2cec63601a942cc580d93945

    Execute Command            sysbus LoadBinary $kernel 0x40000000
    Execute Command            sysbus LoadBinary $device_tree 0x41000000
    Execute Command            sysbus LoadBinary $emulator 0x41100000

    Execute Command            cpu PC 0x41100000

    Execute Command            machine SdCardFromFile @https://dl.antmicro.com/projects/renode/${sdcard_image} mmc_controller False

Load Rootfs To Ram
    Execute Command            set rootfs @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--rootfs.cpio-s_4064768-3107c4884136bce0fccb40193416da6b179fd8cd
    Execute Command            sysbus LoadBinary $rootfs 0x40800000

*** Test Cases ***
Should Mount Filesystem From SD Card
    Create Platform            litex_vexriscv-sdcard--rv32.dtb-s_4881-7438efa7d1bdf60f21643e7804688c1830b31672
    ...                        fat16_sdcard.image-s_64000000-8a919aa2199e1a1cf086e67546b539295d2d9d8f
    Load Rootfs To Ram 

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

Should Load RootFS From SD Card
    Create Platform            litex_vexriscv-sdcard--rootfs_from_sdcard-rv32.dtb-s_4813-b837492f949c15f8ddb9e7e318484a4c689b2841
    ...                        riscv32-buildroot--busybox-rootfs.ext4.image-s_67108864-cd5badff81b32092c010d683c471821d4ea99af6

    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Line On Uart      mmc0: new SD card at address 0000
    Wait For Line On Uart      blk_queue_max_hw_sectors: set to minimum 8
    Wait For Line On Uart      blk_queue_max_segment_size: set to minimum 4096
    Wait For Line On Uart      mmcblk0: mmc0:0000 RENOD

    Wait For Line On Uart      VFS: Mounted root (ext4 filesystem) readonly 
    Wait For Line On Uart      Run /sbin/init as init process

    Wait For Prompt On Uart    buildroot login:
    Write Line To Uart         root

    Wait For Line On Uart      root login on 'console'

    Write Line To Uart         export PS1="$ "

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         ls -la /
    Wait For Line On Uart      linuxrc -> bin/busybox

