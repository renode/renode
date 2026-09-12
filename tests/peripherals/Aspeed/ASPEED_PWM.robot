*** Variables ***
${GENERAL_CTRL}     0x000
${DUTY_CYCLE0}      0x004
${DUTY_CYCLE1}      0x008

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read PWM Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    pwm ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write PWM Register
    [Arguments]             ${offset}  ${value}
    Execute Command         pwm WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With PWM
    [Documentation]         Verify PWM is accessible after platform load
    [Tags]                  aspeed  pwm  platform
    Create AST2600 Machine
    ${val}=                 Read PWM Register  ${GENERAL_CTRL}
    Should Be Equal As Numbers  ${val}  0x0

General Control Register Should Be Writable
    [Documentation]         PWM general control R/W
    [Tags]                  aspeed  pwm  register
    Create AST2600 Machine
    Write PWM Register      ${GENERAL_CTRL}  0x00000001
    ${val}=                 Read PWM Register  ${GENERAL_CTRL}
    Should Be Equal As Numbers  ${val}  0x1

Duty Cycle Registers Should Be Writable
    [Documentation]         All duty cycle registers are R/W
    [Tags]                  aspeed  pwm  register
    Create AST2600 Machine
    Write PWM Register      ${DUTY_CYCLE0}  0x12345678
    ${val}=                 Read PWM Register  ${DUTY_CYCLE0}
    Should Be Equal As Numbers  ${val}  0x12345678
    Write PWM Register      ${DUTY_CYCLE1}  0xAABBCCDD
    ${val}=                 Read PWM Register  ${DUTY_CYCLE1}
    Should Be Equal As Numbers  ${val}  0xAABBCCDD

All Registers Should Default To Zero
    [Documentation]         All PWM registers reset to 0
    [Tags]                  aspeed  pwm  register
    Create AST2600 Machine
    ${val}=                 Read PWM Register  0x000
    Should Be Equal As Numbers  ${val}  0x0
    ${val}=                 Read PWM Register  0x004
    Should Be Equal As Numbers  ${val}  0x0

Register Should Survive Multiple Writes
    [Documentation]         Last write wins
    [Tags]                  aspeed  pwm  register
    Create AST2600 Machine
    Write PWM Register      ${GENERAL_CTRL}  0x11111111
    Write PWM Register      ${GENERAL_CTRL}  0x22222222
    Write PWM Register      ${GENERAL_CTRL}  0x33333333
    ${val}=                 Read PWM Register  ${GENERAL_CTRL}
    Should Be Equal As Numbers  ${val}  0x33333333
