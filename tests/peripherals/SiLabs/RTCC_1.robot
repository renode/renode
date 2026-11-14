*** Settings ***
Test Setup                      Create Machine

*** Variables ***
${FREQUENCY}                    25000
${PLATFORM}                     SEPARATOR=\n
...  """
...  rtcc: Timers.SiLabs_RTCC_1 @ sysbus <0x0, +0x4000>
...  ${SPACE*4}frequency: ${FREQUENCY}
...  """
# Registers
${CFG}                          0x0008
${CMD}                          0x000C
${STATUS}                       0x0010
${IF}                           0x0014
${IEN}                          0x0018
${CNT}                          0x0020
${CC0_CTRL}                     0x0030
${CC0_OUTPUT_COMPARE}           0x0034
${CC1_CTRL}                     0x003C
${CC1_OUTPUT_COMPARE}           0x0040

# Config register fields
${CONFIG_CNT_CC1_TOP_VALUE_ENABLE}  0x00000004

# Status register fields
${STATUS_RUNNING}               0x00000001

*** Keywords ***
Create Machine
    Renode Test Setup
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${PLATFORM}

Register Should Be
    [Arguments]                 ${register}  ${expected}
    ${value}=                   Execute Command  rtcc ReadDoubleWord ${register}
    Should Be Equal As Integers  ${value}  ${expected}

IRQ Should Be
    [Arguments]                 ${state}
    ${irq}=                     Execute Command  rtcc IRQ
    Should Contain              ${irq}  GPIO: ${state}

# Start the Counter
Start Counter
    Execute Command             rtcc WriteDoubleWord ${CMD} 0x1
    Register Should Be          ${STATUS}  ${STATUS_RUNNING}

*** Test Cases ***
Should Start And Stop Counter
    # Basic configuration (prescaler mode, divider set to 1, no PRECNT / CNT top values)
    Execute Command             rtcc WriteDoubleWord ${CFG} 0
    Start Counter
    Register Should Be          ${CNT}  0
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${FREQUENCY}
    IRQ Should Be               unset
    # Stop the Counter
    Execute Command             rtcc WriteDoubleWord ${CMD} 0x2
    Register Should Be          ${STATUS}  0
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${FREQUENCY}
    IRQ Should Be               unset
    # Start the Counter (again)
    Start Counter
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 2 }}
    IRQ Should Be               unset

Should Raise Main Counter Tick Interrupt
    # Basic configuration (prescaler mode, divider set to 1, no PRECNT / CNT top values)
    Execute Command             rtcc WriteDoubleWord ${CFG} 0
    # Enable main counter tick interrupt
    Execute Command             rtcc WriteDoubleWord ${IEN} 0x2
    Start Counter
    Register Should Be          ${CNT}  0
    Execute Command             emulation RunFor "0.001"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 0.001 }}
    IRQ Should Be               set
    Execute Command             rtcc WriteDoubleWord ${IF} 0x0
    IRQ Should Be               unset
    Execute Command             emulation RunFor "0.001"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 0.002 }}
    IRQ Should Be               set
    Execute Command             rtcc WriteDoubleWord ${IF} 0x0
    IRQ Should Be               unset
    # Disable main counter tick interrupt
    Execute Command             rtcc WriteDoubleWord ${IEN} 0x0
    Execute Command             emulation RunFor "0.998"
    Register Should Be          ${CNT}  ${FREQUENCY}
    IRQ Should Be               unset

Should Raise Counter Output Compare Interrupt
    # Prescaler mode, divider set to 1, CNT top value enabled and set
    Execute Command             rtcc WriteDoubleWord ${CFG} ${CONFIG_CNT_CC1_TOP_VALUE_ENABLE}
    # Configure CC1 in output compare mode and set the output compare value
    Execute Command             rtcc WriteDoubleWord ${CC1_CTRL} 0x02
    Execute Command             rtcc WriteDoubleWord ${CC1_OUTPUT_COMPARE} ${FREQUENCY}
    # Enable overflow interrupt
    Execute Command             rtcc WriteDoubleWord ${IEN} 0x1
    Start Counter
    Register Should Be          ${CNT}  0
    Execute Command             emulation RunFor "1"
    IRQ Should Be               set
    Register Should Be          ${CNT}  0
    Execute Command             rtcc WriteDoubleWord ${IF} 0x0
    IRQ Should Be               unset
    # Disable CNT top value
    Execute Command             rtcc WriteDoubleWord ${CFG} 0
    # Enable CC1 interrupt / disable overflow interrupt
    Execute Command             rtcc WriteDoubleWord ${IEN} 0x40
    FOR  ${compare}  IN  ${FREQUENCY}  ${{ ${FREQUENCY} * 2 }}
        Execute Command         rtcc WriteDoubleWord ${CC1_OUTPUT_COMPARE} ${compare}
        Execute Command         emulation RunFor "1"
        IRQ Should Be           set
        Register Should Be      ${CNT}  ${compare}
        Execute Command         rtcc WriteDoubleWord ${IF} 0x0
        IRQ Should Be           unset
    END

Should Divide Counter Clock
    # Prescaler mode, divider set to 8
    Execute Command             rtcc WriteDoubleWord ${CFG} 0x30
    # Configure CC0 in output compare mode and set the output compare value
    Execute Command             rtcc WriteDoubleWord ${CC0_CTRL} 0x02
    Execute Command             rtcc WriteDoubleWord ${CC0_OUTPUT_COMPARE} ${{ ${FREQUENCY} // 8 }}
    # Enable CC0 interrupts
    Execute Command             rtcc WriteDoubleWord ${IEN} 0x10
    Start Counter
    Execute Command             emulation RunFor "0.9"
    IRQ Should Be               unset
    Execute Command             emulation RunFor "0.1"
    IRQ Should Be               set
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} // 8 }}
    Execute Command             rtcc WriteDoubleWord ${IF} 0x0
    IRQ Should Be               unset
