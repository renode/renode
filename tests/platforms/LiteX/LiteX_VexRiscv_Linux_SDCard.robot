*** Variables ***
${SHELL_PROMPT}                $

*** Keywords ***
Create Platform
    [Arguments]                ${device_tree}        ${sdcard_image}
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @platforms/cpus/litex_linux_vexriscv_sdcard.repl

    Execute Command            set device_tree @https://dl.antmicro.com/projects/renode/${device_tree}

    Execute Command            set kernel @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--kernel.bin-s_6934900-7a7291fdb880ad8e2aa75276807f8adf5fb8303a
    Execute Command            set emulator @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--opensbi.bin-s_45360-71c1954133f6589f34fcb00554be44195e23e9d5

    Execute Command            sysbus LoadBinary $kernel 0x40000000
    Execute Command            sysbus LoadBinary $device_tree 0x40ef0000
    Execute Command            sysbus LoadBinary $emulator 0x40f00000

    Execute Command            cpu PC 0x40f00000

    Execute Command            machine SdCardFromFile @https://dl.antmicro.com/projects/renode/${sdcard_image} mmc_controller 0x4000000 False

Load Rootfs To Ram
    Execute Command            set rootfs @https://dl.antmicro.com/projects/renode/litex_vexriscv-sdcard--rootfs.cpio-s_4064768-3107c4884136bce0fccb40193416da6b179fd8cd
    Execute Command            sysbus LoadBinary $rootfs 0x40800000

*** Test Cases ***
Should Mount Filesystem From SD Card
    Create Platform            litex_vexriscv-sdcard--rv32.dtb-s_3323-fdafbb56af0ba66f1b6eb0f6c847238cb77f4095
    ...                        fat16_sdcard.image-s_64000000-8a919aa2199e1a1cf086e67546b539295d2d9d8f
    Load Rootfs To Ram 

    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Line On Uart      mmc0: new SD card at address 0000
    Wait For Line On Uart      blk_queue_max_hw_sectors: set to minimum 8
    Wait For Line On Uart      blk_queue_max_segment_size: set to minimum 4096
    Wait For Line On Uart      mmcblk0: mmc0:0000 RENOD 64.0 MiB 
    Wait For Line On Uart      mmcblk0: p1

    Wait For Prompt On Uart    buildroot login:
    Write Line To Uart         root

    Wait For Line On Uart      32-bit VexRiscv CPU with MMU integrated in a LiteX SoC

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
    Create Platform            litex_vexriscv-sdcard--rootfs_from_sdcard-rv32.dtb-s_3255-8305d2b80955418e53f5400c492dc74dccf05ac8
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

    Wait For Prompt On Uart    root@buildroot

    Write Line To Uart         export PS1="$ "

    Wait For Prompt On Uart    ${SHELL_PROMPT}
    Write Line To Uart         ls -la /
    Wait For Line On Uart      linuxrc -> bin/busybox

