*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/icicle-kit.resc
${UART_HSS}                   sysbus.mmuart0
${UART}                       sysbus.mmuart1

*** Keywords ***
Prepare Machine
    # we use special FDT that contains spi sensors
    Execute Script            ${SCRIPT}
    Execute Command           logLevel 3 sysbus.mmc
    Execute Command           logLevel 3 sysbus

*** Test Cases ***
Should Boot HSS
    [Documentation]           Boots Hart Software Services on Icicle Kit with PolarFire SoC
    [Tags]                    bootloader  uart  ddr  sd
    Prepare Machine

    ${hss}=                   Create Terminal Tester          ${UART_HSS}

    Start Emulation

    Wait For Line On Uart     Timeout in (\\d+) seconds       treatAsRegex=true
    Send Key To Uart          0x1B
    Wait For Line On Uart     u54_\\d+:sbi_init 80200000      treatAsRegex=true
    Wait For Line On Uart     u54_\\d+:sbi_init 80200000      treatAsRegex=true
    Wait For Line On Uart     u54_\\d+:sbi_init 80200000      treatAsRegex=true
    Wait For Line On Uart     u54_\\d+:sbi_init 80200000      treatAsRegex=true

    Provides                  booted-hss

Should Boot U-Boot
    [Documentation]           Boots U-Boot from SD card on Icicle Kit with PolarFire SoC
    [Tags]                    bootloader  uart
    Requires                  booted-hss

    ${uart}=                  Create Terminal Tester          ${UART}  defaultPauseEmulation=true
    SetDefaultTester          ${uart}

    Wait For Prompt On Uart   Hit any key to stop autoboot
    Send Key To Uart          0x1B
    Write Line To Uart        boot
    Wait For Line On Uart     Loading kernel from FIT Image     treatAsRegex=true
    Wait For Line On Uart     Loading ramdisk from FIT Image    treatAsRegex=true
    Wait For Line On Uart     Loading fdt from FIT Image        treatAsRegex=true
    Wait For Line On Uart     Starting kernel ...               treatAsRegex=true

    Provides                  booted-uboot

Should Boot Linux
    [Documentation]           Boots Linux on Icicle Kit with PolarFire SoC.
    [Tags]                    linux  uart  interrupts
    Requires                  booted-uboot

    Wait For Line On Uart     Starting network  timeout=5
    Wait For Prompt On Uart   buildroot login:  timeout=10
    Write Line To Uart        root
    Wait For Prompt On Uart   Password
    Write Line To Uart        root              waitForEcho=false
    Wait For Prompt On Uart   \#
    Provides                  booted-linux

Should Ls
    [Documentation]           Tests shell responsiveness in Linux on Icicle Kit
    [Tags]                    linux  uart  interrupts
    Requires                  booted-linux
    Write Line To Uart        ls /
    Wait For Line On Uart     proc
