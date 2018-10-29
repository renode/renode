*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${CURDIR}/../../../src/Renode/RobotFrameworkEngine/renode-keywords.robot

*** Variables ***
${UART}                       sysbus.uart
${URI}                        @http://antmicro.com/projects/renode
${LED_DELAY}                  20000

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/miv-board.repl

    Execute Command          sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Should Blink Led Using Systick
    Create Machine            riscv-systick-blinky.elf-s_124348-0db68b9e854ad8953e038e24eddb2c428dd29beb
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
    Create Machine            riscv-interrupt-blinky.elf-s_133356-bb1bdea7e6e8cb559119908f8c7a7301f6116298
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

    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_2 Toggle
    Wait For Line On Uart     Key test example

Should Generate Interrupts On Gpio Rising Edge
    Create Machine            riscv-interrupt-blinky-gpio_interrupts.elf-s_134928-755a01d2896d56f62d40b8fd7620f4b019e114ba
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Wait For Line On Uart     GPIO1

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Wait For Line On Uart     GPIO2

Should Generate Interrupts On Gpio Falling Edge
    Create Machine            riscv-interrupt-blinky-gpio_interrupts-edge_negative.elf-s_134928-398f3ba48fd3c0c9ea323b4dfd7140d94ad56782
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Wait For Line On Uart     GPIO1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Wait For Line On Uart     GPIO2

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Test If Uart Is Idle      5

Should Generate Interrupts On Gpio Both Edges
    Create Machine            riscv-interrupt-blinky-gpio_interrupts-edge_both.elf-s_134928-d90257bf9f12b2133c1631952a379c1bebdfd97b
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Wait For Line On Uart     GPIO1

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Wait For Line On Uart     GPIO1

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Wait For Line On Uart     GPIO2

    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Wait For Line On Uart     GPIO2

Should Generate Interrupts On Gpio High Level
    Create Machine            riscv-interrupt-blinky-gpio_interrupts-level_high.elf-s_134928-e5184e20f1458b9784c10c48ad8fde0a738cfb65
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
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s
    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle

    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2

Should Generate Interrupts On Gpio Low Level
    Create Machine            riscv-interrupt-blinky-gpio_interrupts-level_low.elf-s_134928-3d7a09bb3cf434fde9bf9d2c29888ffb11861c0b
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     CoreTIMER and external Interrupt Example.
    Wait For Line On Uart     Observe the LEDs blinking on the board. The LED patterns changes every time a timer interrupt occurs

    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle

    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle
    Sleep                     1s
    Test If Uart Is Idle      5

    Execute Command           sysbus.gpioInputs.user_switch_0 Toggle
    Execute Command           sysbus.gpioInputs.user_switch_1 Toggle

    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2
    Wait For Line On Uart     GPIO1
    Wait For Line On Uart     GPIO2

