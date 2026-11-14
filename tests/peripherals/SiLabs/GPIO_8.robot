*** Settings ***
Test Setup                      Create Machine

*** Variables ***
${PLATFORM}                     SEPARATOR=\n
...  """
...  gpio: GPIOPort.SiLabs_GPIO_8 @ sysbus <0x40006000, +0x4000>
...  """

# Register offsets
${PORTA_MODEL}                  0x0034
${PORTA_DOUT}                   0x0040
${PORTA_DIN}                    0x0044
${PORTB_DOUT}                   0x0070
${PORTC_DOUT}                   0x00A0
${PORTD_DOUT}                   0x00D0

# External interrupt registers
${EXTINT_EXTIPSELL}             0x0400
${EXTINT_EXTIPSELH}             0x0404
${EXTINT_EXTIPINSELL}           0x0408
${EXTINT_EXTIPINSELH}           0x040C
${EXTINT_EXTIRISE}              0x0410
${EXTINT_EXTIFALL}              0x0414
${EXTINT_IF}                    0x0420
${EXTINT_IEN}                   0x0424

# Lock and status registers
${LOCK}                         0x0300
${STATUS_GPIOLOCKSTATUS}        0x0310

# SET/CLEAR/TOGGLE register offsets
${SET_REGISTER_OFFSET}          0x1000
${CLEAR_REGISTER_OFFSET}        0x2000
${TOGGLE_REGISTER_OFFSET}       0x3000

# Pin mode values
${PIN_MODE_INPUT}               0x1
${PIN_MODE_PUSHPULL}            0x4

# Port values
${PORT_A}                       0x0
${PORT_B}                       0x1
${PORT_C}                       0x2
${PORT_D}                       0x3

*** Keywords ***
Create Machine
    Renode Test Setup
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${PLATFORM}

Update Register
    [Arguments]                 ${register}  ${mask}  ${value}
    ${current}=                 Execute Command  gpio ReadDoubleWord ${register}
    Execute Command             gpio WriteDoubleWord ${register} ${{ (int($current, 16) & ~${mask} & 0xFFFFFFFF) | ${value} }}

Set Pin Mode
    [Arguments]                 ${port}  ${pin}  ${mode}
    ${shift}=                   Evaluate  ${pin} % 8 * 4
    Update Register             ${{ ${port} * 0x30 + (0x34 if ${pin} < 8 else 0x3C) }}  ${{ 0xF << ${shift} }}  ${{ ${mode} << ${shift} }}

Write Pin
    [Arguments]                 ${port}  ${pin}  ${value}
    Update Register             ${{ ${port} * 0x30 + 0x40 }}  ${{ 1 << ${pin} }}  ${{ ${value} << ${pin} }}

Configure External Interrupt
    [Arguments]                 ${extint}  ${port}  ${pin}  ${rising}  ${falling}  ${enable}
    ${shift}=                   Evaluate  ${extint} % 8 * 4
    # Configure port select
    Update Register             ${{ ${EXTINT_EXTIPSELL} if ${extint} < 8 else ${EXTINT_EXTIPSELH} }}
    ...                         ${{ 0x3 << ${shift} }}  ${{ ${port} << ${shift} }}
    # Configure pin select
    Update Register             ${{ ${EXTINT_EXTIPINSELL} if ${extint} < 8 else ${EXTINT_EXTIPINSELH} }}
    ...                         ${{ 0x3 << ${shift} }}  ${{ ${pin} << ${shift} }}
    # Configure rising edge
    Update Register             ${EXTINT_EXTIRISE}  ${{ 1 << ${extint} }}  ${{ int(${rising}) << ${extint} }}
    # Configure falling edge
    Update Register             ${EXTINT_EXTIFALL}  ${{ 1 << ${extint} }}  ${{ int(${falling}) << ${extint} }}
    # Enable interrupt
    Update Register             ${EXTINT_IEN}  ${{ 1 << ${extint} }}  ${{ int(${enable}) << ${extint} }}

Set Up External Interrupt
    [Arguments]                 ${extint}  ${initial}  ${rising}  ${falling}
    # Configure pin as input
    Set Pin Mode                ${PORT_A}  ${extint}  ${PIN_MODE_INPUT}
    # Set pin to known initial state before configuring interrupt
    Execute Command             gpio OnGPIO ${extint} ${initial}
    # Configure external interrupt on Port A, with the pin select equal to the interrupt number (but don't enable yet)
    Configure External Interrupt  ${extint}  ${PORT_A}  ${extint}  ${rising}  ${falling}  False
    # Now enable the interrupt - this way UpdateInterrupts won't trigger on stale state
    Update Register             ${EXTINT_IEN}  ${{ 1 << ${extint} }}  ${{ 1 << ${extint} }}
    # Clear any pending interrupts
    Execute Command             gpio WriteDoubleWord ${{ ${EXTINT_IF} + ${CLEAR_REGISTER_OFFSET} }} 0xFFFF

Clear Interrupt Flag
    [Arguments]                 ${extint}
    # Clear interrupt flag using CLR register
    Execute Command             gpio WriteDoubleWord ${{ ${EXTINT_IF} + ${CLEAR_REGISTER_OFFSET} }} ${{ 1 << ${extint} }}
    # Trigger UpdateInterrupts by writing IEN back unchanged (it has a write callback)
    ${ien}=                     Execute Command  gpio ReadDoubleWord ${EXTINT_IEN}
    Execute Command             gpio WriteDoubleWord ${EXTINT_IEN} ${ien}

Field Should Be
    [Arguments]                 ${register}  ${shift}  ${expected}  ${mask}=0x1
    ${value}=                   Execute Command  gpio ReadDoubleWord ${register}
    Should Be Equal As Integers  ${{ (int($value, 16) >> ${shift}) & ${mask} }}  ${expected}

IRQ Should Be
    [Arguments]                 ${irq}  ${state}
    ${irqState}=                Execute Command  gpio ${irq}
    Should Contain              ${irqState}  GPIO: ${state}

*** Test Cases ***
Should Configure Pin Mode
    # Test setting pin to input mode
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_INPUT}
    Field Should Be             ${PORTA_MODEL}  0  ${PIN_MODE_INPUT}  mask=0xF
    # Test setting pin to output mode
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_PUSHPULL}
    Field Should Be             ${PORTA_MODEL}  0  ${PIN_MODE_PUSHPULL}  mask=0xF

Should Write Output Pin
    # Configure pin as output
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_PUSHPULL}
    # Write high
    Write Pin                   ${PORT_A}  0  1
    Field Should Be             ${PORTA_DOUT}  0  1
    # Write low
    Write Pin                   ${PORT_A}  0  0
    Field Should Be             ${PORTA_DOUT}  0  0

Should Read Input Pin
    # Configure pin as input
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_INPUT}
    # Set pin state externally (simulate external input)
    Execute Command             gpio OnGPIO 0 true
    Field Should Be             ${PORTA_DIN}  0  1
    # Clear pin state
    Execute Command             gpio OnGPIO 0 false
    Field Should Be             ${PORTA_DIN}  0  0

Should Set Output Through SET Register
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_PUSHPULL}
    # Use SET register to set bit
    Execute Command             gpio WriteDoubleWord ${{ ${PORTA_DOUT} + ${SET_REGISTER_OFFSET} }} 0x1
    Field Should Be             ${PORTA_DOUT}  0  1

Should Clear Output Through CLEAR Register
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_PUSHPULL}
    # Set bit first
    Write Pin                   ${PORT_A}  0  1
    Field Should Be             ${PORTA_DOUT}  0  1
    # Use CLEAR register to clear bit
    Execute Command             gpio WriteDoubleWord ${{ ${PORTA_DOUT} + ${CLEAR_REGISTER_OFFSET} }} 0x1
    Field Should Be             ${PORTA_DOUT}  0  0

Should Toggle Output Through TOGGLE Register
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_PUSHPULL}
    # Initial state: low
    Write Pin                   ${PORT_A}  0  0
    Field Should Be             ${PORTA_DOUT}  0  0
    # Use TOGGLE register to toggle bit
    Execute Command             gpio WriteDoubleWord ${{ ${PORTA_DOUT} + ${TOGGLE_REGISTER_OFFSET} }} 0x1
    Field Should Be             ${PORTA_DOUT}  0  1
    # Toggle again
    Execute Command             gpio WriteDoubleWord ${{ ${PORTA_DOUT} + ${TOGGLE_REGISTER_OFFSET} }} 0x1
    Field Should Be             ${PORTA_DOUT}  0  0

Should Trigger External Interrupt On Rising Edge
    # External interrupt 0 for Port A, Pin 0, rising edge, initial state low
    Set Up External Interrupt   0  false  rising=True  falling=False
    # Trigger rising edge
    Execute Command             gpio OnGPIO 0 false
    Execute Command             gpio OnGPIO 0 true
    # Check interrupt flag is set
    Field Should Be             ${EXTINT_IF}  0  1
    # Check Even IRQ is set (interrupt 0 is even)
    IRQ Should Be               EvenIRQ  set
    Clear Interrupt Flag        0
    IRQ Should Be               EvenIRQ  unset

Should Trigger External Interrupt On Falling Edge
    # External interrupt 1 for Port A, Pin 1 (pin select 1 in group 0), falling edge, initial state high
    Set Up External Interrupt   1  true  rising=False  falling=True
    # Trigger falling edge
    Execute Command             gpio OnGPIO 1 true
    Execute Command             gpio OnGPIO 1 false
    # Check interrupt flag is set
    Field Should Be             ${EXTINT_IF}  1  1
    # Check Odd IRQ is set (interrupt 1 is odd)
    IRQ Should Be               OddIRQ  set
    Clear Interrupt Flag        1
    IRQ Should Be               OddIRQ  unset

Should Trigger External Interrupt On Both Edges
    # External interrupt 2 for Port A, Pin 2 (pin select 2 in group 0), both edges, initial state low
    Set Up External Interrupt   2  false  rising=True  falling=True
    # Test rising edge
    Execute Command             gpio OnGPIO 2 false
    Execute Command             gpio OnGPIO 2 true
    Field Should Be             ${EXTINT_IF}  2  1
    IRQ Should Be               EvenIRQ  set
    Clear Interrupt Flag        2
    IRQ Should Be               EvenIRQ  unset
    # Test falling edge
    Execute Command             gpio OnGPIO 2 true
    Execute Command             gpio OnGPIO 2 false
    Field Should Be             ${EXTINT_IF}  2  1
    IRQ Should Be               EvenIRQ  set

Should Not Trigger Disabled External Interrupt
    # Configure pin as input
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_INPUT}
    # Configure external interrupt 0 but disable it
    Configure External Interrupt  0  ${PORT_A}  0  True  False  False
    # A direct IF write sets the flags (IF is read/write), so this sets them all
    Execute Command             gpio WriteDoubleWord ${EXTINT_IF} 0xFFFFFFFF
    # Clear all interrupt flags using the CLR register
    Execute Command             gpio WriteDoubleWord ${{ ${EXTINT_IF} + ${CLEAR_REGISTER_OFFSET} }} 0xFFFFFFFF
    # Trigger rising edge
    Execute Command             gpio OnGPIO 0 false
    Execute Command             gpio OnGPIO 0 true
    # Interrupt flag should not be set (interrupt is disabled)
    Field Should Be             ${EXTINT_IF}  0  0
    IRQ Should Be               EvenIRQ  unset

Should Lock Configuration
    # Unlock configuration
    Execute Command             gpio WriteDoubleWord ${LOCK} 0xA534
    Field Should Be             ${STATUS_GPIOLOCKSTATUS}  0  0
    # Lock configuration
    Execute Command             gpio WriteDoubleWord ${LOCK} 0x0
    Field Should Be             ${STATUS_GPIOLOCKSTATUS}  0  1

Should Configure Multiple Ports
    # Configure pins on different ports
    Set Pin Mode                ${PORT_A}  0  ${PIN_MODE_PUSHPULL}
    Set Pin Mode                ${PORT_B}  5  ${PIN_MODE_PUSHPULL}
    Set Pin Mode                ${PORT_C}  10  ${PIN_MODE_PUSHPULL}
    Set Pin Mode                ${PORT_D}  15  ${PIN_MODE_PUSHPULL}
    # Write to different ports
    Write Pin                   ${PORT_A}  0  1
    Write Pin                   ${PORT_B}  5  1
    Write Pin                   ${PORT_C}  10  1
    Write Pin                   ${PORT_D}  15  1
    # Verify all pins are set
    Field Should Be             ${PORTA_DOUT}  0  1
    Field Should Be             ${PORTB_DOUT}  5  1
    Field Should Be             ${PORTC_DOUT}  10  1
    Field Should Be             ${PORTD_DOUT}  15  1
