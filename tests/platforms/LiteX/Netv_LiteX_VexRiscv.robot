*** Settings ***
Suite Setup                    Setup
Suite Teardown                 Teardown
Test Setup                     Reset Emulation
Test Teardown                  Test Teardown
Resource                       ${RENODEKEYWORDS}

*** Test Cases ***
Frame Buffer Test
    [Tags]                     non_critical
    Execute Command            using sysbus

    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @platforms/cpus/litex_netv2_vexriscv_linux.repl

    Execute Command            $kernel?=@https://dl.antmicro.com/projects/renode/litex_netv2_vexriscv--linux_kernel.bin-s_4553716-63780a978bf5768b81854e3febd58cabb47be4f0
    Execute Command            $rootfs?=@https://dl.antmicro.com/projects/renode/litex_netv2_vexriscv--buildroot_rootfs.cpio-s_4061696-befa7810480d9d85fd7d6a7e6c5f2514eb5de4ab
    Execute Command            $dtb?=@https://dl.antmicro.com/projects/renode/litex_netv2_vexriscv--linux.dtb-s_2068-2b68e9266b67dac4bafae70027a19fa487278bbe
    Execute Command            $emulator?=@https://dl.antmicro.com/projects/renode/litex_netv2_vexriscv--emulator.bin-s_10248-8039372fef62d8e4e4cb57e20561e37674fcc4ea

    Execute Command            sysbus LoadBinary $kernel 0xc0000000
    Execute Command            sysbus LoadBinary $rootfs 0xc0800000
    Execute Command            sysbus LoadFdt $dtb 0xc1000000
    Execute Command            sysbus LoadBinary $emulator 0x20000000

    Execute Command            cpu PC 0x20000000

    Create Terminal Tester     sysbus.uart  

    Start Emulation

    Wait For Prompt On Uart    buildroot login: 
    Write Line To Uart         root

    Wait For Line On Uart      root login on 'console'

    Write Line To Uart         export PS1="$ "
    Wait For Prompt On Uart    $

    Execute Command            emulation CreateFrameBufferTester "fb_tester" 5

    Execute Command            fb_tester AttachTo litex_video

    Write Line To Uart         cat /etc/motd > /dev/tty0
    Execute Command            fb_tester WaitForFrame @https://dl.antmicro.com/projects/renode/screenshots/penguin_with_litex_logo.png-s_15074-bbb8416ce2281def08847e6192953b1841cb8807
