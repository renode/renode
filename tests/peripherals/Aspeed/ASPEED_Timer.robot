*** Variables ***
# Timer 1 registers
${TMR1_STATUS}          0x00
${TMR1_RELOAD}          0x04
${TMR1_MATCH1}          0x08
${TMR1_MATCH2}          0x0C
# Timer 2 registers
${TMR2_STATUS}          0x10
${TMR2_RELOAD}          0x14
# Control and IRQ status
${CTRL}                 0x30
${IRQ_STS}              0x34

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read Timer Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    timer ReadDoubleWord ${offset}
    RETURN                  ${val}

Write Timer Register
    [Arguments]             ${offset}  ${value}
    Execute Command         timer WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Control Should Default To Zero
    [Documentation]         CTRL register at 0x30 should be 0 at reset
    [Tags]                  aspeed  timer  register
    Create AST2600 Machine
    ${val}=                 Read Timer Register  ${CTRL}
    Should Be Equal As Numbers  ${val}  0x0

Timer1 Reload Should Be Writable
    [Documentation]         Timer 1 reload register is read/write
    [Tags]                  aspeed  timer  register
    Create AST2600 Machine
    Write Timer Register    ${TMR1_RELOAD}  0x00100000
    ${val}=                 Read Timer Register  ${TMR1_RELOAD}
    Should Be Equal As Numbers  ${val}  0x00100000

Timer1 Match Registers Should Be Writable
    [Documentation]         Timer 1 match1/match2 are read/write
    [Tags]                  aspeed  timer  register
    Create AST2600 Machine
    Write Timer Register    ${TMR1_MATCH1}  0x00050000
    Write Timer Register    ${TMR1_MATCH2}  0x00010000
    ${m1}=                  Read Timer Register  ${TMR1_MATCH1}
    ${m2}=                  Read Timer Register  ${TMR1_MATCH2}
    Should Be Equal As Numbers  ${m1}  0x00050000
    Should Be Equal As Numbers  ${m2}  0x00010000

Timer1 Enable Should Set Counter To Reload
    [Documentation]         Enabling timer should initialize counter to reload value
    [Tags]                  aspeed  timer  register
    Create AST2600 Machine
    # Set reload first
    Write Timer Register    ${TMR1_RELOAD}  0x000F4240
    # Enable timer 1: bit 0 of CTRL
    Write Timer Register    ${CTRL}  0x1
    # Status should be near reload value
    ${val}=                 Read Timer Register  ${TMR1_STATUS}
    Should Not Be Equal As Numbers  ${val}  0x0

Timer2 Should Be Independent
    [Documentation]         Timer 2 operates independently from Timer 1
    [Tags]                  aspeed  timer  register
    Create AST2600 Machine
    Write Timer Register    ${TMR1_RELOAD}  0x11111111
    Write Timer Register    ${TMR2_RELOAD}  0x22222222
    ${r1}=                  Read Timer Register  ${TMR1_RELOAD}
    ${r2}=                  Read Timer Register  ${TMR2_RELOAD}
    Should Be Equal As Numbers  ${r1}  0x11111111
    Should Be Equal As Numbers  ${r2}  0x22222222

IRQ Status Should Default To Zero
    [Documentation]         IRQ status at 0x34 should be 0 at reset
    [Tags]                  aspeed  timer  register
    Create AST2600 Machine
    ${val}=                 Read Timer Register  ${IRQ_STS}
    Should Be Equal As Numbers  ${val}  0x0

IRQ Status Should Be W1C
    [Documentation]         Writing 1 to IRQ status bits should clear them
    [Tags]                  aspeed  timer  register
    Create AST2600 Machine
    # Enable timer 1 with overflow IRQ (bit 2 = overflow irq enable)
    Write Timer Register    ${TMR1_RELOAD}  0x00000001
    Write Timer Register    ${CTRL}  0x5
    # Read status a few times to trigger overflow
    ${val}=                 Read Timer Register  ${TMR1_STATUS}
    ${val}=                 Read Timer Register  ${TMR1_STATUS}
    ${val}=                 Read Timer Register  ${TMR1_STATUS}
    # Clear IRQ status
    Write Timer Register    ${IRQ_STS}  0xFF
    ${sts}=                 Read Timer Register  ${IRQ_STS}
    Should Be Equal As Numbers  ${sts}  0x0
