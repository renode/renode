*** Variables ***
${HASH_SRC}         0x020
${HASH_DIGEST}      0x024
${HASH_KEY_BUFF}    0x028
${HASH_SRC_LEN}     0x02C
${HASH_CMD}         0x030
${STATUS}           0x01C
${CRYPT_CMD}        0x010

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read HACE Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    hace ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write HACE Register
    [Arguments]             ${offset}  ${value}
    Execute Command         hace WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With HACE
    [Documentation]         Verify HACE is accessible after platform load
    [Tags]                  aspeed  hace  platform
    Create AST2600 Machine
    ${val}=                 Read HACE Register  ${STATUS}
    Should Be Equal As Numbers  ${val}  0x0

All Registers Should Reset To Zero
    [Documentation]         All HACE registers default to 0 on reset
    [Tags]                  aspeed  hace  register
    Create AST2600 Machine
    ${val}=                 Read HACE Register  ${HASH_SRC}
    Should Be Equal As Numbers  ${val}  0x0
    ${val}=                 Read HACE Register  ${HASH_DIGEST}
    Should Be Equal As Numbers  ${val}  0x0
    ${val}=                 Read HACE Register  ${HASH_SRC_LEN}
    Should Be Equal As Numbers  ${val}  0x0
    ${val}=                 Read HACE Register  ${HASH_CMD}
    Should Be Equal As Numbers  ${val}  0x0

Source Address Should Be Masked
    [Documentation]         HASH_SRC masked to 0x7FFFFFFF (31-bit)
    [Tags]                  aspeed  hace  register
    Create AST2600 Machine
    Write HACE Register     ${HASH_SRC}  0xFFFFFFFF
    ${val}=                 Read HACE Register  ${HASH_SRC}
    Should Be Equal As Numbers  ${val}  0x7FFFFFFF

Digest Address Should Be Aligned
    [Documentation]         HASH_DIGEST masked to 0x7FFFFFF8 (8-byte aligned)
    [Tags]                  aspeed  hace  register
    Create AST2600 Machine
    Write HACE Register     ${HASH_DIGEST}  0xFFFFFFFF
    ${val}=                 Read HACE Register  ${HASH_DIGEST}
    Should Be Equal As Numbers  ${val}  0x7FFFFFF8

Source Length Should Be Masked
    [Documentation]         HASH_SRC_LEN masked to 0x0FFFFFFF (28-bit)
    [Tags]                  aspeed  hace  register
    Create AST2600 Machine
    Write HACE Register     ${HASH_SRC_LEN}  0xFFFFFFFF
    ${val}=                 Read HACE Register  ${HASH_SRC_LEN}
    Should Be Equal As Numbers  ${val}  0x0FFFFFFF

Hash Command Should Be Masked
    [Documentation]         HASH_CMD masked to 0x00147FFF
    [Tags]                  aspeed  hace  register
    Create AST2600 Machine
    Write HACE Register     ${HASH_CMD}  0xFFFFFFFF
    ${val}=                 Read HACE Register  ${HASH_CMD}
    Should Be Equal As Numbers  ${val}  0x00147FFF

Status W1C Should Clear Hash IRQ
    [Documentation]         Writing 1 to bit 9 clears HASH_IRQ
    [Tags]                  aspeed  hace  interrupt
    Create AST2600 Machine
    # Trigger a hash to set the IRQ bit (SHA256 on zero-length)
    Write HACE Register     ${HASH_SRC_LEN}  0x0
    Write HACE Register     ${HASH_CMD}  0x050
    ${val}=                 Read HACE Register  ${STATUS}
    # HASH_IRQ bit (bit 9) should be set
    ${irq_bit}=             Evaluate  (${val} >> 9) & 1
    Should Be Equal As Numbers  ${irq_bit}  1
    # Clear via W1C
    Write HACE Register     ${STATUS}  0x200
    ${val}=                 Read HACE Register  ${STATUS}
    Should Be Equal As Numbers  ${val}  0x0

Key Buffer Address Should Be Masked
    [Documentation]         HASH_KEY_BUFF masked to 0x7FFFFFF8
    [Tags]                  aspeed  hace  register
    Create AST2600 Machine
    Write HACE Register     ${HASH_KEY_BUFF}  0xFFFFFFFF
    ${val}=                 Read HACE Register  ${HASH_KEY_BUFF}
    Should Be Equal As Numbers  ${val}  0x7FFFFFF8
