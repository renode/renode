*** Keywords ***
Create Platform
    Execute Command           using sysbus

    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/litex_vexriscv_smp.repl

    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/litex_vexriscv_smp--opensbi.bin-s_45360-dcfe5f7b149bd1e0232609d87fb698f95f5e33c4 0x40F00000
    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/litex_vexriscv_smp--linux_kernel.bin-s_3009892-d77e1e2a896ab0767452ee9b1186e117b606ba39 0x40000000
    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/litex_vexriscv_smp--device_tree.dtb-s_1703-ebe07ee2f4e15760ae9b13483a51d241cab20002 0x40EF0000
    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/litex_vexriscv_smp--rootfs.cpio-s_4570112-7a6a6388e09170db38795a006dd75f91d556eecf 0x41000000

    Execute Command           cpu_0 PC 0x40F00000
    Execute Command           cpu_1 PC 0x40F00000
    Execute Command           cpu_2 PC 0x40F00000
    Execute Command           cpu_3 PC 0x40F00000


*** Test Cases ***
Should Run OpenSBI
    Create Platform
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Line On Uart      OpenSBI v0.6
    Wait For Line On Uart      Litex/VexRiscv SMP
    Wait For Line On Uart      Platform Max HARTs\\s+ : 4      treatAsRegex=True


Should Boot Linux
    [Tags]                     non_critical

    Create Platform
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Line On Uart      Linux version 5.0.9
    Wait For Line On Uart      smp: Brought up 1 node, 4 CPUs
    Wait For Line On Uart      Welcome to Buildroot  timeout=16

    Wait For Prompt On Uart    buildroot login:
    Write Line To Uart         root

    Wait For Prompt On Uart    root@buildroot:~#
    Write Line To Uart         cat /proc/cpuinfo

    Wait For Line On Uart      processor\t: 0
    Wait For Line On Uart      processor\t: 1
    Wait For Line On Uart      processor\t: 2
    Wait For Line On Uart      processor\t: 3

