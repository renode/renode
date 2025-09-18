*** Variables ***
${UART}                       sysbus.uart
${SCRIPT_BIOS}                @scripts/single-node/x86_64-kvm-bios.resc
${SCRIPT_LINUX}               @scripts/single-node/x86_64-kvm-linux.resc
${SCRIPT_LINUX_VIRTIO}        @scripts/single-node/x86_64-kvm-linux-virtio.resc

*** Test Cases ***
Should Run SeaBIOS
    [Tags]                    skip_windows  skip_osx  skip_host_arm
    Execute Command           include ${SCRIPT_BIOS}
    Create Terminal Tester    sysbus.uart
    Wait For Line On Uart     SeaBIOS \\(version .*\\)  treatAsRegex=True

Should Run Linux
    [Tags]                    skip_windows  skip_osx  skip_host_arm
    Execute Command           include ${SCRIPT_LINUX}
    Create Terminal Tester    sysbus.uart  defaultPauseEmulation=true
    Wait For Prompt On Uart   buildroot login:
    Write Line To Uart        root
    Wait For Prompt On Uart   \#
    Write Line To Uart        ls /
    Wait For Line On Uart     .*bin *init.*  treatAsRegex=True
    Write Line To Uart        uname -m
    Wait For Line On Uart     x86_64

Should Run Linux On Virtio
    [Tags]                    skip_windows  skip_osx  skip_host_arm
    Execute Command           include ${SCRIPT_LINUX_VIRTIO}
    Create Terminal Tester    sysbus.uart  defaultPauseEmulation=true
    Wait For Prompt On Uart   U-Boot
    Wait For Prompt On Uart   =>
    Write Line To Uart        ext2load virtio 0 0x1000000 /boot/bzImage
    Wait For Prompt On Uart   6272000 bytes read
    Write Line To Uart        zboot
    Wait For Prompt On Uart   buildroot login:
    Write Line To Uart        root
    Wait For Prompt On Uart   \#
    Write Line To Uart        cat /proc/mounts | grep "root"
    Wait For Line On Uart     /dev/root / ext2 rw,relatime 0 0
