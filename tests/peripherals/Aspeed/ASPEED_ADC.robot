*** Variables ***
# Engine 0 register offsets (base 0x000)
${E0_ENGINE_CTRL}       0x000
${E0_INT_CTRL}          0x004
${E0_VGA_DETECT}        0x008
${E0_CLOCK_CTRL}        0x00C
${E0_DATA_CH1_CH0}      0x010
${E0_DATA_CH3_CH2}      0x014
${E0_DATA_CH5_CH4}      0x018
${E0_DATA_CH7_CH6}      0x01C
${E0_BOUNDS_CH0}        0x020
${E0_BOUNDS_CH1}        0x024
${E0_INT_SOURCE}        0x060
${E0_COMPENSATING}      0x064

# Engine 1 register offsets (base 0x100)
${E1_ENGINE_CTRL}       0x100
${E1_INT_CTRL}          0x104
${E1_VGA_DETECT}        0x108
${E1_CLOCK_CTRL}        0x10C
${E1_DATA_CH1_CH0}      0x110
${E1_INT_SOURCE}        0x160

*** Keywords ***
Create AST2600 Machine
    Execute Command         mach create "ast2600"
    Execute Command         machine LoadPlatformDescription @platforms/boards/ast2600/ast2600-evb.repl

Read ADC Register
    [Arguments]             ${offset}
    ${val}=  Execute Command    adc ReadDoubleWord ${offset}
    RETURN                  ${val.strip()}

Write ADC Register
    [Arguments]             ${offset}  ${value}
    Execute Command         adc WriteDoubleWord ${offset} ${value}

*** Test Cases ***
Should Load Platform With ADC
    [Documentation]         Verify ADC is accessible after platform load
    [Tags]                  aspeed  adc  platform
    Create AST2600 Machine
    ${val}=                 Read ADC Register  ${E0_ENGINE_CTRL}
    Should Be Equal As Numbers  ${val}  0x0

Engine Control Should Default To Zero
    [Documentation]         ENGINE_CTRL resets to 0 (disabled)
    [Tags]                  aspeed  adc  register
    Create AST2600 Machine
    ${val}=                 Read ADC Register  ${E0_ENGINE_CTRL}
    Should Be Equal As Numbers  ${val}  0x0
    ${val}=                 Read ADC Register  ${E1_ENGINE_CTRL}
    Should Be Equal As Numbers  ${val}  0x0

VGA Detect And Clock Should Reset To 0xF
    [Documentation]         VGA_DETECT_CTRL and CLOCK_CTRL reset to 0x0F
    [Tags]                  aspeed  adc  register
    Create AST2600 Machine
    ${val}=                 Read ADC Register  ${E0_VGA_DETECT}
    Should Be Equal As Numbers  ${val}  0xF
    ${val}=                 Read ADC Register  ${E0_CLOCK_CTRL}
    Should Be Equal As Numbers  ${val}  0xF

Enable Should Set INIT Bit
    [Documentation]         Writing EN=1 auto-sets INIT bit (bit 8)
    [Tags]                  aspeed  adc  control
    Create AST2600 Machine
    Write ADC Register      ${E0_ENGINE_CTRL}  0x1
    ${val}=                 Read ADC Register  ${E0_ENGINE_CTRL}
    # EN=1 + INIT=0x100 => 0x101
    Should Be Equal As Numbers  ${val}  0x101

AUTO_COMP Should Be Cleared On Write
    [Documentation]         AUTO_COMP (bit 5) is always cleared on write
    [Tags]                  aspeed  adc  control
    Create AST2600 Machine
    Write ADC Register      ${E0_ENGINE_CTRL}  0x21
    ${val}=                 Read ADC Register  ${E0_ENGINE_CTRL}
    # EN=1 + INIT=0x100, AUTO_COMP cleared => 0x101
    Should Be Equal As Numbers  ${val}  0x101

Data Register Should Be Masked To 10 Bits
    [Documentation]         Data registers mask to 0x03FF03FF (10-bit per channel)
    [Tags]                  aspeed  adc  register
    Create AST2600 Machine
    Write ADC Register      ${E0_DATA_CH1_CH0}  0xFFFFFFFF
    ${val}=                 Read ADC Register  ${E0_DATA_CH1_CH0}
    Should Be Equal As Numbers  ${val}  0x03FF03FF

Data Read Should Auto Increment
    [Documentation]         Reading data register auto-increments channel values
    [Tags]                  aspeed  adc  sampling
    Create AST2600 Machine
    Write ADC Register      ${E0_DATA_CH1_CH0}  0x00000000
    # First read returns 0, but values increment internally
    ${val1}=                Read ADC Register  ${E0_DATA_CH1_CH0}
    Should Be Equal As Numbers  ${val1}  0x0
    # Second read should return incremented values (lower+7=7, upper+5=0x50000)
    ${val2}=                Read ADC Register  ${E0_DATA_CH1_CH0}
    Should Be Equal As Numbers  ${val2}  0x00050007

Bounds Register Should Be Masked
    [Documentation]         Bounds registers mask to 0x03FF03FF
    [Tags]                  aspeed  adc  register
    Create AST2600 Machine
    Write ADC Register      ${E0_BOUNDS_CH0}  0xFFFFFFFF
    ${val}=                 Read ADC Register  ${E0_BOUNDS_CH0}
    Should Be Equal As Numbers  ${val}  0x03FF03FF

INT Source Should Be W1C
    [Documentation]         INT_SOURCE is write-1-to-clear
    [Tags]                  aspeed  adc  interrupt
    Create AST2600 Machine
    # Enable engine and set bounds to trigger threshold
    Write ADC Register      ${E0_ENGINE_CTRL}  0x00010001
    Write ADC Register      ${E0_BOUNDS_CH0}  0x02000100
    # Write data below lower bound to trigger interrupt
    Write ADC Register      ${E0_DATA_CH1_CH0}  0x00000050
    # Read data to trigger threshold check
    ${dummy}=               Read ADC Register  ${E0_DATA_CH1_CH0}
    ${int_src}=             Read ADC Register  ${E0_INT_SOURCE}
    # Should have bit 0 set (channel 0 out of bounds)
    ${bit0}=                Evaluate  ${int_src} & 1
    Should Be Equal As Numbers  ${bit0}  1
    # Clear via W1C
    Write ADC Register      ${E0_INT_SOURCE}  0x1
    ${val}=                 Read ADC Register  ${E0_INT_SOURCE}
    Should Be Equal As Numbers  ${val}  0x0

INT Control Should Mask To 8 Bits
    [Documentation]         INT_CTRL only uses lower 8 bits
    [Tags]                  aspeed  adc  register
    Create AST2600 Machine
    Write ADC Register      ${E0_INT_CTRL}  0xFFFFFFFF
    ${val}=                 Read ADC Register  ${E0_INT_CTRL}
    Should Be Equal As Numbers  ${val}  0xFF

Compensating Register Should Mask To 4 Bits
    [Documentation]         COMPENSATING register only uses lower 4 bits
    [Tags]                  aspeed  adc  register
    Create AST2600 Machine
    Write ADC Register      ${E0_COMPENSATING}  0xFFFFFFFF
    ${val}=                 Read ADC Register  ${E0_COMPENSATING}
    Should Be Equal As Numbers  ${val}  0xF

Engine 1 Should Be Independent
    [Documentation]         Engine 1 registers are independent from Engine 0
    [Tags]                  aspeed  adc  engine
    Create AST2600 Machine
    Write ADC Register      ${E0_ENGINE_CTRL}  0x1
    Write ADC Register      ${E1_ENGINE_CTRL}  0x0
    ${val0}=                Read ADC Register  ${E0_ENGINE_CTRL}
    ${val1}=                Read ADC Register  ${E1_ENGINE_CTRL}
    # Engine 0 enabled (0x101), Engine 1 disabled (0x0)
    Should Be Equal As Numbers  ${val0}  0x101
    Should Be Equal As Numbers  ${val1}  0x0

Engine 1 Should Have Same Reset Values
    [Documentation]         Engine 1 VGA and Clock resets match Engine 0
    [Tags]                  aspeed  adc  register
    Create AST2600 Machine
    ${val}=                 Read ADC Register  ${E1_VGA_DETECT}
    Should Be Equal As Numbers  ${val}  0xF
    ${val}=                 Read ADC Register  ${E1_CLOCK_CTRL}
    Should Be Equal As Numbers  ${val}  0xF

Hysteresis Register Should Be Masked
    [Documentation]         Hysteresis mask is 0x83FF3FFF
    [Tags]                  aspeed  adc  register
    Create AST2600 Machine
    # Hysteresis CH0 at offset 0x040
    Execute Command         adc WriteDoubleWord 0x040 0xFFFFFFFF
    ${val}=  Execute Command    adc ReadDoubleWord 0x040
    Should Be Equal As Numbers  ${val.strip()}  0x83FF3FFF
