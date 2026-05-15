*** Variables ***
${STATUS}               0x00
${RELOAD}               0x04
${RESTART}              0x08
${CTRL}                 0x0C
${TIMEOUT_STS}          0x10
${RESET_WIDTH}          0x18

${DEFAULT_STATUS}       0x014FB180
${DEFAULT_RELOAD}       0x014FB180
${RESTART_MAGIC}        0x4755

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read WDT Register
    [Arguments]             ${wdt}  ${offset}
    ${val}=  Execute Command    ${wdt} ReadDoubleWord ${offset}
    RETURN                  ${val}

Write WDT Register
    [Arguments]             ${wdt}  ${offset}  ${value}
    Execute Command         ${wdt} WriteDoubleWord ${offset} ${value}

*** Test Cases ***
WDT1 Status Should Have Default Value
    [Documentation]         WDT00 should return 0x014FB180 at reset
    [Tags]                  aspeed  wdt  register
    Create AST2600 Machine
    ${val}=                 Read WDT Register  wdt1  ${STATUS}
    Should Be Equal As Numbers  ${val}  ${DEFAULT_STATUS}

WDT1 Reload Should Have Default Value
    [Documentation]         WDT04 should return 0x014FB180 at reset
    [Tags]                  aspeed  wdt  register
    Create AST2600 Machine
    ${val}=                 Read WDT Register  wdt1  ${RELOAD}
    Should Be Equal As Numbers  ${val}  ${DEFAULT_RELOAD}

WDT1 Restart Should Reload Counter
    [Documentation]         Writing 0x4755 to WDT08 copies RELOAD into STATUS
    [Tags]                  aspeed  wdt  register
    Create AST2600 Machine
    # Set a custom reload value
    Write WDT Register      wdt1  ${RELOAD}  0x12345678
    # Write restart magic
    Write WDT Register      wdt1  ${RESTART}  ${RESTART_MAGIC}
    # STATUS should now equal RELOAD
    ${val}=                 Read WDT Register  wdt1  ${STATUS}
    Should Be Equal As Numbers  ${val}  0x12345678

WDT1 Control Should Be Writable
    [Documentation]         WDT0C is read/write
    [Tags]                  aspeed  wdt  register
    Create AST2600 Machine
    Write WDT Register      wdt1  ${CTRL}  0x17
    ${val}=                 Read WDT Register  wdt1  ${CTRL}
    # AST2600 sanitize clears bits [9:7]
    Should Be Equal As Numbers  ${val}  0x17

WDT1 Reset Width Should Default To 0xFF
    [Documentation]         WDT18 resets to 0xFF
    [Tags]                  aspeed  wdt  register
    Create AST2600 Machine
    ${val}=                 Read WDT Register  wdt1  ${RESET_WIDTH}
    Should Be Equal As Numbers  ${val}  0xFF

All Four WDTs Should Be Accessible
    [Documentation]         All 4 WDT instances should have default status
    [Tags]                  aspeed  wdt  platform
    Create AST2600 Machine
    ${val1}=                Read WDT Register  wdt1  ${STATUS}
    ${val2}=                Read WDT Register  wdt2  ${STATUS}
    ${val3}=                Read WDT Register  wdt3  ${STATUS}
    ${val4}=                Read WDT Register  wdt4  ${STATUS}
    Should Be Equal As Numbers  ${val1}  ${DEFAULT_STATUS}
    Should Be Equal As Numbers  ${val2}  ${DEFAULT_STATUS}
    Should Be Equal As Numbers  ${val3}  ${DEFAULT_STATUS}
    Should Be Equal As Numbers  ${val4}  ${DEFAULT_STATUS}

Wrong Restart Magic Should Not Reset Counter
    [Documentation]         Writing non-magic value to WDT08 should not affect STATUS
    [Tags]                  aspeed  wdt  register
    Create AST2600 Machine
    # Write a custom reload
    Write WDT Register      wdt1  ${RELOAD}  0xAABBCCDD
    # Write wrong magic
    Write WDT Register      wdt1  ${RESTART}  0x1234
    # STATUS should still be default (not the reload value)
    ${val}=                 Read WDT Register  wdt1  ${STATUS}
    Should Be Equal As Numbers  ${val}  ${DEFAULT_STATUS}
