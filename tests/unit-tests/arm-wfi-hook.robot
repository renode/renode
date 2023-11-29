*** Variables ***
${PLATFORM}                         @platforms/cpus/cortex-a53-gicv2.repl
${LOG_WFI_ENTER}                    WFI_ENTER
${LOG_WFI_END}                      WFI_EXIT

*** Keywords ***
Assert PC Equals
    [Arguments]                     ${expected}
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Integers     ${pc}  ${expected}

Assert Enter In Logs
    Wait For Log Entry              ${LOG_WFI_ENTER}
    # Should not show duplicate Enter message
    Should Not Be In Log            ${LOG_WFI_ENTER}

Assert End In Logs
    Wait For Log Entry              ${LOG_WFI_END}
    # Should not show duplicate Exit message
    Should Not Be In Log            ${LOG_WFI_END}

*** Test Cases ***
Should Invoke Interrupt Hooks
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 using sysbus

    # Create infinite loop with WFI
    Execute Command                 sysbus WriteDoubleWord 0x1000 0xD503207F  # wfi
    Execute Command                 sysbus WriteDoubleWord 0x1004 0x17FFFFFF  # b to 0x1000
    Execute Command                 cpu PC 0x1000

    Execute Command                 cpu AddHookAtWfiStateChange 'self.Log(LogLevel.Info, "${LOG_WFI_ENTER}" if isInWfi else "${LOG_WFI_END}" )'

    Create Log Tester               1
    Start Emulation

    Assert Enter In Logs
    # Trigger interrupt in CPU
    Execute Command                 cpu OnGPIO 0 true
    Assert End In Logs

    # Deactivate interrupt line, so the CPU enters WFI state again
    Execute Command                 cpu OnGPIO 0 false
    Assert Enter In Logs

    # Ensure that the hook triggers after Reset
    Execute Command                 cpu Reset
    # After reset time doesn't flow
    Wait For Log Entry              ${LOG_WFI_END}
