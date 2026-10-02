*** Variables ***
${PROT_KEY}             0x000
${SILICON_REV}          0x004
${CLK_STOP1}            0x010
${CLK_STOP1_CLR}        0x014
${HW_STRAP1}            0x040
${RESET_CTRL1}          0x050
${HW_STRAP2}            0x510
${HW_STRAP_SEC}         0x500

${UNLOCK_KEY}           0x1688A8A8
${AST2600_A3_REV}       0x05030303

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read SCU Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    scu ReadDoubleWord ${offset}
    RETURN                  ${val}

Write SCU Register
    [Arguments]             ${offset}  ${value}
    Execute Command         scu WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load AST2600 Platform
    [Documentation]         Verify the AST2600 platform loads without errors
    [Tags]                  aspeed  scu  platform
    Create AST2600 Machine

Should Read Silicon Revision As AST2600-A3
    [Documentation]         SCU004 should return 0x05030303 (AST2600-A3)
    [Tags]                  aspeed  scu  register
    Create AST2600 Machine
    ${rev}=                 Read SCU Register  ${SILICON_REV}
    Should Be Equal As Numbers  ${rev}  ${AST2600_A3_REV}

Silicon Revision Should Be Read-Only
    [Documentation]         Writing to SCU004 should not change the value
    [Tags]                  aspeed  scu  register  readonly
    Create AST2600 Machine
    Write SCU Register      ${SILICON_REV}  0xDEADBEEF
    ${rev}=                 Read SCU Register  ${SILICON_REV}
    Should Be Equal As Numbers  ${rev}  ${AST2600_A3_REV}

Protection Key Should Default To Locked
    [Documentation]         SCU000 should read 0 at reset (locked)
    [Tags]                  aspeed  scu  register
    Create AST2600 Machine
    ${key}=                 Read SCU Register  ${PROT_KEY}
    Should Be Equal As Numbers  ${key}  0x0

Should Unlock SCU With Protection Key
    [Documentation]         Writing 0x1688A8A8 to SCU000 unlocks the SCU
    [Tags]                  aspeed  scu  register  protection
    Create AST2600 Machine
    Write SCU Register      ${PROT_KEY}  ${UNLOCK_KEY}
    ${key}=                 Read SCU Register  ${PROT_KEY}
    Should Be Equal As Numbers  ${key}  ${UNLOCK_KEY}

Clock Stop Register Should Be Writable
    [Documentation]         SCU010 clock stop control is read/write
    [Tags]                  aspeed  scu  register  clock
    Create AST2600 Machine
    ${initial}=             Read SCU Register  ${CLK_STOP1}
    Should Be Equal As Numbers  ${initial}  0x0
    Write SCU Register      ${CLK_STOP1}  0x0000FFFF
    ${val}=                 Read SCU Register  ${CLK_STOP1}
    Should Be Equal As Numbers  ${val}  0x0000FFFF

Reset Control Register Should Be Writable
    [Documentation]         SCU050 system reset control is read/write
    [Tags]                  aspeed  scu  register
    Create AST2600 Machine
    Write SCU Register      ${RESET_CTRL1}  0x12345678
    ${val}=                 Read SCU Register  ${RESET_CTRL1}
    Should Be Equal As Numbers  ${val}  0x12345678

Hardware Strap 1 Should Be Read-Only
    [Documentation]         SCU040 hardware strap is factory-programmed, read-only
    [Tags]                  aspeed  scu  register  readonly
    Create AST2600 Machine
    ${initial}=             Read SCU Register  ${HW_STRAP1}
    Write SCU Register      ${HW_STRAP1}  0xFFFFFFFF
    ${after}=               Read SCU Register  ${HW_STRAP1}
    Should Be Equal As Numbers  ${after}  ${initial}

Hardware Strap 2 Should Be Read-Only
    [Documentation]         SCU200 hardware strap 2 is factory-programmed, read-only
    [Tags]                  aspeed  scu  register  readonly
    Create AST2600 Machine
    ${initial}=             Read SCU Register  ${HW_STRAP2}
    Write SCU Register      ${HW_STRAP2}  0xFFFFFFFF
    ${after}=               Read SCU Register  ${HW_STRAP2}
    Should Be Equal As Numbers  ${after}  ${initial}

Hardware Strap Security Should Be Read-Only
    [Documentation]         SCU500 hardware strap security is read-only
    [Tags]                  aspeed  scu  register  readonly
    Create AST2600 Machine
    ${initial}=             Read SCU Register  ${HW_STRAP_SEC}
    Write SCU Register      ${HW_STRAP_SEC}  0xFFFFFFFF
    ${after}=               Read SCU Register  ${HW_STRAP_SEC}
    Should Be Equal As Numbers  ${after}  ${initial}
