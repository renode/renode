*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BLINKY_ELF}                       ${URI}/zephyr-blinky.elf-s_409892-ff40b96865d6d6a7af51989180bb74dc21240a91
${BUTTON_ELF}                       ${URI}/zephyr-button.elf-s_416536-a09e3bb98514ac3318664fe7572a0fca77dd8534
${UART}                             sysbus.uart0
${PLATFORM}                         @platforms/boards/sam4s_xplained.repl

*** Keywords ***
Prepare Machine
    [Arguments]                     ${elf}
    Execute Command                 using sysbus
    Execute Command                 mach create "sam4s_xplained"

    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 sysbus LoadELF ${elf}

*** Test Cases ***
Should Blink Led
    Prepare Machine                 ${BLINKY_ELF}

    Create Terminal Tester          ${UART}                                       defaultPauseEmulation=True
    Create LED Tester               sysbus.pioC.LED                               defaultTimeout=1

    Wait For Line On Uart           *** Booting Zephyr OS                         includeUnfinishedLine=true
    Wait For Line On Uart           LED state: (ON|OFF)                           treatAsRegex=true

    Assert LED Is Blinking          testDuration=8  onDuration=1  offDuration=1  pauseEmulation=true

Should Handle Button Press
    Prepare Machine                 ${BUTTON_ELF}
    Create Terminal Tester          ${UART}                                       defaultPauseEmulation=True
    Wait For Line On Uart           Press the button
    Test If Uart Is Idle            1
    Execute Command                 sysbus.pioA.Button Press
    Test If Uart Is Idle            1
    Execute Command                 sysbus.pioA.Button Release
    Wait For Line On Uart           Button pressed
    Test If Uart Is Idle            1
    Execute Command                 sysbus.pioA.Button PressAndRelease
    Wait For Line On Uart           Button pressed
