*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart2

*** Test Cases ***
Run Zephyr Hello World
    Execute Command           set bin @https://dl.antmicro.com/projects/renode/stm32f4_discovery--zephyr-hello_world.elf-s_515008-2180a4018e82fcbc8821ef4330c9b5f3caf2dcdb
    Execute Command           include @scripts/single-node/stm32f4_discovery.resc

    Execute Command           showAnalyzer ${UART}
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Booting Zephyr OS
    Wait For Line On Uart     Hello World! stm32f4_disco

Configure RTC Alarm
    Execute Command           set bin @https://dl.antmicro.com/projects/renode/stm32f4_discovery--riot-tests_periph_rtc.elf-s_1249644-ca2effb6a0a8bcde39496b99bcb8b160a4ed292e
    Execute Command           include @scripts/single-node/stm32f4_discovery.resc

    Execute Command           showAnalyzer ${UART}
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Help: Press s to start test, r to print it is ready
    Write Char On Uart        s

    Wait For Line On Uart     This is RIOT!
    Wait For Line On Uart     RIOT RTC low-level driver test
    Wait For Line On Uart     This test will display 'Alarm!' every 2 seconds for 4 times

    Wait For Line On Uart     Alarm!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:02
       
    Wait For Line On Uart     Alarm!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:04

    Wait For Line On Uart     Alarm!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:06

    Wait For Line On Uart     Alarm!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:08

