*** Variables ***
${FREQUENCY}                    25000
${REPL_STRING}=                 SEPARATOR=
...  """                                                               ${\n}
...  rtcc: Timers.SiLabs_RTCC_1 @ sysbus <0x0, +0x4000>                ${\n}
...  ${SPACE*4}frequency: ${FREQUENCY}                                 ${\n}
...  """
# Registers
${CFG_REG}                      0x0008
${CMD_REG}                      0x000C
${STATUS_REG}                   0x0010
${IF_REG}                       0x0014
${IEN_REG}                      0x0018
${CNT_REG}                      0x0020
${CC0_CTRL_REG}                 0x0030
${CC0_OUTPUT_COMPARE_REG}       0x0034
${CC1_CTRL_REG}                 0x003C
${CC1_OUTPUT_COMPARE_REG}       0x0040
${CC2_CTRL_REG}                 0x0048
${CC2_OUTPUT_COMPARE_REG}       0x004C

# Config register fields
${CONFIG_PRECNT_CC0_TOP_VALUE_ENABLE}  0x00000002
${CONFIG_CNT_CC1_TOP_VALUE_ENABLE}     0x00000004

# Status register fields
${STATUS_RUNNING}                      0x00000001


*** Keywords ***
Create Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL_STRING}

Start Command
    Execute Command             sysbus.rtcc WriteDoubleWord ${CMD_REG} 0x1

Stop Command
    Execute Command             sysbus.rtcc WriteDoubleWord ${CMD_REG} 0x2

Assert IRQ Is Set
    ${irqState}=                    Execute Command  sysbus.rtcc IRQ
    Should Contain                  ${irqState}  GPIO: set

Assert IRQ Is Unset
    ${irqState}=                    Execute Command  sysbus.rtcc IRQ
    Should Contain                  ${irqState}  GPIO: unset


*** Test Cases ***
Start/Stop Counter
    Create Machine
    # Basic configuration (prescaler mode, divider set to 1, not PRECNT / CNT top values)
    Execute Command               sysbus.rtcc WriteDoubleWord ${CFG_REG} 0
    # Start the Counter
    Start Command
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  ${STATUS_RUNNING}
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Assert IRQ Is Unset
    # Stop the Counter
    Stop Command
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Assert IRQ Is Unset
    # Start the Counter (again)
    Start Command
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  ${STATUS_RUNNING}
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Assert IRQ Is Unset

Main Counter Tick Interrupt
    Create Machine
    # Basic configuration (prescaler mode, divider set to 1, not PRECNT / CNT top values)
    Execute Command               sysbus.rtcc WriteDoubleWord ${CFG_REG} 0
    # Enable main counter tick interrupt
    Execute Command               sysbus.rtcc WriteDoubleWord ${IEN_REG} 0x2
    # Start the Counter
    Start Command
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  ${STATUS_RUNNING}
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               emulation RunFor "0.001"
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 0.001
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Assert IRQ Is Set
    Execute Command               sysbus.rtcc WriteDoubleWord ${IF_REG} 0x0
    Assert IRQ Is Unset
    Execute Command               emulation RunFor "0.001"
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 0.002
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Assert IRQ Is Set
    Execute Command               sysbus.rtcc WriteDoubleWord ${IF_REG} 0x0
    Assert IRQ Is Unset
    # Disable main counter tick interrupt
    Execute Command               sysbus.rtcc WriteDoubleWord ${IEN_REG} 0x0
    Execute Command               emulation RunFor "0.998"
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Assert IRQ Is Unset

Counter Output Compare
    Create Machine
    # Prescaler mode, divider set to 1, CNT top value enabled and set)
    Execute Command               sysbus.rtcc WriteDoubleWord ${CFG_REG} ${CONFIG_CNT_CC1_TOP_VALUE_ENABLE}
    # Configure CC1 in output compare mode and set the output compare value
    Execute Command               sysbus.rtcc WriteDoubleWord ${CC1_CTRL_REG} 0x02
    Execute Command               sysbus.rtcc WriteDoubleWord ${CC1_OUTPUT_COMPARE_REG} ${FREQUENCY}
    # Enable overflow interrupt
    Execute Command               sysbus.rtcc WriteDoubleWord ${IEN_REG} 0x1
    # Start the Counter
    Start Command
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  ${STATUS_RUNNING}
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               emulation RunFor "1"
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               sysbus.rtcc WriteDoubleWord ${IF_REG} 0x0
    Assert IRQ Is Unset
    # Disable CNT top value
    Execute Command               sysbus.rtcc WriteDoubleWord ${CFG_REG} 0
    # Enable CC1 interrupt / disable overflow interrupt
    Execute Command               sysbus.rtcc WriteDoubleWord ${IEN_REG} 0x40
    ${compare_val}                evaluate  ${FREQUENCY} * 1
    Execute Command               sysbus.rtcc WriteDoubleWord ${CC1_OUTPUT_COMPARE_REG} ${compare_val}
    Execute Command               emulation RunFor "1"
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  ${compare_val}
    Execute Command               sysbus.rtcc WriteDoubleWord ${IF_REG} 0x0
    Assert IRQ Is Unset
    ${compare_val}                evaluate  ${FREQUENCY} * 2
    Execute Command               sysbus.rtcc WriteDoubleWord ${CC1_OUTPUT_COMPARE_REG} ${compare_val}
    Execute Command               emulation RunFor "1"
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  ${compare_val}
    Execute Command               sysbus.rtcc WriteDoubleWord ${IF_REG} 0x0
    Assert IRQ Is Unset

Divider
    Create Machine
    # Prescaler mode, divider set to 8
    Execute Command               sysbus.rtcc WriteDoubleWord ${CFG_REG} 0x30
    # Configure CC0 in output compare mode and set the output compare value
    Execute Command               sysbus.rtcc WriteDoubleWord ${CC0_CTRL_REG} 0x02
    ${compare_val}                evaluate  ${FREQUENCY} / 8
    Execute Command               sysbus.rtcc WriteDoubleWord ${CC0_OUTPUT_COMPARE_REG} ${compare_val}
    # Enable CC0 interrupts
    Execute Command               sysbus.rtcc WriteDoubleWord ${IEN_REG} 0x10
    # Start the Counter
    Start Command
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  ${STATUS_RUNNING}
    Execute Command               emulation RunFor "0.9"
    Assert IRQ Is Unset
    Execute Command               emulation RunFor "0.1"
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.rtcc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  ${compare_val}
    Execute Command               sysbus.rtcc WriteDoubleWord ${IF_REG} 0x0
    Assert IRQ Is Unset