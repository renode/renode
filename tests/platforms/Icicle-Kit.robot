*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/icicle-kit.resc
${UART_HSS}                   sysbus.mmuart0
${UART}                       sysbus.mmuart1

*** Keywords ***
Prepare Machine
    # we use special FDT that contains spi sensors
    Execute Script            ${SCRIPT}
    Set Default Uart Timeout  300

# These tests have some code duplication (before the `Requires` keywords) to alleviate the problem related
# to non-idempotent behavior of `CreateTerminalTester`. This duplication should be removed when we address
# this issue.
*** Test Cases ***
Should Boot HSS
    [Documentation]           Boots Hart Software Services on Icicle Kit with PolarFire SoC
    [Tags]                    bootloader  uart  ddr  sd
    Prepare Machine
    ${hss}=                   Create Terminal Tester          ${UART_HSS}
    ${uart}=                  Create Terminal Tester          ${UART}
    Start Emulation

    Wait For Line On Uart     Timeout in (\\d+) seconds       testerId=${hss}  treatAsRegex=true
    Wait For Line On Uart     u54_\\d+:sbi_init 80200000      testerId=${hss}  treatAsRegex=true
    Wait For Line On Uart     u54_\\d+:sbi_init 80200000      testerId=${hss}  treatAsRegex=true
    Wait For Line On Uart     u54_\\d+:sbi_init 80200000      testerId=${hss}  treatAsRegex=true
    Wait For Line On Uart     u54_\\d+:sbi_init 80200000      testerId=${hss}  treatAsRegex=true

    Provides                  booted-hss

Should Boot U-Boot
    [Documentation]           Boots U-Boot from SD card on Icicle Kit with PolarFire SoC
    [Tags]                    bootloader  uart
    Prepare Machine
    ${hss}=                   Create Terminal Tester          ${UART_HSS}
    ${uart}=                  Create Terminal Tester          ${UART}
    Start Emulation
    #Requires                  booted-hss

    Wait For Prompt On Uart   Hit any key to stop autoboot    testerId=${uart}  treatAsRegex=true
    Wait For Line On Uart     Loading kernel from FIT Image   testerId=${uart}  treatAsRegex=true
    Wait For Line On Uart     Loading ramdisk from FIT Image  testerId=${uart}  treatAsRegex=true
    Wait For Line On Uart     Loading fdt from FIT Image      testerId=${uart}  treatAsRegex=true
    Wait For Line On Uart     Starting kernel ...             testerId=${uart}  treatAsRegex=true

    Provides                  booted-uboot

Should Boot Linux
    [Documentation]           Boots Linux on Icicle Kit with PolarFire SoC.
    [Tags]                    linux  uart  interrupts
    Prepare Machine
    ${hss}=                   Create Terminal Tester        ${UART_HSS}
    ${uart}=                  Create Terminal Tester        ${UART}
    Start Emulation
    #Requires                  booted-uboot

    Wait For Prompt On Uart   buildroot login:  testerId=${uart}
    Write Line To Uart        root              testerId=${uart}
    Wait For Prompt On Uart   Password          testerId=${uart}
    Write Line To Uart        root              testerId=${uart}  waitForEcho=false
    Wait For Prompt On Uart   \#                testerId=${uart}

    Provides                  booted-linux

Should Ls
    [Documentation]           Tests shell responsiveness in Linux on Icicle Kit
    [Tags]                    linux  uart  interrupts
    Prepare Machine
    ${hss}=                   Create Terminal Tester        ${UART_HSS}
    ${uart}=                  Create Terminal Tester        ${UART}
    Start Emulation
    Wait For Prompt On Uart   buildroot login:  testerId=${uart}
    Write Line To Uart        root              testerId=${uart}
    Wait For Prompt On Uart   Password          testerId=${uart}
    Write Line To Uart        root              testerId=${uart}  waitForEcho=false
    Wait For Prompt On Uart   \#                testerId=${uart}
    #Requires                  booted-linux

    Write Line To Uart        ls /              testerId=${uart}
    Wait For Line On Uart     proc              testerId=${uart}

