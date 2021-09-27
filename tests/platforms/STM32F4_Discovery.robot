*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.usart2

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

Should Fire Update Event When Counting Up
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f4.repl
    Execute Command         sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4disco-timer-upcount.elf-g2d98d1b-s_1021132-961284be838516abea9db8302c9af2dcb67b482a

    Create Terminal Tester  sysbus.usart2

    Start Emulation

    Wait For Line On Uart   *** Timer2 Upcount Overflow Example ***
    Wait For Line On Uart   Tim2 IRQ enabled
    Wait For Line On Uart   Tim2 started
    Wait For Line On Uart   period elapsed callback
    Wait For Line On Uart   period elapsed callback
    Wait For Line On Uart   period elapsed callback

Should Fire Update Event When Counting Down
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f4.repl
    Execute Command         sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4disco-timer-downcount.elf-g2d98d1b-s_1021136-4995992fa219c49c38d7163da1381104c26c823a

    Create Terminal Tester  sysbus.usart2

    Start Emulation

    Wait For Line On Uart   *** Timer2 Downcount Overflow Example ***
    Wait For Line On Uart   Tim2 IRQ enabled
    Wait For Line On Uart   Tim2 started
    Wait For Line On Uart   period elapsed callback
    Wait For Line On Uart   period elapsed callback
    Wait For Line On Uart   period elapsed callback

