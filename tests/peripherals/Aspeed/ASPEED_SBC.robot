*** Variables ***
${PROT}         0x000
${CMD}          0x004
${ADDR}         0x010
${STATUS}       0x014
${CAMP1}        0x020
${CAMP2}        0x024
${QSR}          0x040

# OTP_IDLE (bit 2) | OTP_MEM_IDLE (bit 1) = 0x06
${STATUS_IDLE}  0x6

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read SBC Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    sbc ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write SBC Register
    [Arguments]             ${offset}  ${value}
    Execute Command         sbc WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With SBC
    [Documentation]         Verify SBC is accessible after platform load
    [Tags]                  aspeed  sbc  platform
    Create AST2600 Machine
    ${val}=                 Read SBC Register  ${STATUS}
    Should Not Be Equal As Numbers  ${val}  0xFFFFFFFF

Status Should Report Idle And Not Secured
    [Documentation]         R_STATUS should have OTP idle bits set, SECURE_BOOT_EN clear
    [Tags]                  aspeed  sbc  register
    Create AST2600 Machine
    ${val}=                 Read SBC Register  ${STATUS}
    Should Be Equal As Numbers  ${val}  ${STATUS_IDLE}

Status Should Be Read-Only
    [Documentation]         Writing to R_STATUS should be rejected
    [Tags]                  aspeed  sbc  register
    Create AST2600 Machine
    Write SBC Register      ${STATUS}  0xFFFFFFFF
    ${val}=                 Read SBC Register  ${STATUS}
    Should Be Equal As Numbers  ${val}  ${STATUS_IDLE}

QSR Should Default To Zero
    [Documentation]         R_QSR should be 0 (no signing configured)
    [Tags]                  aspeed  sbc  register
    Create AST2600 Machine
    ${val}=                 Read SBC Register  ${QSR}
    Should Be Equal As Numbers  ${val}  0x0

QSR Should Be Read-Only
    [Documentation]         Writing to R_QSR should be rejected
    [Tags]                  aspeed  sbc  register
    Create AST2600 Machine
    Write SBC Register      ${QSR}  0xDEADBEEF
    ${val}=                 Read SBC Register  ${QSR}
    Should Be Equal As Numbers  ${val}  0x0

OTP Address Should Be Writable
    [Documentation]         R_ADDR is read-write
    [Tags]                  aspeed  sbc  register
    Create AST2600 Machine
    Write SBC Register      ${ADDR}  0x00000100
    ${val}=                 Read SBC Register  ${ADDR}
    Should Be Equal As Numbers  ${val}  0x100

OTP Command Should Maintain Idle
    [Documentation]         Writing a command should keep OTP idle (stub behavior)
    [Tags]                  aspeed  sbc  register  otp
    Create AST2600 Machine
    Write SBC Register      ${ADDR}  0x00000001
    Write SBC Register      ${CMD}  0x23b1e361
    ${val}=                 Read SBC Register  ${STATUS}
    Should Be Equal As Numbers  ${val}  ${STATUS_IDLE}
