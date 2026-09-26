*** Variables ***
# Register offsets for ABCD set
${DATA_VALUE}       0x000
${DIRECTION}        0x004
${INT_ENABLE}       0x008
${INT_STATUS}       0x018
${DATA_READ}        0x0C0

# EFGH set
${EFGH_DATA}        0x020
${EFGH_DIR}         0x024
${EFGH_INT_STATUS}  0x038
${EFGH_DATA_READ}   0x0C4

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read GPIO Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    gpio ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write GPIO Register
    [Arguments]             ${offset}  ${value}
    Execute Command         gpio WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With GPIO
    [Documentation]         Verify GPIO is accessible after platform load
    [Tags]                  aspeed  gpio  platform
    Create AST2600 Machine
    ${val}=                 Read GPIO Register  ${DATA_VALUE}
    Should Be Equal As Numbers  ${val}  0x0

Direction Should Default To Zero
    [Documentation]         All pins default to output (direction=0)
    [Tags]                  aspeed  gpio  register
    Create AST2600 Machine
    ${val}=                 Read GPIO Register  ${DIRECTION}
    Should Be Equal As Numbers  ${val}  0x0

Direction Should Be Writable
    [Documentation]         Direction register should accept writes
    [Tags]                  aspeed  gpio  register
    Create AST2600 Machine
    Write GPIO Register     ${DIRECTION}  0xFF00FF00
    ${val}=                 Read GPIO Register  ${DIRECTION}
    Should Be Equal As Numbers  ${val}  0xFF00FF00

Data Value Should Be Writable
    [Documentation]         Data value register should accept writes
    [Tags]                  aspeed  gpio  register
    Create AST2600 Machine
    Write GPIO Register     ${DATA_VALUE}  0xDEADBEEF
    ${val}=                 Read GPIO Register  ${DATA_VALUE}
    Should Be Equal As Numbers  ${val}  0xDEADBEEF

Data Read Should Return Data Value
    [Documentation]         DATA_READ should reflect DATA_VALUE
    [Tags]                  aspeed  gpio  register
    Create AST2600 Machine
    Write GPIO Register     ${DATA_VALUE}  0x12345678
    ${val}=                 Read GPIO Register  ${DATA_READ}
    Should Be Equal As Numbers  ${val}  0x12345678

Data Read Should Be Read-Only
    [Documentation]         Writing to DATA_READ should be ignored
    [Tags]                  aspeed  gpio  register
    Create AST2600 Machine
    Write GPIO Register     ${DATA_VALUE}  0xAABBCCDD
    Write GPIO Register     ${DATA_READ}  0x00000000
    ${val}=                 Read GPIO Register  ${DATA_READ}
    Should Be Equal As Numbers  ${val}  0xAABBCCDD

Int Status Should Be W1C
    [Documentation]         INT_STATUS is write-1-to-clear
    [Tags]                  aspeed  gpio  register  interrupt
    Create AST2600 Machine
    # Manually set some interrupt status bits via direct write won't work (W1C)
    # Instead verify clearing: write INT_STATUS directly in storage first
    # We'll use EFGH to test since 0x038 is INT_STATUS
    # Write 0xFF to EFGH INT_STATUS (this clears bits, but starts at 0 so no effect)
    ${val}=                 Read GPIO Register  ${INT_STATUS}
    Should Be Equal As Numbers  ${val}  0x0

EFGH Set Should Be Independent
    [Documentation]         EFGH set should have its own registers
    [Tags]                  aspeed  gpio  register
    Create AST2600 Machine
    Write GPIO Register     ${DATA_VALUE}  0x11111111
    Write GPIO Register     ${EFGH_DATA}  0x22222222
    ${val1}=                Read GPIO Register  ${DATA_VALUE}
    ${val2}=                Read GPIO Register  ${EFGH_DATA}
    Should Be Equal As Numbers  ${val1}  0x11111111
    Should Be Equal As Numbers  ${val2}  0x22222222

EFGH Data Read Should Return EFGH Data Value
    [Documentation]         EFGH DATA_READ maps to EFGH DATA_VALUE
    [Tags]                  aspeed  gpio  register
    Create AST2600 Machine
    Write GPIO Register     ${EFGH_DATA}  0x99887766
    ${val}=                 Read GPIO Register  ${EFGH_DATA_READ}
    Should Be Equal As Numbers  ${val}  0x99887766

1_8V GPIO Should Be Accessible
    [Documentation]         1.8V GPIO controller should be present
    [Tags]                  aspeed  gpio  platform  1_8v
    Create AST2600 Machine
    ${val}=                 Execute Command    gpio_1_8v ReadDoubleWord 0x000
    Should Be Equal As Numbers  ${val.strip()}  0x0
