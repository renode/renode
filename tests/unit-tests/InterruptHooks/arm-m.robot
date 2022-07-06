*** Variables ***
${PLATFROM}                     @platforms/boards/stm32f7_discovery-bb.repl
${BIN}                          @https://dl.antmicro.com/projects/renode/stm32f746g_disco--zephyr-custom_gpio_button.elf-s_302336-4b097ec2f848449980149053eafcbae55beeacdb
${LOG_KWD_START}                INTERRUPT_STARTED
${LOG_KWD_END}                  INTERRUPT_ENDED

*** Test Cases ***
Should Invoke Interrupt Hooks
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescription ${PLATFROM}
    Execute Command             sysbus LoadELF ${BIN}

    Execute Command             sysbus.cpu AddHookAtInterruptBegin 'self.Log(LogLevel.Info, "${LOG_KWD_START}")'
    Execute Command             sysbus.cpu AddHookAtInterruptEnd 'self.Log(LogLevel.Info, "${LOG_KWD_END}")'

    Create Log Tester           1
    Start Emulation
    
    Should Not Be In Log        ${LOG_KWD_START}
    Should Not Be In Log        ${LOG_KWD_END}

    Execute Command             sysbus.gpioPortI OnGPIO 11 true  # This presses the button
    Wait For Log Entry          ${LOG_KWD_START}
    Wait For Log Entry          ${LOG_KWD_END}

    Should Not Be In Log        ${LOG_KWD_START}
    Should Not Be In Log        ${LOG_KWD_END}
