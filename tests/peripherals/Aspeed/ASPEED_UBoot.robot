*** Settings ***
Library           String
Suite Teardown    Teardown
Test Teardown     Test Teardown
Test Setup        Reset Emulation

*** Variables ***
${FLASH_BIN}      tests/peripherals/Aspeed/firmware/flash.bin

*** Keywords ***
Create AST2600 Machine With Flash
    Execute Command    mach create "ast2600"
    Execute Command    machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl
    Execute Command    sysbus LoadBinary @${FLASH_BIN} 0x0

*** Test Cases ***
Full U-Boot Boots To Prompt
    [Documentation]    SPL loads FIT, full u-boot boots to => prompt.
    [Tags]             aspeed  uboot  boot  integration
    Create AST2600 Machine With Flash
    Create Terminal Tester    sysbus.uart5    timeout=8
    Start Emulation
    Wait For Line On Uart    U-Boot SPL
    Wait For Line On Uart    Trying to boot from RAM
    Wait For Line On Uart    U-Boot 2026

U-Boot Detects DRAM
    [Documentation]    Full u-boot reports DRAM size.
    [Tags]             aspeed  uboot  boot  integration
    Create AST2600 Machine With Flash
    Create Terminal Tester    sysbus.uart5    timeout=8
    Start Emulation
    Wait For Line On Uart    DRAM:

U-Boot Reaches Autoboot
    [Documentation]    U-boot reaches autoboot countdown.
    [Tags]             aspeed  uboot  boot  integration
    Create AST2600 Machine With Flash
    Create Terminal Tester    sysbus.uart5    timeout=10
    Start Emulation
    Wait For Line On Uart    Hit any key to stop autoboot
