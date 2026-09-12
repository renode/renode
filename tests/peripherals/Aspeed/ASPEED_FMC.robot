*** Variables ***
${CONF}                 0x00
${CE_CTRL}              0x04
${INTR_CTRL}            0x08
${CE0_CTRL}             0x10
${SEG_ADDR0}            0x30
${SEG_ADDR1}            0x34
${DMA_CTRL}             0x80
${DMA_FLASH_ADDR}       0x84
${DMA_DRAM_ADDR}        0x88
${DMA_LEN}              0x8C
${DMA_CHECKSUM}         0x90
${TIMINGS}              0x94

# DMA magic (AST2600)
${DMA_GRANT_REQ}        0xAEED0000
${DMA_GRANT_CLR}        0xDEEA0000

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read FMC Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    fmc ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write FMC Register
    [Arguments]             ${offset}  ${value}
    Execute Command         fmc WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With FMC
    [Documentation]         FMC peripheral and flash window should be accessible
    [Tags]                  aspeed  fmc  platform
    Create AST2600 Machine
    ${conf}=                Read FMC Register  ${CONF}
    Should Not Be Equal As Numbers  ${conf}  0x0

Config Should Have SPI Type And Write Enable
    [Documentation]         FMC_CONF: CE0=SPI type (0x2) and write-enabled (bit 16)
    [Tags]                  aspeed  fmc  register
    Create AST2600 Machine
    ${conf}=                Read FMC Register  ${CONF}
    # SPI type (0x2) in bits [1:0] + write enable (1<<16) = 0x10002
    Should Be Equal As Numbers  ${conf}  0x10002

CE0 Control Should Have Read Mode
    [Documentation]         CE0_CTRL should default to read mode with READ command
    [Tags]                  aspeed  fmc  register
    Create AST2600 Machine
    ${ctrl}=                Read FMC Register  ${CE0_CTRL}
    # READ cmd (0x03 << 16) | CE_STOP_ACTIVE (1<<2) = 0x30004
    Should Be Equal As Numbers  ${ctrl}  0x30004

Segment0 Should Cover 128MB
    [Documentation]         SEG_ADDR0: end=0x08 (128MB units), start=0x00
    [Tags]                  aspeed  fmc  register
    Create AST2600 Machine
    ${seg}=                 Read FMC Register  ${SEG_ADDR0}
    Should Be Equal As Numbers  ${seg}  0x08000000

DMA Grant Request Should Auto-Grant
    [Documentation]         Writing 0xAEED0000 should set request+grant bits
    [Tags]                  aspeed  fmc  dma
    Create AST2600 Machine
    Write FMC Register      ${DMA_CTRL}  ${DMA_GRANT_REQ}
    ${ctrl}=                Read FMC Register  ${DMA_CTRL}
    # Request (bit 31) + Grant (bit 30) = 0xC0000000
    Should Be Equal As Numbers  ${ctrl}  0xC0000000

DMA Grant Clear Should Remove Grant
    [Documentation]         Writing 0xDEEA0000 should clear request+grant
    [Tags]                  aspeed  fmc  dma
    Create AST2600 Machine
    # First request
    Write FMC Register      ${DMA_CTRL}  ${DMA_GRANT_REQ}
    # Then clear
    Write FMC Register      ${DMA_CTRL}  ${DMA_GRANT_CLR}
    ${ctrl}=                Read FMC Register  ${DMA_CTRL}
    Should Be Equal As Numbers  ${ctrl}  0x0

DMA Flash Addr Needs Grant
    [Documentation]         DMA flash address write should only work when granted
    [Tags]                  aspeed  fmc  dma
    Create AST2600 Machine
    # Write without grant — should be ignored
    Write FMC Register      ${DMA_FLASH_ADDR}  0x20001000
    ${addr}=                Read FMC Register  ${DMA_FLASH_ADDR}
    Should Be Equal As Numbers  ${addr}  0x0
    # Now grant and write
    Write FMC Register      ${DMA_CTRL}  ${DMA_GRANT_REQ}
    Write FMC Register      ${DMA_FLASH_ADDR}  0x20001000
    ${addr}=                Read FMC Register  ${DMA_FLASH_ADDR}
    # Address stored with 4-byte alignment: 0x20001000
    Should Be Equal As Numbers  ${addr}  0x20001000

DMA Checksum Should Read Flash
    [Documentation]         DMA checksum reads from flash window and accumulates
    [Tags]                  aspeed  fmc  dma
    Create AST2600 Machine
    # Write known data to flash at offset 0
    Execute Command         sysbus WriteDoubleWord 0x20000000 0x12345678
    Execute Command         sysbus WriteDoubleWord 0x20000004 0xAABBCCDD
    # Request DMA grant
    Write FMC Register      ${DMA_CTRL}  ${DMA_GRANT_REQ}
    # Set flash addr (base of flash window)
    Write FMC Register      ${DMA_FLASH_ADDR}  0x20000000
    Write FMC Register      ${DMA_DRAM_ADDR}  0x80000000
    # Length: 7 means 8 bytes (aligned to 4 = 8)
    Write FMC Register      ${DMA_LEN}  0x7
    # Enable DMA with checksum mode (bits: enable=0, cksum=2)
    Write FMC Register      ${DMA_CTRL}  0xC0000005
    # Read checksum: should be 0x12345678 + 0xAABBCCDD = 0xBCF02355
    ${cksum}=               Read FMC Register  ${DMA_CHECKSUM}
    Should Be Equal As Numbers  ${cksum}  0xBCF02355

DMA Copy Flash To DRAM
    [Documentation]         DMA should copy data from flash to DRAM
    [Tags]                  aspeed  fmc  dma
    Create AST2600 Machine
    # Write test pattern to flash
    Execute Command         sysbus WriteDoubleWord 0x20000000 0xDEADBEEF
    # Request grant
    Write FMC Register      ${DMA_CTRL}  ${DMA_GRANT_REQ}
    # Setup DMA: flash=0x20000000, dram=0x80100000, len=3 (4 bytes)
    Write FMC Register      ${DMA_FLASH_ADDR}  0x20000000
    Write FMC Register      ${DMA_DRAM_ADDR}  0x80100000
    Write FMC Register      ${DMA_LEN}  0x3
    # Enable DMA read (no checksum, no write)
    Write FMC Register      ${DMA_CTRL}  0xC0000001
    # Verify data copied to DRAM
    ${val}=                 Execute Command    sysbus ReadDoubleWord 0x80100000
    Should Be Equal As Numbers  ${val.strip()}  0xDEADBEEF

Timings Register Should Be Writable
    [Documentation]         Read timing compensation register is R/W
    [Tags]                  aspeed  fmc  register
    Create AST2600 Machine
    Write FMC Register      ${TIMINGS}  0x00112233
    ${val}=                 Read FMC Register  ${TIMINGS}
    Should Be Equal As Numbers  ${val}  0x00112233
