*** Variables ***
${PROT_KEY}             0x000
${CONFIG}               0x004
${ISR}                  0x050
${STATUS1}              0x060
${ECC_TEST_CTRL}        0x070
${PHY_STATUS}           0x400

${UNLOCK_KEY}           0xFC600309
# AST2600 1GiB: HW_VERSION=3[31:28], VGA=64MB[3:2], SIZE=2[1:0]
${DEFAULT_CONFIG}       0x3000000E
${PHY_PLL_LOCK}         0x10

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read SDMC Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    sdmc ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write SDMC Register
    [Arguments]             ${offset}  ${value}
    Execute Command         sdmc WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With SDMC
    [Documentation]         Verify SDMC is accessible after platform load
    [Tags]                  aspeed  sdmc  platform
    Create AST2600 Machine
    ${val}=                 Read SDMC Register  ${CONFIG}
    Should Not Be Equal As Numbers  ${val}  0x0

Config Should Report 1GiB DRAM
    [Documentation]         MCR04 should encode 1 GiB DRAM (index 2)
    [Tags]                  aspeed  sdmc  register
    Create AST2600 Machine
    ${val}=                 Read SDMC Register  ${CONFIG}
    Should Be Equal As Numbers  ${val}  ${DEFAULT_CONFIG}

Protection Key Should Default To Locked
    [Documentation]         MCR00 should read 0 at reset (locked)
    [Tags]                  aspeed  sdmc  register
    Create AST2600 Machine
    ${val}=                 Read SDMC Register  ${PROT_KEY}
    Should Be Equal As Numbers  ${val}  0x0

Should Unlock SDMC
    [Documentation]         Writing 0xFC600309 unlocks the SDMC
    [Tags]                  aspeed  sdmc  register  protection
    Create AST2600 Machine
    Write SDMC Register     ${PROT_KEY}  ${UNLOCK_KEY}
    ${val}=                 Read SDMC Register  ${PROT_KEY}
    # QEMU returns 0x01 for unlocked state, not the raw key value
    Should Be Equal As Numbers  ${val}  0x1

PHY PLL Lock Should Be Set
    [Documentation]         Status1 bit 4 (PHY PLL lock) should be set
    [Tags]                  aspeed  sdmc  register
    Create AST2600 Machine
    ${val}=                 Read SDMC Register  ${STATUS1}
    # Status1 resets to 0x10 (PLL lock, bit 4)
    Should Be Equal As Numbers  ${val}  ${PHY_PLL_LOCK}

PHY Status Should Report OK
    [Documentation]         PHY status at 0x400 should have bit 1 set (phy ok)
    [Tags]                  aspeed  sdmc  register
    Create AST2600 Machine
    ${val}=                 Read SDMC Register  ${PHY_STATUS}
    # Reset() writes 0x2 to PHY_STATUS
    Should Be Equal As Numbers  ${val}  0x2

Config Should Preserve ReadOnly Bits
    [Documentation]         Writing to MCR04 should not change HW_VERSION or DRAM_SIZE
    [Tags]                  aspeed  sdmc  register  readonly
    Create AST2600 Machine
    # First unlock
    Write SDMC Register     ${PROT_KEY}  ${UNLOCK_KEY}
    # Try to overwrite config
    Write SDMC Register     ${CONFIG}  0x00000000
    ${val}=                 Read SDMC Register  ${CONFIG}
    # DRAM_SIZE and HW_VERSION and VGA_APERTURE bits should still be set
    Should Be Equal As Numbers  ${val}  ${DEFAULT_CONFIG}
