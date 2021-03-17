*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.usart1
${LED}                        sysbus.gpioPortC.led
${BUTTON}                     sysbus.gpioPortA.button
${URI}                        @https://dl.antmicro.com/projects/renode
${LED_DELAY}                  1

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/stm32f072b_discovery.repl
    
    Execute Command          sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Should Run Zephyr Hello Sample
    Create Machine           stm32f072b_disco--zephyr-hello_world.elf-s_451704-a4d8c888e36c324dcc1dfde33bac33fc6ed3ed1b
    Create Terminal Tester   ${UART}
    Start Emulation
    
    Wait For Line On Uart    Hello World! stm32f072b_disco

Should Run Zephyr Console Echo Sample
    Create Machine           stm32f072b_disco--zephyr-echo.elf-s_544096-541b7b153ff0a9b30489bd1cc34e693c0ac8b9ea
    Create Terminal Tester   ${UART}

    Start Emulation

    Wait For Line On Uart    Start typing characters to see them echoed back
    Write Line To Uart       Echo working?      waitForEcho=true

Should Run Zephyr Blinky Sample
    Create Machine           stm32f072b_disco--zephyr-blinky.elf-s_460516-9452135ae6af4492bb284a6f88b196b1314909c8

    Execute Command          emulation CreateLEDTester "led_tester" ${LED}

    Start Emulation
    Execute Command          led_tester AssertState true ${LED_DELAY}
    Execute Command          led_tester AssertState false ${LED_DELAY}
    Execute Command          led_tester AssertState true ${LED_DELAY}
    Execute Command          led_tester AssertState false ${LED_DELAY}
    Execute Command          led_tester AssertState true ${LED_DELAY}
    Execute Command          led_tester AssertState false ${LED_DELAY}

Should Run Zephyr Button Sample
    Create Machine           stm32f072b_disco--zephyr-button.elf-s_466084-bd8983bad3182e3a36ca6120a629093bd24426c8
    Create Terminal Tester   ${UART}

    Start Emulation
    
    Execute Command          ${BUTTON} PressAndRelease
    Wait For Line On Uart    Button pressed at   

    # LED blinks when the button is held
    Execute Command          emulation CreateLEDTester "led_tester" ${LED}
    Execute Command          ${BUTTON} Press
    Execute Command          led_tester AssertState true ${LED_DELAY}
    Execute Command          led_tester AssertState false ${LED_DELAY}
    Execute Command          led_tester AssertState true ${LED_DELAY}
    Execute Command          led_tester AssertState false ${LED_DELAY}
    Execute Command          led_tester AssertState true ${LED_DELAY}
    Execute Command          ${BUTTON} Release

