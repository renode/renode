*** Variables ***
${CMD}              0x008
${INT_CTRL}         0x018
${INT_STS}          0x01C
${WR_DATA0}         0x020
${RD_DATA0}         0x030
${CMD_FIRE}         0x1
${INT_CMD_DONE}     0x1
${PECI_SUCCESS}     0x40

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read PECI Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    peci ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write PECI Register
    [Arguments]             ${offset}  ${value}
    Execute Command         peci WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With PECI
    [Documentation]         Verify PECI is accessible after platform load
    [Tags]                  aspeed  peci  platform
    Create AST2600 Machine
    ${val}=                 Read PECI Register  ${CMD}
    Should Be Equal As Numbers  ${val}  0x0

Fire Command Should Auto-Complete
    [Documentation]         Writing FIRE bit should auto-clear it
    [Tags]                  aspeed  peci  command
    Create AST2600 Machine
    Write PECI Register     ${CMD}  ${CMD_FIRE}
    ${val}=                 Read PECI Register  ${CMD}
    ${fire}=                Evaluate  ${val} & 0x1
    Should Be Equal As Numbers  ${fire}  0x0

Fire Should Set CMD_DONE In Interrupt Status
    [Documentation]         Auto-complete sets CMD_DONE bit
    [Tags]                  aspeed  peci  interrupt
    Create AST2600 Machine
    Write PECI Register     ${CMD}  ${CMD_FIRE}
    ${val}=                 Read PECI Register  ${INT_STS}
    ${done}=                Evaluate  ${val} & 0x1
    Should Be Equal As Numbers  ${done}  ${INT_CMD_DONE}

Fire Should Return Success Code In Read Buffer
    [Documentation]         Auto-complete writes 0x40 to RD_DATA0
    [Tags]                  aspeed  peci  command
    Create AST2600 Machine
    Write PECI Register     ${CMD}  ${CMD_FIRE}
    ${val}=                 Read PECI Register  ${RD_DATA0}
    Should Be Equal As Numbers  ${val}  ${PECI_SUCCESS}

Interrupt Status Should Be W1C
    [Documentation]         Writing 1 clears INT_STS bits
    [Tags]                  aspeed  peci  interrupt
    Create AST2600 Machine
    Write PECI Register     ${CMD}  ${CMD_FIRE}
    ${val}=                 Read PECI Register  ${INT_STS}
    Should Not Be Equal As Numbers  ${val}  0x0
    Write PECI Register     ${INT_STS}  ${INT_CMD_DONE}
    ${val}=                 Read PECI Register  ${INT_STS}
    Should Be Equal As Numbers  ${val}  0x0

Write Data Buffer Should Be Writable
    [Documentation]         WR_DATA0 is a normal R/W register
    [Tags]                  aspeed  peci  register
    Create AST2600 Machine
    Write PECI Register     ${WR_DATA0}  0xDEADBEEF
    ${val}=                 Read PECI Register  ${WR_DATA0}
    Should Be Equal As Numbers  ${val}  0xDEADBEEF

Int Control Should Be Writable
    [Documentation]         INT_CTRL register is R/W
    [Tags]                  aspeed  peci  register
    Create AST2600 Machine
    Write PECI Register     ${INT_CTRL}  0x00000001
    ${val}=                 Read PECI Register  ${INT_CTRL}
    Should Be Equal As Numbers  ${val}  0x1
