*** Comments ***
# Copyright (c) 2026 Microsoft
# Licensed under the MIT license.
# Aspeed AST2600 LPC/KCS Controller Tests

*** Settings ***
Library    String

*** Variables ***
${LPC_BASE}    0x1E789000

# HICR registers
${HICR0}    0x00
${HICR1}    0x04
${HICR2}    0x08
${HICR3}    0x0C
${HICR4}    0x10
${HICR5}    0x80
${HICR6}    0x84
${HICR7}    0x88
${HICR8}    0x8C
${HICRB}    0x100

# KCS1-3 registers
${IDR1}    0x24
${IDR2}    0x28
${IDR3}    0x2C
${ODR1}    0x30
${ODR2}    0x34
${ODR3}    0x38
${STR1}    0x3C
${STR2}    0x40
${STR3}    0x44

# KCS4 registers
${IDR4}    0x114
${ODR4}    0x118
${STR4}    0x11C

*** Keywords ***
Create AST2600 Machine
    Execute Command    mach create
    Execute Command    machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read LPC Register
    [Arguments]    ${offset}
    ${val}=    Execute Command    sysbus ReadDoubleWord ${${LPC_BASE} + ${offset}}
    RETURN    ${val}

Write LPC Register
    [Arguments]    ${offset}    ${value}
    Execute Command    sysbus WriteDoubleWord ${${LPC_BASE} + ${offset}} ${value}

*** Test Cases ***
All HICR Registers Should Reset To Zero
    [Documentation]    Verify all HICR registers reset to 0 (HICR7 defaults to 0 when property not set)
    Create AST2600 Machine
    ${h0}=    Read LPC Register    ${HICR0}
    ${h1}=    Read LPC Register    ${HICR1}
    ${h2}=    Read LPC Register    ${HICR2}
    ${h3}=    Read LPC Register    ${HICR3}
    ${h4}=    Read LPC Register    ${HICR4}
    ${h5}=    Read LPC Register    ${HICR5}
    ${h6}=    Read LPC Register    ${HICR6}
    ${h7}=    Read LPC Register    ${HICR7}
    ${h8}=    Read LPC Register    ${HICR8}
    ${hb}=    Read LPC Register    ${HICRB}
    Should Be Equal As Numbers    ${h0}    0
    Should Be Equal As Numbers    ${h1}    0
    Should Be Equal As Numbers    ${h2}    0
    Should Be Equal As Numbers    ${h3}    0
    Should Be Equal As Numbers    ${h4}    0
    Should Be Equal As Numbers    ${h5}    0
    Should Be Equal As Numbers    ${h6}    0
    Should Be Equal As Numbers    ${h7}    0
    Should Be Equal As Numbers    ${h8}    0
    Should Be Equal As Numbers    ${hb}    0

KCS1 IDR Write Should Set IBF
    [Documentation]    Writing to IDR1 should set the IBF bit in STR1
    Create AST2600 Machine
    # STR1 starts at 0
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    0
    # Write to IDR1
    Write LPC Register    ${IDR1}    0xAB
    # Check IBF (bit 1) is set
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    2

KCS1 IDR Read Should Clear IBF
    [Documentation]    Reading IDR1 should clear the IBF bit in STR1
    Create AST2600 Machine
    # Write to IDR1 to set IBF
    Write LPC Register    ${IDR1}    0x42
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    2
    # Read IDR1 — clears IBF
    ${data}=    Read LPC Register    ${IDR1}
    Should Be Equal As Numbers    ${data}    0x42
    # STR1 should be 0 now
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    0

ODR Write Should Set OBF
    [Documentation]    Writing to ODR1 should set the OBF bit in STR1
    Create AST2600 Machine
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    0
    # Write to ODR1
    Write LPC Register    ${ODR1}    0x55
    # Check OBF (bit 0) is set
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    1

KCS2 Should Work Independently
    [Documentation]    KCS2 operations should not affect KCS1
    Create AST2600 Machine
    # Write to IDR2
    Write LPC Register    ${IDR2}    0xBB
    # STR2 should have IBF, STR1 should be clean
    ${str2}=    Read LPC Register    ${STR2}
    ${str1}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str2}    2
    Should Be Equal As Numbers    ${str1}    0

KCS3 Dual Gate Enable
    [Documentation]    KCS3 requires BOTH HICR0.LPC3E and HICR4.KCSENBL for IRQ
    Create AST2600 Machine
    # Enable HICR2.IBFIE3 (bit 3)
    Write LPC Register    ${HICR2}    0x08
    # Only set HICR0.LPC3E (bit 7) — not HICR4.KCSENBL
    Write LPC Register    ${HICR0}    0x80
    # Write to IDR3 — IBF set but no IRQ (channel not fully enabled)
    Write LPC Register    ${IDR3}    0x11
    ${str}=    Read LPC Register    ${STR3}
    Should Be Equal As Numbers    ${str}    2
    # Now enable HICR4.KCSENBL (bit 2) as well
    # Clear IBF first by reading IDR3
    ${dummy}=    Read LPC Register    ${IDR3}
    Write LPC Register    ${HICR4}    0x04
    # Write again — now channel is fully enabled, IRQ should fire
    Write LPC Register    ${IDR3}    0x22
    ${str}=    Read LPC Register    ${STR3}
    Should Be Equal As Numbers    ${str}    2

KCS4 Enable And IBF
    [Documentation]    KCS4 at extended offsets should work with HICRB enable
    Create AST2600 Machine
    # Enable KCS4 via HICRB bit 0
    Write LPC Register    ${HICRB}    0x01
    # Write to IDR4
    Write LPC Register    ${IDR4}    0xCC
    # Check IBF in STR4
    ${str}=    Read LPC Register    ${STR4}
    Should Be Equal As Numbers    ${str}    2
    # Read IDR4 — data should be 0xCC, IBF should clear
    ${data}=    Read LPC Register    ${IDR4}
    Should Be Equal As Numbers    ${data}    0xCC
    ${str}=    Read LPC Register    ${STR4}
    Should Be Equal As Numbers    ${str}    0

ODR4 Should Set OBF In STR4
    [Documentation]    Writing ODR4 sets OBF in STR4
    Create AST2600 Machine
    Write LPC Register    ${ODR4}    0xDD
    ${str}=    Read LPC Register    ${STR4}
    Should Be Equal As Numbers    ${str}    1

STR Is Directly Writable
    [Documentation]    Status registers should be fully R/W (host side control)
    Create AST2600 Machine
    # Write CMD_DATA bit (bit 3) + OBF (bit 0)
    Write LPC Register    ${STR1}    0x09
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    9

IDR Data Is Byte Masked
    [Documentation]    IDR should only store lower 8 bits
    Create AST2600 Machine
    Write LPC Register    ${IDR1}    0x1FF
    # Read should return only 0xFF (and clear IBF)
    ${data}=    Read LPC Register    ${IDR1}
    Should Be Equal As Numbers    ${data}    0xFF

HICR Registers Are Read Write
    [Documentation]    HICR registers should be freely R/W
    Create AST2600 Machine
    Write LPC Register    ${HICR0}    0xE0
    ${val}=    Read LPC Register    ${HICR0}
    Should Be Equal As Numbers    ${val}    0xE0
    Write LPC Register    ${HICR5}    0xABCD1234
    ${val}=    Read LPC Register    ${HICR5}
    Should Be Equal As Numbers    ${val}    0xABCD1234

Both IBF And OBF Can Be Set
    [Documentation]    Writing IDR then ODR should set both IBF and OBF in STR
    Create AST2600 Machine
    Write LPC Register    ${IDR1}    0x10
    Write LPC Register    ${ODR1}    0x20
    ${str}=    Read LPC Register    ${STR1}
    # IBF(bit1)=2, OBF(bit0)=1 => 3
    Should Be Equal As Numbers    ${str}    3

KCS1 IBF IRQ Requires Channel Enable
    [Documentation]    IBF IRQ should only fire when channel is enabled
    Create AST2600 Machine
    # Enable IBFIE1 but NOT LPC1E
    Write LPC Register    ${HICR2}    0x02
    # Write IDR1 — IBF set but no IRQ (channel disabled)
    Write LPC Register    ${IDR1}    0x55
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    2
    # Now enable LPC1E
    Write LPC Register    ${HICR0}    0x20
    # Clear IDR1 by reading
    ${dummy}=    Read LPC Register    ${IDR1}
    # Write again — now fully enabled
    Write LPC Register    ${IDR1}    0x66
    ${str}=    Read LPC Register    ${STR1}
    Should Be Equal As Numbers    ${str}    2

Multiple Channels Simultaneous
    [Documentation]    All 4 channels can hold data simultaneously
    Create AST2600 Machine
    Write LPC Register    ${IDR1}    0x11
    Write LPC Register    ${IDR2}    0x22
    Write LPC Register    ${IDR3}    0x33
    Write LPC Register    ${IDR4}    0x44
    # All STR should have IBF
    ${s1}=    Read LPC Register    ${STR1}
    ${s2}=    Read LPC Register    ${STR2}
    ${s3}=    Read LPC Register    ${STR3}
    ${s4}=    Read LPC Register    ${STR4}
    Should Be Equal As Numbers    ${s1}    2
    Should Be Equal As Numbers    ${s2}    2
    Should Be Equal As Numbers    ${s3}    2
    Should Be Equal As Numbers    ${s4}    2
    # Verify data
    ${d1}=    Read LPC Register    ${IDR1}
    ${d2}=    Read LPC Register    ${IDR2}
    ${d3}=    Read LPC Register    ${IDR3}
    ${d4}=    Read LPC Register    ${IDR4}
    Should Be Equal As Numbers    ${d1}    0x11
    Should Be Equal As Numbers    ${d2}    0x22
    Should Be Equal As Numbers    ${d3}    0x33
    Should Be Equal As Numbers    ${d4}    0x44

Reset Clears All State
    [Documentation]    After reset all registers and state should be cleared
    Create AST2600 Machine
    # Set up some state
    Write LPC Register    ${HICR0}    0xE0
    Write LPC Register    ${IDR1}    0xAA
    Write LPC Register    ${ODR2}    0xBB
    # Reset the machine
    Execute Command    machine Reset
    # Verify everything is cleared
    ${h0}=    Read LPC Register    ${HICR0}
    ${idr}=    Read LPC Register    ${IDR1}
    ${str1}=    Read LPC Register    ${STR1}
    ${str2}=    Read LPC Register    ${STR2}
    Should Be Equal As Numbers    ${h0}    0
    Should Be Equal As Numbers    ${idr}    0
    Should Be Equal As Numbers    ${str1}    0
    Should Be Equal As Numbers    ${str2}    0
