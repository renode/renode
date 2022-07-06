*** Variables ***
${UART}                       sysbus.uart
${URI}                        @https://dl.antmicro.com/projects/renode
${LED_DELAY}                  1

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/miv-board.repl

    Execute Command          sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Should Blink Led Using Systick
    Create Machine            riscv-systick-blinky.elf-s_125004-59e1fa0a46f86e8ccad8b5bbb4d92b8dfa009af3
    Create Terminal Tester    ${UART}

    Execute Command           emulation CreateLEDTester "led0_tester" sysbus.gpioOutputs.led0

    Start Emulation

    Wait For Line On Uart      System timer Blinky Example.

    # because of very fast LED switching this ends very soon
    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}
    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}
    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}
    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}
    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}

Should Blink Led Using CoreTimer
    Create Machine            riscv-interrupt-blinky.elf-s_135504-4fe164958c1fe3e89790f8d7d2824ba16182fa75
    Create Terminal Tester    ${UART}

    Execute Command           emulation CreateLEDTester "led0_tester" sysbus.gpioOutputs.led0

    Start Emulation

    Wait For Line On Uart      CoreTIMER and external Interrupt Example.

    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}
    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}
    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}
    Execute Command            led0_tester AssertState true ${LED_DELAY}
    Execute Command            led0_tester AssertState false ${LED_DELAY}

Should Run FreeRTOS Sample
    Create Machine            riscv-freertos-sample.elf-s_208404-40208b240e2d718e999a533e084f022628aec5d6
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Sample Demonstration of FreeRTOS port for Microsemi RISC-V processor.
    Wait For Line On Uart     Task - 2
    Wait For Line On Uart     Task - 1
    Wait For Line On Uart     Task - 2
    Wait For Line On Uart     Task - 1
    Wait For Line On Uart     Task - 2
    Wait For Line On Uart     Task - 1
    Wait For Line On Uart     Task - 2
    Wait For Line On Uart     Task - 1
    Wait For Line On Uart     Task - 2
    Wait For Line On Uart     Task - 1

Should Run LiteOS Port Sample
    Create Machine            riscv-liteos-port.elf-s_689820-e68d3bcf0a12c25daa66fc51e474281bcbed2fc7
    Create Terminal Tester    ${UART}

    # this magic PerformanceInMips is required for the test to pass
    # it is related to a bug in LiteOS (stack overflow and corruption) when interrupts happens in *wrong* moments
    Execute Command           sysbus.cpu PerformanceInMips 300
    Execute Command           showAnalyzer ${UART}

    Start Emulation

    Wait For Line On Uart     Los Inspect start.
    Wait For Line On Uart     Los Key example: please press the UserKey (SW2) key

    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_2 Toggle
    Wait For Line On Uart     Key test example

Should Run ZephyrRTOS Shell Sample
    Create Machine            shell-demo-miv.elf-s_803248-ea4ddb074325b2cc1aae56800d099c7cf56e592a
    Create Terminal Tester    ${UART}

    Execute Command           showAnalyzer ${UART}

    Start Emulation
    Wait For Prompt On Uart   uart:~
    Write Line To Uart        version
    Wait For Line On Uart     Zephyr version 1.13.99


Should Generate Interrupts On Gpio Rising Edge
    Create Machine            riscv-interrupt-blinky_gpio-interrupts-edge-positive.elf-s_135192-436f2656cbcff66f043ae6ba0b7977d0ee5e82a1
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Sleep                     1s
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s
    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Sleep                     1s
    Wait For Line On Uart     GPIO1
    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Sleep                     1s
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s
    Wait For Line On Uart     GPIO2

Should Generate Interrupts On Gpio Falling Edge
    Create Machine            riscv-interrupt-blinky_gpio-interrupts-edge-negative.elf-s_135192-19e453c25b09a2ecfeb7a8015588355f90ad8f02
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Wait For Line On Uart     GPIO1
    Sleep                     1s

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Wait For Line On Uart     GPIO2
    Sleep                     1s

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Test If Uart Is Idle      1

Should Generate Interrupts On Gpio Both Edges
    Create Machine            riscv-interrupt-blinky_gpio-interrupts-edge-both.elf-s_135192-1afc01350e4f0e17e2e556796cf577d2768636ec
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Wait For Line On Uart     GPIO1
    Sleep                     1s

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Wait For Line On Uart     GPIO1
    Sleep                     1s

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Wait For Line On Uart     GPIO2
    Sleep                     1s

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Wait For Line On Uart     GPIO2

Should Generate Interrupts On Gpio High Level
    Create Machine            riscv-interrupt-blinky_gpio-interrupts-level-high.elf-s_135168-e03e81b692982ad2f1f46085b9077fdfef62adf2
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Sleep                     1s
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s
    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Sleep                     1s
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s

    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2

Should Generate Interrupts On Gpio Low Level
    Create Machine            riscv-interrupt-blinky_gpio-interrupts-level-low.elf-s_135168-f570dad79ea5aa0bfe9aa1000f453f0f50f344df
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Sleep                     1s
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s

    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Sleep                     1s
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s
    Test If Uart Is Idle      1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Sleep                     1s
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s

    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2

