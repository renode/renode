*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Test Cases ***
Should Handle Version Command In Zephyr Shell
    Execute Command          include @scripts/single-node/stm32l072.resc

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Prompt On Uart  $
    Write Line To Uart       version
    Wait For Line On Uart    Zephyr version 2.6.99
