*** Variables ***
${ALARM_REG}            0x14
${CONTROL_REG}          0x18
${STATUS_REG}           0x1C

*** Keywords ***
Create Machine
    Execute Command     mach create
    Execute Command     machine LoadPlatformDescriptionFromString "rtc: Timers.AndesATCRTC100 @ sysbus 0xf0600000"
    Execute Command     emulation SetGlobalAdvanceImmediately True

Interrupt Status Bit Should Be Set
    [Arguments]                         ${bit}
    ${status_val}=  Execute Command     rtc ReadDoubleWord ${STATUS_REG}
    ${is_set}=  Evaluate                bool(${status_val} & (1 << ${bit}))
    Should Be True                      ${is_set}


*** Test Cases ***
Time Should Pass Correctly
    Create Machine
    Execute Command                 rtc WriteDoubleWord ${CONTROL_REG} 1
    Execute Command                 emulation RunFor "00:02:43.000000000"
    ${time}=  Execute Command       rtc TimePassed
    Should Be Equal                 ${time.strip()}  00:02:43.000000000

Time Should Not Pass When RTC Is Not Enabled
    Create Machine
    Execute Command                 emulation RunFor "12"
    ${time}=  Execute Command       rtc TimePassed
    Should Be Equal                 ${time.strip()}  00:00:00.000000000

Alarm Should Trigger And Set IRQ
    Create Machine
    Execute Command                 rtc WriteDoubleWord ${CONTROL_REG} 0x5   # Enable and alarm interrupt enable
    Execute Command                 rtc WriteDoubleWord ${ALARM_REG} 5  # Alarm at 5 seconds passed

    Execute Command                 emulation RunFor "4"
    # Alarm Should not have triggered yet
    ${irq}=  Execute Command        rtc IRQ IsSet
    Should Be Equal                 ${irq.strip()}  False
    Execute Command                 emulation RunFor "1"
    ${irq}=  Execute Command        rtc IRQ IsSet
    Should Be Equal                 ${irq.strip()}  True

Pending Interrupts Should Be Set At Correct Times
    Create Machine
    Execute Command                     rtc WriteDoubleWord ${CONTROL_REG} 1
    # Initially only the Write Done bit should be set
    ${status_val}=  Execute Command     rtc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Numbers          ${status_val}  0x10000

    Execute Command                     emulation RunFor "00:00:00.500000000"
    Interrupt Status Bit Should Be Set  7  # Half second interrupt

    Execute Command                     emulation RunFor "00:00:00.500000000"
    Interrupt Status Bit Should Be Set  6  # Second Interrupt

    Execute Command                     emulation RunFor "00:00:59.000000000"
    Interrupt Status Bit Should Be Set  5  # Minute Interrupt

    Execute Command                     emulation RunFor "00:59:00.000000000"
    Interrupt Status Bit Should Be Set  4  # Hour Interrupt Interrupt
 
    # Not testing day interrupt as that takes an very long time, but verified manually
