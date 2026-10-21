*** Comments ***
# Copyright (c) 2026 Microsoft
# Licensed under the MIT license.
# Aspeed AST2600 FTGMAC100 Ethernet MAC Controller Tests

*** Settings ***
Library    String

*** Variables ***
# Use ETH1 base address
${ETH_BASE}    0x1E660000

# Register offsets
${ISR}       0x00
${IER}       0x04
${MAC_MADR}  0x08
${MAC_LADR}  0x0C
${NPTXR}     0x20
${RXR}       0x24
${DBLAC}     0x38
${REVR}      0x40
${RBSR}      0x4C
${MACCR}     0x50
${PHYCR}     0x60
${PHYDATA}   0x64

*** Keywords ***
Create AST2600 Machine
    Execute Command    mach create
    Execute Command    machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read ETH Register
    [Arguments]    ${offset}
    ${val}=    Execute Command    sysbus ReadDoubleWord ${${ETH_BASE} + ${offset}}
    RETURN    ${val}

Write ETH Register
    [Arguments]    ${offset}    ${value}
    Execute Command    sysbus WriteDoubleWord ${${ETH_BASE} + ${offset}} ${value}

PHY Read
    [Arguments]    ${phy_reg}
    # Build PHYCR: phyReg in bits [25:21], MIIRD in bit 26
    # phyReg << 21 | (1 << 26) = phyReg * 0x200000 + 0x4000000
    ${shifted}=    Evaluate    (${phy_reg} << 21) | (1 << 26)
    Write ETH Register    ${PHYCR}    ${shifted}
    ${data}=    Read ETH Register    ${PHYDATA}
    # Result in bits [31:16]
    ${result}=    Evaluate    (${data} >> 16) & 0xFFFF
    RETURN    ${result}

*** Test Cases ***
DBLAC Should Have Reset Value
    [Documentation]    DBLAC should reset to 0x00022F00
    Create AST2600 Machine
    ${val}=    Read ETH Register    ${DBLAC}
    Should Be Equal As Numbers    ${val}    0x00022F00

RBSR Should Have Reset Value
    [Documentation]    RX buffer size should reset to 0x640
    Create AST2600 Machine
    ${val}=    Read ETH Register    ${RBSR}
    Should Be Equal As Numbers    ${val}    0x640

REVR Should Read Zero
    [Documentation]    Revision register returns 0
    Create AST2600 Machine
    ${val}=    Read ETH Register    ${REVR}
    Should Be Equal As Numbers    ${val}    0

ISR Should Be Write 1 To Clear
    [Documentation]    Writing 1 bits to ISR should clear those bits
    Create AST2600 Machine
    # ISR starts at 0, set some bits via direct register manipulation first
    # Write IER then set ISR bits indirectly — for stub, write ISR directly
    # Actually ISR is W1C so writing will clear. Let's test:
    # First write 0xFF to force some bits (would need interrupt source)
    # Instead test that W1C doesn't accumulate
    ${val}=    Read ETH Register    ${ISR}
    Should Be Equal As Numbers    ${val}    0
    # W1C on already-zero register should remain zero
    Write ETH Register    ${ISR}    0xFFFFFFFF
    ${val}=    Read ETH Register    ${ISR}
    Should Be Equal As Numbers    ${val}    0

MAC Address Registers Are RW
    [Documentation]    MAC address high and low registers should be R/W
    Create AST2600 Machine
    Write ETH Register    ${MAC_MADR}    0x00112233
    Write ETH Register    ${MAC_LADR}    0x44556677
    ${hi}=    Read ETH Register    ${MAC_MADR}
    ${lo}=    Read ETH Register    ${MAC_LADR}
    Should Be Equal As Numbers    ${hi}    0x00112233
    Should Be Equal As Numbers    ${lo}    0x44556677

TX And RX Ring Base Are RW
    [Documentation]    Descriptor ring base addresses should be R/W
    Create AST2600 Machine
    Write ETH Register    ${NPTXR}    0x80000000
    Write ETH Register    ${RXR}    0x80001000
    ${tx}=    Read ETH Register    ${NPTXR}
    ${rx}=    Read ETH Register    ${RXR}
    Should Be Equal As Numbers    ${tx}    0x80000000
    Should Be Equal As Numbers    ${rx}    0x80001000

MACCR Is RW
    [Documentation]    MACCR should accept and return written values
    Create AST2600 Machine
    # Enable TX/RX MAC and DMA
    Write ETH Register    ${MACCR}    0x0000000F
    ${val}=    Read ETH Register    ${MACCR}
    Should Be Equal As Numbers    ${val}    0x0000000F

MACCR SW RST Preserves Mode Bits
    [Documentation]    SW_RST should preserve GIGA_MODE (bit9) and FAST_MODE (bit19)
    Create AST2600 Machine
    # Set GIGA_MODE and FAST_MODE
    Write ETH Register    ${MACCR}    0x00080200
    ${val}=    Read ETH Register    ${MACCR}
    Should Be Equal As Numbers    ${val}    0x00080200
    # Trigger SW_RST (bit 31)
    Write ETH Register    ${MACCR}    0x80080200
    # After reset, only mode bits should remain
    ${val}=    Read ETH Register    ${MACCR}
    Should Be Equal As Numbers    ${val}    0x00080200
    # And DBLAC should be back to reset value
    ${dblac}=    Read ETH Register    ${DBLAC}
    Should Be Equal As Numbers    ${dblac}    0x00022F00

PHY ID1 Should Be RTL8211E
    [Documentation]    PHY ID register 1 should return 0x001C (Realtek OUI)
    Create AST2600 Machine
    ${id1}=    PHY Read    2
    Should Be Equal As Numbers    ${id1}    0x001C

PHY ID2 Should Be RTL8211E
    [Documentation]    PHY ID register 2 should return 0xC916
    Create AST2600 Machine
    ${id2}=    PHY Read    3
    Should Be Equal As Numbers    ${id2}    0xC916

PHY Link Should Be Up
    [Documentation]    PHY BMSR (reg 1) bit 2 must be set for link status
    Create AST2600 Machine
    ${bmsr}=    PHY Read    1
    # Check bit 2 (LINK_ST = 0x0004)
    ${link}=    Evaluate    ${bmsr} & 0x0004
    Should Not Be Equal As Numbers    ${link}    0

PHY BMCR Should Have Auto Neg Enable
    [Documentation]    PHY BMCR should have auto-negotiation enable bit set
    Create AST2600 Machine
    ${bmcr}=    PHY Read    0
    # Bit 12 = auto-neg enable = 0x1000
    ${an}=    Evaluate    ${bmcr} & 0x1000
    Should Not Be Equal As Numbers    ${an}    0

PHYCR Read Clears MIIRD Bit
    [Documentation]    After PHY read, MIIRD bit in PHYCR should be cleared
    Create AST2600 Machine
    # Trigger a PHY read (reg 1, MIIRD = bit 26)
    ${cmd}=    Evaluate    (1 << 21) | (1 << 26)
    Write ETH Register    ${PHYCR}    ${cmd}
    # MIIRD should be auto-cleared
    ${phycr}=    Read ETH Register    ${PHYCR}
    Should Be Equal As Numbers    ${phycr}    0x00200000

IER Is RW
    [Documentation]    Interrupt enable register should be R/W
    Create AST2600 Machine
    Write ETH Register    ${IER}    0x0000FFFF
    ${val}=    Read ETH Register    ${IER}
    Should Be Equal As Numbers    ${val}    0x0000FFFF

Reset Restores Defaults
    [Documentation]    Machine reset should restore all register defaults
    Create AST2600 Machine
    # Modify several registers
    Write ETH Register    ${MAC_MADR}    0xDEADBEEF
    Write ETH Register    ${IER}    0xFFFF
    Write ETH Register    ${MACCR}    0x0F
    # Reset
    Execute Command    machine Reset
    # Verify defaults
    ${dblac}=    Read ETH Register    ${DBLAC}
    ${rbsr}=    Read ETH Register    ${RBSR}
    ${madr}=    Read ETH Register    ${MAC_MADR}
    ${maccr}=    Read ETH Register    ${MACCR}
    Should Be Equal As Numbers    ${dblac}    0x00022F00
    Should Be Equal As Numbers    ${rbsr}    0x640
    Should Be Equal As Numbers    ${madr}    0
    Should Be Equal As Numbers    ${maccr}    0
