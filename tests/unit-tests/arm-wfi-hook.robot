*** Variables ***
${PLATFORM}                         @platforms/cpus/cortex-a53-gicv2.repl
${LOG_WFI_ENTER}                    WFI_ENTER
${LOG_WFI_END}                      WFI_EXIT

*** Keywords ***
Create Platform
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 using sysbus

    # Create infinite loop with WFI
    Execute Command                 sysbus WriteDoubleWord 0x1000 0xD503207F  # wfi
    Execute Command                 sysbus WriteDoubleWord 0x1004 0xD503201F  # nop
    Execute Command                 sysbus WriteDoubleWord 0x1008 0xD503201F  # nop
    Execute Command                 sysbus WriteDoubleWord 0x100C 0xD503201F  # nop
    Execute Command                 sysbus WriteDoubleWord 0x1010 0x17FFFFFC  # b to 0x1000
    Execute Command                 cpu PC 0x1000

Assert SysReg Equals
    [Arguments]                     ${name}  ${expected}
    ${pc}=                          Execute Command  cpu GetSystemRegisterValue ${name}
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
    Create Platform

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

Should Reset Cpu From WFI Hook
    Create Platform

    # Preload TTBR0 with a nonsensical value, to check if it is cleared after reset
    Execute Command                 cpu SetSystemRegisterValue "TTBR0_EL1" 0xDEADBEEF
    Execute Command                 cpu AddHookAtWfiStateChange 'self.Log(LogLevel.Info, "${LOG_WFI_ENTER}" if isInWfi else "${LOG_WFI_END}" )'
    Execute Command                 cpu AddHookAtWfiStateChange 'self.Reset()'

    Create Log Tester               1
    Start Emulation

    # Can't use Assert X In Logs, since the Reset happens inside the hook
    Wait For Log Entry              ${LOG_WFI_ENTER}
    Wait For Log Entry              ${LOG_WFI_END}

    # CPU has been reset, so TTBR0 is set to 0
    Assert SysReg Equals            "TTBR0_EL1"  0x0
