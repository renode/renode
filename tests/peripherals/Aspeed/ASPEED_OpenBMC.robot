*** Comments ***
# Copyright (c) 2026 Microsoft
# SPDX-License-Identifier: Apache-2.0
#
# AST2600 OpenBMC Boot Tests
# Tests full OpenBMC boot: SPL -> u-boot -> Linux kernel -> userspace

*** Settings ***
Suite Setup         Run Keywords    Setup    AND    Create OpenBMC Machine
Suite Teardown      Teardown

*** Variables ***
${UART5}            sysbus.uart5

*** Keywords ***
Create OpenBMC Machine
    Execute Command     mach create "ast2600"
    Execute Command     machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl
    # Load firmware into bootrom (0x0), flash backing store (0x60000000), and DRAM (0x88000000)
    Execute Command     sysbus LoadBinary @tests/peripherals/Aspeed/firmware/openbmc-image.bin 0x0
    Execute Command     sysbus LoadBinary @tests/peripherals/Aspeed/firmware/openbmc-image.bin 0x60000000
    Execute Command     sysbus LoadBinary @tests/peripherals/Aspeed/firmware/openbmc-image.bin 0x88000000

    # Silence unmapped peripheral regions to prevent driver probe hangs
    Execute Command     sysbus SilenceRange <0x1E630000 0xC4>
    Execute Command     sysbus SilenceRange <0x30000000 0x10000000>
    Execute Command     sysbus SilenceRange <0x1E631000 0xC4>
    Execute Command     sysbus SilenceRange <0x50000000 0x10000000>
    Execute Command     sysbus SilenceRange <0x1E650000 0x20>
    Execute Command     sysbus SilenceRange <0x1E740000 0x10000>
    Execute Command     sysbus SilenceRange <0x1E750000 0x10000>
    Execute Command     sysbus SilenceRange <0x1E6A0000 0x1000>
    Execute Command     sysbus SilenceRange <0x1E6A3000 0x1000>
    Execute Command     sysbus SilenceRange <0x1E700000 0x1000>

    Create Terminal Tester    ${UART5}    timeout=120

*** Test Cases ***
Should Boot SPL
    [Documentation]     Verify SPL starts and loads FIT image
    [Tags]              openbmc    boot    spl
    Execute Command     emulation RunFor "5"
    Wait For Line On Uart    U-Boot SPL    timeout=30
    Wait For Line On Uart    Trying to boot from    timeout=10

Should Load U-Boot
    [Documentation]     Verify u-boot loads and initializes hardware
    [Tags]              openbmc    boot    uboot
    Wait For Line On Uart    U-Boot 2019    timeout=30
    Wait For Line On Uart    DRAM:    timeout=15
    Wait For Line On Uart    Model: AST2600 EVB    timeout=10

Should Detect Peripherals In U-Boot
    [Documentation]     Verify u-boot probes key peripherals
    [Tags]              openbmc    boot    peripherals
    Wait For Line On Uart    MMC:    timeout=15
    Wait For Line On Uart    Net:    timeout=15
    Wait For Line On Uart    eth0:    timeout=10

Should Start Kernel With Earlycon
    [Documentation]     Interrupt autoboot to inject earlycon, then boot kernel
    [Tags]              openbmc    boot    kernel
    # Interrupt u-boot autoboot
    Wait For Line On Uart    autoboot    timeout=30    includeUnfinishedLine=true
    Write Line To Uart
    Wait For Line On Uart    =>    timeout=5    includeUnfinishedLine=true
    # Add earlycon and boot from DRAM copy (FIT at offset 0x100000)
    Write Line To Uart    setenv bootargs console=ttyS4,115200n8 earlycon=uart8250,mmio32,0x1e784000,115200n8 nosmp maxcpus=1 panic=-1
    Wait For Line On Uart    =>    timeout=5    includeUnfinishedLine=true
    Write Line To Uart    bootm 88100000
    Wait For Line On Uart    Starting kernel    timeout=60

Should Boot Linux Kernel
    [Documentation]     Verify Linux kernel starts and prints banner
    [Tags]              openbmc    boot    linux
    Wait For Line On Uart    Linux version    timeout=120
    Wait For Line On Uart    Booting Linux on    timeout=10

Should Mount Root Filesystem
    [Documentation]     Verify rootfs mounts successfully
    [Tags]              openbmc    boot    rootfs
    Wait For Line On Uart    VFS: Mounted root    timeout=120

Should Reach Login Prompt
    [Documentation]     Verify system boots to login prompt
    [Tags]              openbmc    boot    login
    Wait For Line On Uart    login:    timeout=300
