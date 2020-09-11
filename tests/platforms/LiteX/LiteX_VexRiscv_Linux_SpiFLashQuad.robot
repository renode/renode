*** Settings ***
Library                       Process
Suite Setup                   Setup
Suite Teardown                Teardown
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${PROMPT}                     \#${SPACE}

*** Keywords ***
Prepare Machine
    Execute Command           mach create "litex-vexriscv"
    Execute Command           machine LoadPlatformDescription @${CURDIR}/litex-vexriscv_spiflash_quad.repl
    
    Execute Command           showAnalyzer sysbus.uart
   
    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/litex-vexriscv_spiflash_quad--kernel.bin-s_6031812-d26d1d03552dd13ebce445c913a03d5dd8e04758 0x40000000
    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/litex-vexriscv_spiflash_quad--rootfs.cpio-s_7052800-caeeb6dc2bc6c2bf44d12add145ffbacc6573ec2 0x40800000
    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/litex-vexriscv_spiflash_quad--rv32.dtb-s_2341-acc12c43d21630423e09547fb092ff4570b1cf33 0x41000000
    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/litex-vexriscv_spiflash_quad--emulator.bin-s_2992-12e60410d881ebc1a1a80ed79b1f26ede5153480 0x41100000
    Execute Command           sysbus.cpu PC 0x41100000

*** Test Cases ***
Test Flash
    Prepare Machine
    Create Terminal Tester    sysbus.uart  timeout=4800

    Start Emulation

    Wait For Line On Uart     No DTB passed to the kernel
    Wait For Line On Uart     Creating 1 MTD partitions on "NAND 128MiB 1,8V 8-bit"
    Wait For Line On Uart     litex-spiflash_quad_read_write 20000000.spiflash: n25q128a11

    Wait For Line On Uart     Welcome to Buildroot
    Wait For Prompt On Uart   buildroot login:
    Write Line To Uart        root

    # format the flash memory and create a file    
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        flash_erase -j /dev/mtd1 0 0
    Wait For Line On Uart     Erasing 4 Kibyte @ fff000 -- 100 % complete

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        mount -t jffs2 /dev/mtdblock1 /mnt

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        echo "Hello, Renode!" > /mnt/test.txt

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ls -l /mnt
    Wait For Line On Uart     total 1
    Wait For Line On Uart     test.txt

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        sync

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        umount /mnt

    # remount the filesystem and read the file
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ls -l /mnt
    Wait For Line On Uart     total 0

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        mount -t jffs2 /dev/mtdblock1 /mnt

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        ls -l /mnt
    Wait For Line On Uart     total 1
    Wait For Line On Uart     test.txt

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        cat /mnt/test.txt
    Wait For Line On Uart     Hello, Renode!


