*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/cpus/nrf52840.repl

    Execute Command          sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Should Run ZephyrRTOS Shell Sample
    Create Machine            zephyr_shell_nrf52840.elf-s_1110556-9653ab7fffe1427c50fa6b837e55edab38925681
    Create Terminal Tester    ${UART}

    Execute Command           showAnalyzer ${UART}

    Start Emulation
    Wait For Prompt On Uart   uart:~$
    Write Line To Uart        demo ping
    Wait For Line On Uart     pong

Should Run Alarm Sample
    Create Machine            zephyr_alarm_nRF52840.elf-s_489392-49a2ec3fda2f0337fe72521f08e51ecb0fd8d616
    Create Terminal Tester    ${UART}

    Execute Command           showAnalyzer ${UART}

    Start Emulation
    
    Wait For Line On Uart     !!! Alarm !!!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:02

    Wait For Line On Uart     !!! Alarm !!!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:06

