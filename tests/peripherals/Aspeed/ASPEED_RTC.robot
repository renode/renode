*** Variables ***
${COUNTER1}         0x000
${COUNTER2}         0x004
${ALARM}            0x008
${CONTROL}          0x010
${ALARM_STATUS}     0x014
${RTC_ENABLED}      0x1
${RTC_UNLOCKED}     0x2

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read RTC Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    rtc ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write RTC Register
    [Arguments]             ${offset}  ${value}
    Execute Command         rtc WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With RTC
    [Documentation]         Verify RTC is accessible after platform load
    [Tags]                  aspeed  rtc  platform
    Create AST2600 Machine
    ${val}=                 Read RTC Register  ${CONTROL}
    Should Be Equal As Numbers  ${val}  0x0

Counter Should Return Fixed Time When Enabled
    [Documentation]         Enabled RTC returns fixed date/time
    [Tags]                  aspeed  rtc  register
    Create AST2600 Machine
    Write RTC Register      ${CONTROL}  ${RTC_ENABLED}
    ${val}=                 Read RTC Register  ${COUNTER1}
    Should Be Equal As Numbers  ${val}  0x01000000

Counter2 Should Return Fixed Date When Enabled
    [Documentation]         Enabled RTC returns century=20, year=25, month=1
    [Tags]                  aspeed  rtc  register
    Create AST2600 Machine
    Write RTC Register      ${CONTROL}  ${RTC_ENABLED}
    ${val}=                 Read RTC Register  ${COUNTER2}
    Should Be Equal As Numbers  ${val}  0x00141901

Counters Should Return Zero When Disabled
    [Documentation]         Disabled RTC returns 0 for counters
    [Tags]                  aspeed  rtc  register
    Create AST2600 Machine
    ${val}=                 Read RTC Register  ${COUNTER1}
    Should Be Equal As Numbers  ${val}  0x0

Counters Should Be Writable When Unlocked
    [Documentation]         Unlock bit allows counter writes
    [Tags]                  aspeed  rtc  register
    Create AST2600 Machine
    Write RTC Register      ${CONTROL}  ${RTC_UNLOCKED}
    Write RTC Register      ${COUNTER1}  0xAABBCCDD
    ${val}=                 Read RTC Register  ${COUNTER1}
    Should Be Equal As Numbers  ${val}  0xAABBCCDD

Counters Should Not Be Writable When Locked
    [Documentation]         Locked counters ignore writes
    [Tags]                  aspeed  rtc  register
    Create AST2600 Machine
    Write RTC Register      ${COUNTER1}  0x12345678
    ${val}=                 Read RTC Register  ${COUNTER1}
    Should Be Equal As Numbers  ${val}  0x0

Alarm Status Should Be W1C
    [Documentation]         Alarm status cleared on write-1
    [Tags]                  aspeed  rtc  interrupt
    Create AST2600 Machine
    ${val}=                 Read RTC Register  ${ALARM_STATUS}
    Should Be Equal As Numbers  ${val}  0x0

Control Register Should Be Writable
    [Documentation]         Control register is R/W
    [Tags]                  aspeed  rtc  register
    Create AST2600 Machine
    Write RTC Register      ${CONTROL}  0x3
    ${val}=                 Read RTC Register  ${CONTROL}
    Should Be Equal As Numbers  ${val}  0x3
