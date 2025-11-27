*** Variables ***
${BIN}                      @https://dl.antmicro.com/projects/renode/zephyr-stm32h747i-display.elf-s_1312828-55334a5ed1b3104c7033b0f3f55e9eb451fafc71
${SHADOW_CONTROL}           0x24
${SHADOW_RELOAD_NOW}        0
${LINE_COUNT}               0xb4
${FIFO_UNDERRUN_INT}        2
${INTERRUPT_STATUS}         0x38

*** Keywords ***
Setup Machine
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32h743.repl
    Execute Command         machine LoadPlatformDescriptionFromString "button: Miscellaneous.Button @ gpioPortA { -> gpioPortA@0 }"
    Execute Command         sysbus LoadELF ${BIN}
    Execute Command         ltdc FramesPerVirtualSecond 1
    Create Terminal Tester  sysbus.usart1  timeout=45
    Wait For Line On Uart   Display starts
    Wait For Update

Wait For Update
    Execute Command         gpioPortA.button PressAndRelease
    Wait For Line On Uart   Display updated

Should Have FIFO Underrun Interrupt
    [Arguments]  ${yes}
    ${res}=                 Execute Command  ltdc ReadDoubleWord ${INTERRUPT_STATUS}
    ${int_bit}=             Evaluate  (${res}) & ${FIFO_UNDERRUN_INT}
    IF  ${yes}
        Should Not Be Equal As Integers  ${int_bit}  0
    ELSE
        Should Be Equal As Integers  ${int_bit}  0
    END

*** Test Cases ***
Should Emit FIFO Underrun Interrupt
    Setup Machine
    Execute Command         ltdc WriteDoubleWord ${LINE_COUNT} 0  # Set line count to 0
    Execute Command         ltdc WriteDoubleWord ${SHADOW_CONTROL} ${SHADOW_RELOAD_NOW}  # Reload shadow registers
    Sleep  1.5  # Wait for LTDC to redraw
    Should Have FIFO Underrun Interrupt  True

Should Shadow Registers
    Setup Machine
    ${og_line_count}=       Execute Command  ltdc ReadDoubleWord ${LINE_COUNT}
    Execute Command         ltdc WriteDoubleWord ${LINE_COUNT} 0  # Set line count to 0
    # Don't reload shadow
    Sleep  1.5  # Wait for LTDC to redraw
    Should Have FIFO Underrun Interrupt  False
    Execute Command         ltdc WriteDoubleWord ${LINE_COUNT} ${og_line_count} # Restore line count
    Wait For Update
    Sleep  1.5  # Wait for LTDC to redraw
    Should Have FIFO Underrun Interrupt  False
    

