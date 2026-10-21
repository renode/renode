*** Comments ***
# Copyright (c) 2026 Microsoft
# Licensed under the MIT license.

*** Variables ***
${ESPI_BASE}    0x1E6EE000

*** Keywords ***
Create AST2600 Machine
    Execute Command    mach create "ast2600"
    Execute Command    machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read ESPI Register
    [Arguments]    ${offset}
    ${val}=     Execute Command    espi ReadDoubleWord ${offset}
    RETURN    ${val.strip()}

Write ESPI Register
    [Arguments]    ${offset}    ${value}
    Execute Command    espi WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Read INT_STS Reset Value With RST_DEASSERT
    [Documentation]    INT_STS resets with BIT(31) set indicating reset deassert
    [Tags]             aspeed    espi    registers
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x008
    Should Be Equal As Numbers    ${val}    0x80000000

Should Read General Capability Reset Value
    [Documentation]    GEN_CAP_N_CONF at 0x0A0 reads 0xF759
    [Tags]             aspeed    espi    capabilities
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x0A0
    Should Be Equal As Numbers    ${val}    0x0000F759

Should Read CH0 Capability Reset Value
    [Documentation]    CH0_CAP_N_CONF at 0x0A4 reads 0x73
    [Tags]             aspeed    espi    capabilities
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x0A4
    Should Be Equal As Numbers    ${val}    0x00000073

Should Read CH1 Capability Reset Value
    [Documentation]    CH1_CAP_N_CONF at 0x0A8 reads 0x33
    [Tags]             aspeed    espi    capabilities
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x0A8
    Should Be Equal As Numbers    ${val}    0x00000033

Should Read CH2 Capability Reset Value
    [Documentation]    CH2_CAP_N_CONF at 0x0AC reads 0x33
    [Tags]             aspeed    espi    capabilities
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x0AC
    Should Be Equal As Numbers    ${val}    0x00000033

Should Read CH3 Capability Reset Value
    [Documentation]    CH3_CAP_N_CONF at 0x0B0 reads 0x03
    [Tags]             aspeed    espi    capabilities
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x0B0
    Should Be Equal As Numbers    ${val}    0x00000003

Should Read CTRL2 Reset Value
    [Documentation]    CTRL2 at 0x080 resets to MCYC_RD_DIS|MCYC_WR_DIS = 0x50
    [Tags]             aspeed    espi    registers
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x080
    Should Be Equal As Numbers    ${val}    0x00000050

Should Read VW_SYSEVT Reset With PLTRST
    [Documentation]    VW_SYSEVT at 0x098 resets with PLTRST# bit (BIT 5) set
    [Tags]             aspeed    espi    virtualwire
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x098
    Should Be Equal As Numbers    ${val}    0x00000020

Should Clear INT_STS By Write One To Clear
    [Documentation]    Writing 1 bits to INT_STS clears those bits
    [Tags]             aspeed    espi    interrupts
    Create AST2600 Machine
    # INT_STS starts with 0x80000000 (RST_DEASSERT)
    ${val}=    Read ESPI Register    0x008
    Should Be Equal As Numbers    ${val}    0x80000000
    # W1C the RST_DEASSERT bit
    Write ESPI Register    0x008    0x80000000
    ${val}=    Read ESPI Register    0x008
    Should Be Equal As Numbers    ${val}    0x00000000

Should Support INT_EN_CLR Register
    [Documentation]    INT_EN_CLR at 0x0FC clears INT_EN bits
    [Tags]             aspeed    espi    interrupts
    Create AST2600 Machine
    # Set some INT_EN bits
    Write ESPI Register    0x00C    0xFF
    ${val}=    Read ESPI Register    0x00C
    Should Be Equal As Numbers    ${val}    0x000000FF
    # Clear bits [3:0] via INT_EN_CLR
    Write ESPI Register    0x0FC    0x0F
    ${val}=    Read ESPI Register    0x00C
    Should Be Equal As Numbers    ${val}    0x000000F0

Should Write And Read CTRL Register
    [Documentation]    CTRL R/W with SW reset bits self-clearing
    [Tags]             aspeed    espi    registers
    Create AST2600 Machine
    # Write ready bits + a SW reset bit
    # PERIF_SW_RDY = BIT(1), PERIF_PC_RX_SW_RST = BIT(24)
    Write ESPI Register    0x000    0x01000002
    ${val}=    Read ESPI Register    0x000
    # SW reset bit should have self-cleared
    Should Be Equal As Numbers    ${val}    0x00000002

Should Support Capabilities As ReadOnly
    [Documentation]    Writing to capability registers has no effect
    [Tags]             aspeed    espi    capabilities
    Create AST2600 Machine
    Write ESPI Register    0x0A0    0xFFFFFFFF
    ${val}=    Read ESPI Register    0x0A0
    Should Be Equal As Numbers    ${val}    0x0000F759

Should Handle PC TX Completion
    [Documentation]    Writing TRIG_PEND to PC TX CTRL triggers TX and raises INT
    [Tags]             aspeed    espi    peripheral
    Create AST2600 Machine
    # Enable PC TX completion interrupt
    Write ESPI Register    0x00C    0x02
    # Clear initial INT_STS
    Write ESPI Register    0x008    0xFFFFFFFF
    # Write TRIG_PEND (BIT 31) to PC TX CTRL
    Write ESPI Register    0x024    0x80000000
    # Check TRIG_PEND cleared
    ${ctrl}=    Read ESPI Register    0x024
    ${ctrlNum}=    Evaluate    ${ctrl} & 0x80000000
    Should Be Equal As Numbers    ${ctrlNum}    0
    # Check INT_STS has PC TX CMPLT (BIT 1)
    ${sts}=    Read ESPI Register    0x008
    ${bit1}=    Evaluate    ${sts} & 0x02
    Should Not Be Equal As Numbers    ${bit1}    0

Should Handle OOB TX Completion
    [Documentation]    Writing TRIG_PEND to OOB TX CTRL triggers TX and raises INT
    [Tags]             aspeed    espi    oob
    Create AST2600 Machine
    Write ESPI Register    0x00C    0x20
    Write ESPI Register    0x008    0xFFFFFFFF
    Write ESPI Register    0x054    0x80000000
    ${ctrl}=    Read ESPI Register    0x054
    ${trigCleared}=    Evaluate    ${ctrl} & 0x80000000
    Should Be Equal As Numbers    ${trigCleared}    0
    ${sts}=    Read ESPI Register    0x008
    ${bit5}=    Evaluate    ${sts} & 0x20
    Should Not Be Equal As Numbers    ${bit5}    0

Should Handle Flash TX Completion
    [Documentation]    Writing TRIG_PEND to Flash TX CTRL triggers TX and raises INT
    [Tags]             aspeed    espi    flash
    Create AST2600 Machine
    Write ESPI Register    0x00C    0x80
    Write ESPI Register    0x008    0xFFFFFFFF
    Write ESPI Register    0x074    0x80000000
    ${ctrl}=    Read ESPI Register    0x074
    ${trigCleared}=    Evaluate    ${ctrl} & 0x80000000
    Should Be Equal As Numbers    ${trigCleared}    0
    ${sts}=    Read ESPI Register    0x008
    ${bit7}=    Evaluate    ${sts} & 0x80
    Should Not Be Equal As Numbers    ${bit7}    0

Should Write Only Slave Driven SYSEVT Bits
    [Documentation]    BMC writes to SYSEVT only affect slave-driven bits
    [Tags]             aspeed    espi    virtualwire
    Create AST2600 Machine
    # Initially PLTRST (host bit 5) is set = 0x20
    ${val}=    Read ESPI Register    0x098
    Should Be Equal As Numbers    ${val}    0x00000020
    # Write SLV_BOOT_DONE (bit 20) + try to clear PLTRST (bit 5)
    Write ESPI Register    0x098    0x00100000
    ${val}=    Read ESPI Register    0x098
    # PLTRST should still be set (host-driven), SLV_BOOT_DONE should be set
    ${expected}=    Evaluate    0x00100020
    Should Be Equal As Numbers    ${val}    ${expected}

Should Handle DMA Address Registers
    [Documentation]    DMA address registers are R/W
    [Tags]             aspeed    espi    dma
    Create AST2600 Machine
    Write ESPI Register    0x010    0xDEADBEEF
    ${val}=    Read ESPI Register    0x010
    Should Be Equal As Numbers    ${val}    0xDEADBEEF
    Write ESPI Register    0x040    0xCAFEBABE
    ${val}=    Read ESPI Register    0x040
    Should Be Equal As Numbers    ${val}    0xCAFEBABE

Should Support MMBI Registers
    [Documentation]    MMBI CTRL and INT_EN are R/W, INT_STS is W1C
    [Tags]             aspeed    espi    mmbi
    Create AST2600 Machine
    Write ESPI Register    0x800    0x01
    ${val}=    Read ESPI Register    0x800
    Should Be Equal As Numbers    ${val}    0x01
    Write ESPI Register    0x80C    0xFF
    ${val}=    Read ESPI Register    0x80C
    Should Be Equal As Numbers    ${val}    0xFF

Should Handle VW SYSEVT Interrupt Type Registers
    [Documentation]    SYSEVT interrupt type/status registers are R/W and W1C
    [Tags]             aspeed    espi    virtualwire
    Create AST2600 Machine
    # Write interrupt type T0
    Write ESPI Register    0x110    0x0000FFFF
    ${val}=    Read ESPI Register    0x110
    Should Be Equal As Numbers    ${val}    0x0000FFFF
    # Write interrupt type T1
    Write ESPI Register    0x114    0xFFFF0000
    ${val}=    Read ESPI Register    0x114
    Should Be Equal As Numbers    ${val}    0xFFFF0000

Should Read Zero From Unimplemented Registers
    [Documentation]    Reading unimplemented register space returns 0
    [Tags]             aspeed    espi    registers
    Create AST2600 Machine
    ${val}=    Read ESPI Register    0x200
    Should Be Equal As Numbers    ${val}    0x00000000
