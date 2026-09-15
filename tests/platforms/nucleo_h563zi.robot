*** Variables ***
${UART}                             sysbus.usart3
${LED}                              sysbus.gpioPortB.GreenLED
${FIRMWARE}                         https://zephyr-dashboard.renode.io/zephyr/d3943eac8869e4c97718cda77d9ab5ef10daddfc/nucleo_h563zi/hello_world/hello_world.elf
${BLINKY_FIRMWARE}                  https://zephyr-dashboard.renode.io/zephyr/d3943eac8869e4c97718cda77d9ab5ef10daddfc/nucleo_h563zi/blinky/blinky.elf
${PLATFORM}                         platforms/boards/nucleo_h563zi.repl

*** Keywords ***
Create Machine
    [Arguments]                     ${elf}=${FIRMWARE}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}
    Execute Command                 sysbus LoadELF @${elf}

*** Test Cases ***
Should Print Hello World
    [Documentation]                 Zephyr hello_world sample boots and prints on USART3.
    ...                             Validates that the STM32H5 platform models support Zephyr's
    ...                             initialization path for the Nucleo-H563ZI board.
    Create Machine
    Create Terminal Tester          ${UART}  defaultPauseEmulation=True
    Wait For Line On Uart           Hello World!  timeout=5

Should Blink LED
    [Documentation]                 Zephyr blinky sample toggles the green LED (PB0) at 1 Hz.
    ...                             Validates GPIO output and timer-driven toggling.
    Create Machine                  ${BLINKY_FIRMWARE}
    Create Terminal Tester          ${UART}  defaultPauseEmulation=True
    Create LED Tester               ${LED}

    Wait For Line On Uart           LED state:  timeout=5
    Assert LED Is Blinking          testDuration=4  onDuration=1  offDuration=1
