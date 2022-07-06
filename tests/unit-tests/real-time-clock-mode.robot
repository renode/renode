*** Keywords ***
Create Machine
    Execute Command           using sysbus
    Execute Command           mach create

Machine And RTC DateTimes Should Be Equal
    ${rtc}=  Execute Command  rtc CurrentDateTime
    ${cur}=  Execute Command  machine RealTimeClockDateTime
    Should Be Equal           ${rtc}  ${cur}

Set RTC Mode
    [Arguments]    ${mode}
    Execute Command           machine RealTimeClockMode ${mode}

Should Support RTC Mode Changes
    [Arguments]    ${model}
    Create Machine
    Execute Command           machine LoadPlatformDescriptionFromString "rtc: Timers.${model} @ sysbus 0x0"

    # Check the initial state.
    Machine And RTC DateTimes Should Be Equal

    Set RTC Mode              HostTimeLocal
    Machine And RTC DateTimes Should Be Equal

    Set RTC Mode              HostTimeUTC
    Machine And RTC DateTimes Should Be Equal

    Set RTC Mode              Epoch
    Machine And RTC DateTimes Should Be Equal

*** Test Cases ***
AmbiqApollo4_RTC Should Support RTC Mode Changes
    Should Support RTC Mode Changes    AmbiqApollo4_RTC

MAX32650_RTC Should Support RTC Mode Changes
    Should Support RTC Mode Changes    MAX32650_RTC
