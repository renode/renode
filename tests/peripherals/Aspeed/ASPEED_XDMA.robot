*** Variables ***
${CMDQ_ADDR}        0x014
${CMDQ_ENDP}        0x018
${CMDQ_WRP}         0x01C
${CMDQ_RDP}         0x020
${IRQ_CTRL}         0x038
${IRQ_STATUS}       0x03C
${IRQ_STATUS_RESET}    0xF8000000
${IRQ_CTRL_MASK}    0x017003FF

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read XDMA Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    xdma ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write XDMA Register
    [Arguments]             ${offset}  ${value}
    Execute Command         xdma WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With XDMA
    [Documentation]         Verify XDMA is accessible after platform load
    [Tags]                  aspeed  xdma  platform
    Create AST2600 Machine
    ${val}=                 Read XDMA Register  ${IRQ_STATUS}
    Should Not Be Equal As Numbers  ${val}  0xFFFFFFFF

IRQ Status Should Reset To F8000000
    [Documentation]         QEMU resets IRQ_STATUS to    0xF8000000
    [Tags]                  aspeed  xdma  register
    Create AST2600 Machine
    ${val}=                 Read XDMA Register  ${IRQ_STATUS}
    Should Be Equal As Numbers  ${val}  ${IRQ_STATUS_RESET}

IRQ Status Should Be W1C
    [Documentation]         Writing 1 clears IRQ status bits
    [Tags]                  aspeed  xdma  interrupt
    Create AST2600 Machine
    Write XDMA Register    ${IRQ_STATUS}  0x08000000
    ${val}=                 Read XDMA Register  ${IRQ_STATUS}
    Should Be Equal As Numbers  ${val}  0xF0000000

IRQ Control Should Mask High Bits
    [Documentation]         IRQ_CTRL write mask is 0x017003FF
    [Tags]                  aspeed  xdma  register
    Create AST2600 Machine
    Write XDMA Register    ${IRQ_CTRL}  0xFFFFFFFF
    ${val}=                 Read XDMA Register  ${IRQ_CTRL}
    Should Be Equal As Numbers  ${val}  ${IRQ_CTRL_MASK}

Command Queue Registers Should Be Writable
    [Documentation]         CMDQ address and endpoint are R/W
    [Tags]                  aspeed  xdma  register
    Create AST2600 Machine
    Write XDMA Register    ${CMDQ_ADDR}  0x10000000
    ${val}=                 Read XDMA Register  ${CMDQ_ADDR}
    Should Be Equal As Numbers  ${val}  0x10000000
    Write XDMA Register    ${CMDQ_ENDP}  0x10001000
    ${val}=                 Read XDMA Register  ${CMDQ_ENDP}
    Should Be Equal As Numbers  ${val}  0x10001000

Other Registers Should Default To Zero
    [Documentation]         Non-status registers default to 0
    [Tags]                  aspeed  xdma  register
    Create AST2600 Machine
    ${val}=                 Read XDMA Register  ${CMDQ_ADDR}
    Should Be Equal As Numbers  ${val}  0x0
    ${val}=                 Read XDMA Register  ${IRQ_CTRL}
    Should Be Equal As Numbers  ${val}  0x0
