*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${VMLINUX}                          ${URI}/zynq-interface-tests-vmlinux-s_14142952-ab5cd7445f31414fcbf8c79d49d737c669034ef2
${ROOTFS}                           ${URI}/zynq--interface-tests-rootfs.ext2-s_16777216-191638e3b3832a81bebd21d555f67bf3a4d7882a
${DTB}                              ${URI}/zynq-interface-tests-gem0.dtb-s_11724-f0dec8ffadea47891dfe2441215401f09f7242fa
${PLATFORM_REPL}                    @tests/platforms/ArmExperimental/zedboard.repl
${PROMPT}                           \#${SPACE}

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM_REPL}

    # From Zedboard resc
    Execute Command                 sysbus Redirect 0xC0000000 0x0 0x10000000
    Execute Command                 cpu SetRegister "R0" 0x000
    # processor variant (cortex-a9)
    Execute Command                 cpu SetRegister "R1" 0xD32
    # device tree address
    Execute Command                 cpu SetRegister "R2" 0x100
    Execute Command                 sysbus LoadELF ${VMLINUX}
    Execute Command                 sysbus LoadFdt ${DTB} 0x100 "console=ttyPS0,115200 root=/dev/ram0 rw initrd=0x1a000000,16M" false
    Execute Command                 sysbus LoadBinary ${ROOTFS} 0x1a000000

*** Test Cases ***
Should Boot Linux to Userspace
    Create Machine
    Create Terminal Tester          sysbus.uart0
    Wait For Line On Uart           Booting Linux on physical CPU 0x0
    Wait For Line On Uart           Run /sbin/init as init process
    Wait For Prompt On Uart         buildroot login:
    Write Line To Uart              root
    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              ls
    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              sh
    Wait For Prompt On Uart         ${PROMPT}
