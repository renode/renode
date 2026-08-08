*** Settings ***
Library           String
Suite Teardown    Teardown
Test Teardown     Test Teardown
Test Setup        Reset Emulation

*** Variables ***
${I2C_BASE}       0x1E78A000
${BUS0_BASE}      0x1E78A080
${FUN_CTRL}       0x00
${AC_TIMING}      0x04
${TXRX_BUF}       0x08
${POOL_CTRL}      0x0C
${M_INTR_CTRL}    0x10
${M_INTR_STS}     0x14
${M_CMD}          0x18
${S_INTR_CTRL}    0x20
${S_INTR_STS}     0x24
${S_CMD}          0x28
${S_DEV_ADDR}     0x40

*** Keywords ***
Create AST2600 Machine
    Execute Command    mach create "ast2600"
    Execute Command    machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Write Bus Register
    [Arguments]    ${bus}    ${reg_offset}    ${value}
    ${bus_addr}=    Evaluate    hex(${BUS0_BASE} + ${bus} * 0x80 + ${reg_offset})
    Execute Command    sysbus WriteDoubleWord ${bus_addr} ${value}

Read Bus Register
    [Arguments]    ${bus}    ${reg_offset}
    ${bus_addr}=    Evaluate    hex(${BUS0_BASE} + ${bus} * 0x80 + ${reg_offset})
    ${val}=    Execute Command    sysbus ReadDoubleWord ${bus_addr}
    RETURN    ${val}

*** Test Cases ***
Global Register Read Returns Zero On Reset
    [Documentation]    Global control register should be zero after reset.
    [Tags]             aspeed  i2c  register
    Create AST2600 Machine
    ${val}=    Execute Command    sysbus ReadDoubleWord ${I2C_BASE}
    Should Contain    ${val}    0x00000000

Bus 0 Function Control Defaults To Zero
    [Documentation]    Function control register resets to 0 (master/slave disabled).
    [Tags]             aspeed  i2c  register
    Create AST2600 Machine
    ${val}=    Read Bus Register    0    ${FUN_CTRL}
    Should Contain    ${val}    0x00000000

Write And Read Function Control
    [Documentation]    Function control is R/W.
    [Tags]             aspeed  i2c  register
    Create AST2600 Machine
    Write Bus Register    0    ${FUN_CTRL}    0x00000001
    ${val}=    Read Bus Register    0    ${FUN_CTRL}
    Should Contain    ${val}    0x00000001

AC Timing Is Masked
    [Documentation]    AC timing register masks to 0x1FFFF0FF.
    [Tags]             aspeed  i2c  register
    Create AST2600 Machine
    Write Bus Register    0    ${AC_TIMING}    0xFFFFFFFF
    ${val}=    Read Bus Register    0    ${AC_TIMING}
    Should Contain    ${val}    0x1FFFF0FF

Master Interrupt Control Is Masked
    [Documentation]    Master interrupt control masks to 0x0007F07F.
    [Tags]             aspeed  i2c  register
    Create AST2600 Machine
    Write Bus Register    0    ${M_INTR_CTRL}    0xFFFFFFFF
    ${val}=    Read Bus Register    0    ${M_INTR_CTRL}
    Should Contain    ${val}    0x0007F07F

Start TX Generates NAK
    [Documentation]    START+TX on empty bus sets TX_NAK in interrupt status.
    [Tags]             aspeed  i2c  command
    Create AST2600 Machine
    Write Bus Register    0    ${FUN_CTRL}    0x00000001
    Write Bus Register    0    ${M_CMD}    0x00000003
    ${val}=    Read Bus Register    0    ${M_INTR_STS}
    Should Contain    ${val}    0x00000002

Master Interrupt Status Is W1C
    [Documentation]    Writing 1 to interrupt status bits clears them.
    [Tags]             aspeed  i2c  register
    Create AST2600 Machine
    Write Bus Register    0    ${M_CMD}    0x00000003
    ${val}=    Read Bus Register    0    ${M_INTR_STS}
    Should Contain    ${val}    0x00000002
    Write Bus Register    0    ${M_INTR_STS}    0x00000002
    ${val}=    Read Bus Register    0    ${M_INTR_STS}
    Should Contain    ${val}    0x00000000

Stop Command Sets Normal Stop
    [Documentation]    STOP command sets NORMAL_STOP in interrupt status.
    [Tags]             aspeed  i2c  command
    Create AST2600 Machine
    Write Bus Register    0    ${M_CMD}    0x00000020
    ${val}=    Read Bus Register    0    ${M_INTR_STS}
    Should Contain    ${val}    0x00000010

Bus 15 Is Accessible
    [Documentation]    Bus 15 (highest) is at correct offset and functional.
    [Tags]             aspeed  i2c  register
    Create AST2600 Machine
    Write Bus Register    15    ${FUN_CTRL}    0x00000001
    ${val}=    Read Bus Register    15    ${FUN_CTRL}
    Should Contain    ${val}    0x00000001

Command Bits Are Cleared After Execution
    [Documentation]    Command register START/TX/RX/STOP bits auto-clear.
    [Tags]             aspeed  i2c  command
    Create AST2600 Machine
    Write Bus Register    0    ${M_CMD}    0x0000002B
    ${val}=    Read Bus Register    0    ${M_CMD}
    Should Contain    ${val}    0x00000000

Buses Are Independent
    [Documentation]    Writing to bus 0 does not affect bus 1.
    [Tags]             aspeed  i2c  register
    Create AST2600 Machine
    Write Bus Register    0    ${FUN_CTRL}    0x00000001
    Write Bus Register    1    ${FUN_CTRL}    0x00000000
    ${val0}=    Read Bus Register    0    ${FUN_CTRL}
    ${val1}=    Read Bus Register    1    ${FUN_CTRL}
    Should Contain    ${val0}    0x00000001
    Should Contain    ${val1}    0x00000000
