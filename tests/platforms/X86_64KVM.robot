*** Variables ***
${UART}                       sysbus.uart
${SCRIPT_BIOS}                @scripts/single-node/x86_64-kvm-bios.resc
${SCRIPT_LINUX}               @scripts/single-node/x86_64-kvm-linux.resc

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
