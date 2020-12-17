*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/A2_CV32E40P.repl

    Execute Command          sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Should Print Hello to UART
    Create Machine           arnold-pulp-hello-s_354412-d0f4d2860104d3bb1d4524c4ee76ef476bbe1d1e
    Create Terminal Tester   ${UART}

    Start Emulation

    Wait For Line On Uart    Hello !

Should Set GPIO Output to High
    Create Machine           arnold-pulp-gpio-s_380728-f9f273e2063a3ea7d4f9607cce4d7f12ea10bf63
    Execute Command          machine LoadPlatformDescriptionFromString "gpio: { 5 -> led@0 }; led: Miscellaneous.LED @ gpio 5"

    Execute Command          emulation CreateLEDTester "lt" sysbus.gpio.led

    Start Emulation

    Execute Command          lt AssertState True 1

Should Print to UART Using a Timer
    Create Machine            arnold-pulp-timer-s_365004-fc268eecd231afb88a571748c864b6c3ab0bcb5d
    Create Terminal Tester    ${UART}

    Set Test Variable         ${SLEEP_TIME}                 163
    Set Test Variable         ${SLEEP_TOLERANCE}            10
    Set Test Variable         ${REPEATS}                    20

    Start Emulation

    ${l}=               Create List
    ${MAX_SLEEP_TIME}=  Evaluate  ${SLEEP_TIME} + ${SLEEP_TOLERANCE}

    :FOR  ${i}  IN RANGE  0  ${REPEATS}
    \     ${r}        Wait For Line On Uart     Entered user handler
    \              Append To List            ${l}  ${r.timestamp}

    :FOR  ${i}  IN RANGE  1  ${REPEATS}
    \     ${i1}=  Get From List   ${l}                       ${i - 1}
    \     ${i2}=  Get From List   ${l}                       ${i}
    \     ${d}=   Evaluate        ${i2} - ${i1}
    \             Should Be True  ${d} >= ${SLEEP_TIME}      Too short sleep detected between entries ${i} and ${i + 1}: expected ${SLEEP_TIME}, got ${d}
    \             Should Be True  ${d} <= ${MAX_SLEEP_TIME}  Too long sleep detected between entires ${i} and ${i + 1}: expected ${SLEEP_TIME}, got ${d}

Should Echo Characters on UART
    Create Machine            arnold-pulp-echo-s_387724-9df7d9c7b43d7fa2740d07a44b36dcad35f2d796
    Create Terminal Tester    ${UART}

    Start Emulation

    Write Char On Uart        t
    Wait For Prompt On Uart   t
    Write Char On Uart        e
    Wait For Prompt On Uart   e
    Write Char On Uart        s
    Wait For Prompt On Uart   s
    Write Char On Uart        t
    Wait For Prompt On Uart   t
