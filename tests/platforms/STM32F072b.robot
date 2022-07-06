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
    
    Execute Command          ${BUTTON} Press
    Sleep                    0.3
    Execute Command          ${BUTTON} Release
    Wait For Line On Uart    Button pressed at   

    # LED matches button state and should not change until after the button is pressed/released
    Execute Command          emulation CreateLEDTester "led_tester" ${LED}
    Execute Command          ${BUTTON} Press
    Execute Command          led_tester AssertAndHoldState false ${LED_DELAY} ${LED_DELAY}
    Execute Command          ${BUTTON} Release
    Execute Command          led_tester AssertAndHoldState true ${LED_DELAY} ${LED_DELAY}
    Execute Command          ${BUTTON} Press
    Execute Command          led_tester AssertAndHoldState false ${LED_DELAY} ${LED_DELAY}
    Execute Command          ${BUTTON} Release

Should Read ADC
    Create Machine           stm32f072b--zephyr-adc.elf-s_567632-591075b4dc78decfb7ccab1d7a2477a78edc710e

    Create Terminal Tester   ${UART}

    Start Emulation
    
    Wait For Line On Uart    Booting Zephyr

    Execute Command          sysbus.adc SetDefaultValue 600
    Wait For Line On Uart    ADC reading: 745

    Execute Command          sysbus.adc SetDefaultValue 1200
    Wait For Line On Uart    ADC reading: 1489

Should Run stm32f0-crc-test Application
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/stm32f072b_discovery.repl
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f0-crc-test.elf-s_915148-a4b6b448dca6f24df573f23cd05224d11f9d83ff
    Create Terminal Tester   ${UART}

    Start Emulation

    Wait For Line On Uart    test result: ok. 840 passed; 0 failed
