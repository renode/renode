*** Variables ***
${SCRIPT}                     @scripts/single-node/beaglev-fire.resc
${UART}                       sysbus.mmuart0

*** Keywords ***
Create Machine
    Execute Command          include @${SCRIPT}
    Create Terminal Tester   ${UART}

Should Run U-Boot
    Wait For Line On Uart    OpenSBI - version 1.2
    Wait For Line On Uart    U-Boot 2023.07
    Wait For Prompt On Uart  Model: BeagleBoard BeagleV-Fire

Should Show Login Prompt
    Wait For Prompt On Uart  buildroot login:  timeout=25
    Write Line To Uart       root

Should Run Uname
    Wait For Prompt On Uart  \#
    Write Line To Uart       uname -m
    Wait For Line On Uart    riscv64
    Write Line To Uart       uname -n
    Wait For Line On Uart    buildroot

*** Test Cases ***
Should Boot Buildroot From SD Card
    Create Machine
    Should Run U-Boot
    Should Show Login Prompt
    Should Run Uname
