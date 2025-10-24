*** Variables ***
${IP_VERSION}                   0
${CLOCK_FREQUENCY}              50000
# A prescaler value of 1 actually causes the clock frequency to be halved
${PRESCALER}                    1
${FREQUENCY}                    25000
${REPL_STRING}=                 SEPARATOR=
...  """                                                               ${\n}
...  timer: Timers.SiLabs_TIMER_${IP_VERSION} @ sysbus <0x0, +0x4000>  ${\n}
...  ${SPACE*4}frequency: ${CLOCK_FREQUENCY}                           ${\n}
...  """

# Register definitions for different IP versions
&{REGS_V0}    CFG=0x0004    CTRL=0x0008    CMD=0x000C    STATUS=0x0010    IF=0x0014    IEN=0x0018    TOP=0x001C    CNT=0x0024    CCO_CFG=0x0060    CCO_CTRL=0x0064    CCO_OC=0x0070    CC1_CFG=0x0080    CC1_CTRL=0x0084    CC1_OC=0x0088
&{REGS_V2}    CFG=0x0004    CTRL=0x0008    CMD=0x000C    STATUS=0x0010    IF=0x0018    IEN=0x001C    TOP=0x0020    CNT=0x0028    CCO_CFG=0x0060    CCO_CTRL=0x0064    CCO_OC=0x0070    CC1_CFG=0x0090    CC1_CTRL=0x0094    CC1_OC=0x00A0

*** Keywords ***
Setup Registers
    # Set register variables based on IP_VERSION
    IF  ${IP_VERSION} == 0
        Set Suite Variable    ${CFG_REG}      ${REGS_V0.CFG}
        Set Suite Variable    ${CTRL_REG}     ${REGS_V0.CTRL}
        Set Suite Variable    ${CMD_REG}      ${REGS_V0.CMD}
        Set Suite Variable    ${STATUS_REG}   ${REGS_V0.STATUS}
        Set Suite Variable    ${IF_REG}       ${REGS_V0.IF}
        Set Suite Variable    ${IEN_REG}      ${REGS_V0.IEN}
        Set Suite Variable    ${TOP_REG}      ${REGS_V0.TOP}
        Set Suite Variable    ${CNT_REG}      ${REGS_V0.CNT}
        Set Suite Variable    ${CCO_CFG}      ${REGS_V0.CCO_CFG}
        Set Suite Variable    ${CCO_CTRL}     ${REGS_V0.CCO_CTRL}
        Set Suite Variable    ${CCO_OC}       ${REGS_V0.CCO_OC}
        Set Suite Variable    ${CC1_CFG}      ${REGS_V0.CC1_CFG}
        Set Suite Variable    ${CC1_CTRL}     ${REGS_V0.CC1_CTRL}
        Set Suite Variable    ${CC1_OC}       ${REGS_V0.CC1_OC}
    ELSE IF  ${IP_VERSION} == 2
        Set Suite Variable    ${CFG_REG}      ${REGS_V2.CFG}
        Set Suite Variable    ${CTRL_REG}     ${REGS_V2.CTRL}
        Set Suite Variable    ${CMD_REG}      ${REGS_V2.CMD}
        Set Suite Variable    ${STATUS_REG}   ${REGS_V2.STATUS}
        Set Suite Variable    ${IF_REG}       ${REGS_V2.IF}
        Set Suite Variable    ${IEN_REG}      ${REGS_V2.IEN}
        Set Suite Variable    ${TOP_REG}      ${REGS_V2.TOP}
        Set Suite Variable    ${CNT_REG}      ${REGS_V2.CNT}
        Set Suite Variable    ${CCO_CFG}      ${REGS_V2.CCO_CFG}
        Set Suite Variable    ${CCO_CTRL}     ${REGS_V2.CCO_CTRL}
        Set Suite Variable    ${CCO_OC}       ${REGS_V2.CCO_OC}
        Set Suite Variable    ${CC1_CFG}      ${REGS_V2.CC1_CFG}
        Set Suite Variable    ${CC1_CTRL}     ${REGS_V2.CC1_CTRL}
        Set Suite Variable    ${CC1_OC}       ${REGS_V2.CC1_OC}
    ELSE
        Fail  Unsupported IP version: ${IP_VERSION} 
    END

Create Machine
    Setup Registers
    Execute Command                 mach create "test"
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL_STRING}
    Execute Command                 logLevel 1 sysbus.timer

Configure Timer
    [Arguments]  ${down_count}  ${one_shot}
    ${reg_val}                      Evaluate  ${PRESCALER} << 18
    IF  ${down_count}
        ${reg_val}                  Evaluate  ${reg_val} | 0x1
    END
    IF  ${one_shot}
        ${reg_val}                  Evaluate  ${reg_val} | 0x10
    END
    Execute Command                 sysbus WriteDoubleWord ${CFG_REG} ${reg_val}

Set Top Value
    [Arguments]  ${top_val}
    Execute Command                 sysbus WriteDoubleWord ${TOP_REG} ${top_val}

Start Command
    Execute Command                 sysbus.timer WriteDoubleWord ${CMD_REG} 0x1

Stop Command
    Execute Command                 sysbus.timer WriteDoubleWord ${CMD_REG} 0x2

Assert Counter Value
    [Arguments]  ${expected_val}
    ${current_val}=                 Execute Command  sysbus.timer ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers     ${expected_val}  ${current_val}

Assert Timer Is Running
    [Arguments]  ${is_running}
    ${read_val}=                    Execute Command  sysbus.timer ReadDoubleWord ${STATUS_REG}
    ${read_val}=                    Convert To Integer  ${read_val}
    ${check_val}                    Evaluate  ${read_val} & 0x1
    IF  ${is_running}
        Should Be Equal As Integers  ${check_val}  0x1
    ELSE
        Should Be Equal As Integers  ${check_val}  0x0
    END

Assert IRQ Is Set
    ${irqState}=                    Execute Command  sysbus.timer IRQ
    Should Contain                  ${irqState}  GPIO: set

Assert IRQ Is Unset
    ${irqState}=                    Execute Command  sysbus.timer IRQ
    Should Contain                  ${irqState}  GPIO: unset

*** Test Cases ***
Overflow
    Create Machine
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    # Configure the timer to count up, no one-shot mode
    Configure Timer                 False  False
    # Enable all implemented interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IEN_REG} 0x7F3
    # Set top value so that the counter overflows right at the 2 second mark
    ${top_val}                      Evaluate  ${FREQUENCY} * 2
    Set Top Value                   ${top_val}
    Assert Timer Is Running         False
    # Start the timer
    Start Command
    Assert Timer Is Running         True
    Assert Counter Value            0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    ${check_val}                    Evaluate  ${FREQUENCY} * 1
    Assert Counter Value            ${check_val}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the overflow interrupt fired
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x1
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    # Upon overflow, expect the timer to restart from 0
    Assert Counter Value            0
    # Go around one more time
    Execute Command                 emulation RunFor "2"
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x1
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    ${check_val}                    Evaluate  ${FREQUENCY} * 1
    Assert Counter Value            ${check_val}
    Assert IRQ Is Unset
    # Stop the timer
    Stop Command
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    Assert Counter Value            0

Underflow
    Create Machine
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    # Configure the timer to count down, no one-shot mode
    Configure Timer                 True  False
    # Enable all implemented interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IEN_REG} 0x7F3
    # Set top value so that the counter overflows right at the 2 second mark
    ${top_val}                      Evaluate  ${FREQUENCY} * 2
    Set Top Value                   ${top_val}
    Assert Timer Is Running         False
    # Start the timer
    Start Command
    Assert Timer Is Running         True
    ${check_val}                    Evaluate  ${FREQUENCY} * 2
    Assert Counter Value            ${check_val}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    ${check_val}                    Evaluate  ${FREQUENCY} * 1
    Assert Counter Value            ${check_val}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the underflow interrupt fired
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x2
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    # Upon underflow, expect the timer to restart from the top value
    ${check_val}                    Evaluate  ${FREQUENCY} * 2
    Assert Counter Value            ${check_val}
    # Go around one more time
    Execute Command                 emulation RunFor "2"
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x2
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    ${check_val}                    Evaluate  ${FREQUENCY} * 1
    Assert Counter Value            ${check_val}
    Assert IRQ Is Unset
    # Stop the timer
    Stop Command
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    Assert Counter Value            0

One Shot Mode
    Create Machine
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    # Configure the timer to count up, one-shot mode
    Configure Timer                 False  True
    # Enable all implemented interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IEN_REG} 0x7F3
    # Set top value so that the counter overflows right at the 2 second mark
    ${top_val}                      Evaluate  ${FREQUENCY} * 2
    Set Top Value                   ${top_val}
    Assert Timer Is Running         False
    # Start the timer
    Start Command
    Assert Timer Is Running         True
    Assert Counter Value            0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    ${check_val}                    Evaluate  ${FREQUENCY} * 1
    Assert Counter Value            ${check_val}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the overflow interrupt fired
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x1
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    # Check that the timer is no longer running
    Assert Timer Is Running         False
    Execute Command                 emulation RunFor "2"
    Assert IRQ Is Unset

Channel Compare
    Create Machine
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    # Configure the timer to count up, no one-shot mode
    Configure Timer                 False  False
    # Enable all implemented interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IEN_REG} 0x7F3
    # Set top value so that the counter overflows right at the 5 second mark
    ${top_val}                      Evaluate  ${FREQUENCY} * 5
    Set Top Value                   ${top_val}
    Assert Timer Is Running         False
    # Start the timer
    Start Command
    Assert Timer Is Running         True
    Assert Counter Value            0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    ${check_val}                    Evaluate  ${FREQUENCY} * 1
    Assert Counter Value            ${check_val}
    Assert IRQ Is Unset
    # Set Channel 0 to hit the compare event right at the 3 second mark
    ${set_val}                      Evaluate  ${FREQUENCY} * 3
    Execute Command                 sysbus.timer WriteDoubleWord ${CCO_OC} ${set_val}
    Execute Command                 sysbus.timer WriteDoubleWord ${CCO_CFG} 0x2
    Execute Command                 emulation RunFor "1"
    ${check_val}                    Evaluate  ${FREQUENCY} * 2
    Assert Counter Value            ${check_val}
    Assert IRQ Is Unset
    # Set Channel 1 to hit the compare event right at the 4 second mark
    ${set_val}                      Evaluate  ${FREQUENCY} * 4
    Execute Command                 sysbus.timer WriteDoubleWord ${CC1_OC} ${set_val}
    Execute Command                 sysbus.timer WriteDoubleWord ${CC1_CFG} 0x2
    Execute Command                 emulation RunFor "1"
    # Check that (only) the CC0 interrupt fires
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x10
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the CC1 interrupt fires
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x20
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the overflow interrupt fired
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x1
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    # Go around one more time
    Execute Command                 emulation RunFor "3"
    # Check that (only) the CC0 interrupt fires
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x10
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the CC1 interrupt fires
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x20
    # Clear interrupts
    Execute Command                 sysbus.timer WriteDoubleWord ${IF_REG} 0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the overflow interrupt fired
    Assert IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.timer ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x1

