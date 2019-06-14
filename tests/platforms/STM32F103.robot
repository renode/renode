*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${RENODEKEYWORDS}

*** Test Cases ***
Should Handle Button Press
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f103.repl
    Execute Command         machine LoadPlatformDescriptionFromString "button: Miscellaneous.Button @ gpioPortC 13 { IRQ -> gpioPortC@13 }"
    Execute Command         sysbus LoadELF @http://antmicro.com/projects/renode/zephyr-stm32f103-button.elf-s_276760-1bf32c99bbb3c01d81e13ca68118eaf08b2a815f

    Create Terminal Tester  sysbus.uart2

    Start Emulation

    Wait For Line On Uart   Press the user defined button on the board
    Test If Uart Is Idle    3
    Execute Command         sysbus.gpioPortC.button Press
    Test If Uart Is Idle    3
    Execute Command         sysbus.gpioPortC.button Release
    Wait For Line On Uart   Button pressed
    Test If Uart Is Idle    3
    Execute Command         sysbus.gpioPortC.button PressAndRelease
    Wait For Line On Uart   Button pressed
