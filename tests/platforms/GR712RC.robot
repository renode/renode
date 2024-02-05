*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/gr712rc.resc
${UART}                       sysbus.uart0
${GPIO_BIN}                   @https://dl.antmicro.com/projects/renode/gaisler-gr712rc--custom-rtems-gpio.prom.elf-s_145444-331f2e16b35e247c296b8e637f4901a46852c5ce

*** Keywords ***
Prepare Machine
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}  defaultPauseEmulation=True

Prepare Machine With Buttons And LEDs
    [Arguments]               ${bin}

    Execute Command           $bin = ${bin}
    Prepare Machine

    Execute Command           machine LoadPlatformDescriptionFromString "buttonLowLevel1: Miscellaneous.Button @ gpio1 1 { IRQ -> gpio1@1 }"
    Execute Command           machine LoadPlatformDescriptionFromString "buttonRisingEdge: Miscellaneous.Button @ gpio1 2 { IRQ -> gpio1@2 }"
    Execute Command           machine LoadPlatformDescriptionFromString "buttonFallingEdge: Miscellaneous.Button @ gpio1 3 { IRQ -> gpio1@3 }"
    Execute Command           machine LoadPlatformDescriptionFromString "buttonHighLevel: Miscellaneous.Button @ gpio1 4 { IRQ -> gpio1@4 }"
    Execute Command           machine LoadPlatformDescriptionFromString "buttonLowLevel2: Miscellaneous.Button @ gpio1 5 { IRQ -> gpio1@5 }"

    Execute Command           machine LoadPlatformDescriptionFromString "led: Miscellaneous.LED @ gpio1 7; gpio1: { 7 -> led@0 }"
    Execute Command           machine LoadPlatformDescriptionFromString "ledInputOnlyPin: Miscellaneous.LED @ gpio1 8; gpio1: { 8 -> ledInputOnlyPin@0 }"

    ${led}=                   Create LED Tester  sysbus.gpio1.led  0.05
    Set Suite Variable        ${led}  ${led}
    ${ledInputOnlyPin}=       Create LED Tester  sysbus.gpio1.ledInputOnlyPin  0.05
    Set Suite Variable        ${ledInputOnlyPin}  ${ledInputOnlyPin}

*** Test Cases ***
Should Run RTEMS Hello World with LEON3 PROM
    Prepare Machine

    Start Emulation

    Wait For Line On Uart     MKPROM2 boot loader v2.0.69
    Wait For Line On Uart     starting rtems-hello
    Wait For Line On Uart     Hello World over printk() on Debug console

Should Run RTEMS GPIO Interrupt Sample
    Prepare Machine With Buttons And LEDs  ${GPIO_BIN}

    # This low level-triggered ISR should fire continuously at first
    Wait For Line On Uart     GPIO_ISR: pin 1
    Wait For Line On Uart     GPIO_ISR: pin 1
    Should Not Be On Uart     TEST END  timeout=0.005

    Execute Command           gpio1.buttonLowLevel1 Press
    Wait For Line On Uart     TEST END

    Wait For Line On Uart     Interrupts configured, ready for next test

    # Rising-edge-triggered interrupt -> only once on rising edge
    Execute Command           gpio1.buttonRisingEdge Press
    Wait For Line On Uart     GPIO_ISR: pin 2
    Assert LED State          true  testerId=${led}
    # Input-only pin should not be affected
    Assert LED State          false  testerId=${ledInputOnlyPin}
    Should Not Be On Uart     GPIO_ISR: pin 2  timeout=0.005
    Execute Command           gpio1.buttonRisingEdge Release
    Should Not Be On Uart     GPIO_ISR: pin 2  timeout=0.005

    # Falling-edge-triggered interrupt -> only once on falling edge
    Execute Command           gpio1.buttonFallingEdge Press
    Should Not Be On Uart     GPIO_ISR: pin 3  timeout=0.005
    Execute Command           gpio1.buttonFallingEdge Release
    Wait For Line On Uart     GPIO_ISR: pin 3
    Assert LED State          false  testerId=${led}
    Assert LED State          false  testerId=${ledInputOnlyPin}
    Should Not Be On Uart     GPIO_ISR: pin 3  timeout=0.005

    # Pressing this button enables a low-level interrupt on pin 5. That one has a higher priority so
    # it gets printed continuously until we press the low-level button.
    Execute Command           gpio1.buttonHighLevel Press
    Should Not Be On Uart     GPIO_ISR: pin 4  timeout=0.005
    Wait For Line On Uart     GPIO_ISR: pin 5
    Wait For Line On Uart     GPIO_ISR: pin 5
    Execute Command           gpio1.buttonLowLevel2 Press
    Wait For Line On Uart     GPIO_ISR: pin 4
    Wait For Line On Uart     GPIO_ISR: pin 4
    Should Not Be On Uart     GPIO_ISR: pin 5  timeout=0.005

    # Finally we release the high-level-trigger button, after which nothing should be printed
    Execute Command           pause
    Execute Command           gpio1.buttonHighLevel Release
    Execute Command           emulation RunFor "0.005"
    Clear Terminal Tester Report
    Should Not Be On Uart     GPIO_ISR  timeout=0.005
