*** Variables ***
${CLOCK_FREQUENCY}                  50000
# A prescaler value of 1 actually causes the clock frequency to be halved
${PRESCALER}                        1
${FREQUENCY}                        25000

# Register definitions for different IP versions
&{REGS_V0}    CFG=0x0004    CTRL=0x0008    CMD=0x000C    STATUS=0x0010    IF=0x0014    IEN=0x0018
...           TOP=0x001C    CNT=0x0024    CC0_CFG=0x0060    CC0_CTRL=0x0064    CC0_OC=0x0068    CC1_CFG=0x0080
...           CC1_CTRL=0x0084    CC1_OC=0x0088
&{REGS_V1}    CFG=0x0004    CTRL=0x0008    CMD=0x000C    STATUS=0x0010    IF=0x0014    IEN=0x0018
...           TOP=0x001C    CNT=0x0024    EN=0x0030    CC0_CFG=0x0060    CC0_CTRL=0x0064    CC0_OC=0x0068
...           CC1_CFG=0x0080    CC1_CTRL=0x0084    CC1_OC=0x0088
&{REGS_V2}    CFG=0x0004    CTRL=0x0008    CMD=0x000C    STATUS=0x0010    IF=0x0018    IEN=0x001C
...           TOP=0x0020    CNT=0x0028    EN=0x0030    CC0_CFG=0x0060    CC0_CTRL=0x0064    CC0_OC=0x0070
...           CC1_CFG=0x0090    CC1_CTRL=0x0094    CC1_OC=0x00A0

*** Keywords ***
Create Machine
    [Arguments]                     ${ip_version}  ${hfxo_frequency}=${CLOCK_FREQUENCY}  ${width}=32
    Reset Emulation
    Set Test Variable               ${IP_VERSION}  ${ip_version}
    # Set register variables based on IP_VERSION
    Set Test Variable               ${REGS}  ${REGS_V${ip_version}}
    # Width is a TIMER_1 constructor argument
    ${width_line}=  Set Variable If  ${ip_version} == 1  ${SPACE*4}width: ${width}  ${EMPTY}
    ${repl}=  Catenate              SEPARATOR=\n
    ...  """
    ...  timer: Timers.SiLabs_TIMER_${ip_version} @ sysbus <0x0, +0x4000>
    ...  ${width_line}
    ...  cmu: Miscellaneous.SiLabs.SiLabs_CMU_1 @ sysbus <0x4000, +0x4000>
    ...  ${SPACE*4}hfxoFrequency: ${hfxo_frequency}
    ...  """
    Execute Command                 mach create "test"
    Execute Command                 machine LoadPlatformDescriptionFromString ${repl}
    Execute Command                 logLevel 1 sysbus.timer

Create Width Machine
    [Arguments]                     ${width}
    # 1 kHz so each RunFor "0.001" is one counter tick. Width is a constructor argument.
    Create Machine                  1  hfxo_frequency=1000  width=${width}

Write Register
    [Arguments]                     ${register}  ${value}
    Execute Command                 sysbus.timer WriteDoubleWord ${register} ${value}

Register Should Be Equal
    [Arguments]                     ${register}  ${expected}
    ${value}=  Execute Command      sysbus.timer ReadDoubleWord ${register}
    Should Be Equal As Integers     ${value}  ${expected}

# CFG and CCx_CFG are WSTATIC on IP versions with EN, so write them before enabling.
# TIMER_0 has no EN.
Enable Timer Peripheral
    IF  ${IP_VERSION} != 0
        Write Register              ${REGS.EN}  0x1
    END

Configure Timer
    [Arguments]                     ${down_count}  ${one_shot}
    Write Register                  ${REGS.CFG}  ${{${PRESCALER} << 18 | (0x1 if ${down_count} else 0) | (0x10 if ${one_shot} else 0)}}
    Enable Timer Peripheral

Enable All Interrupts
    Write Register                  ${REGS.IEN}  0x7F3

Clear Interrupt Flags
    Write Register                  ${REGS.IF}  0

Assert Overflow Interrupt Flag
    Register Should Be Equal        ${REGS.IF}  0x1

Assert Underflow Interrupt Flag
    Register Should Be Equal        ${REGS.IF}  0x2

Assert CC0 Interrupt Flag
    Register Should Be Equal        ${REGS.IF}  0x10

Assert CC1 Interrupt Flag
    Register Should Be Equal        ${REGS.IF}  0x20

Start Command
    Write Register                  ${REGS.CMD}  0x1

Stop Command
    Write Register                  ${REGS.CMD}  0x2

Assert Counter Value
    [Arguments]                     ${expected_val}
    Register Should Be Equal        ${REGS.CNT}  ${expected_val}

Assert Timer Is Running
    [Arguments]                     ${is_running}
    ${status}=  Execute Command     sysbus.timer ReadDoubleWord ${REGS.STATUS}
    Should Be Equal As Integers     ${{int($status, 16) & 0x1}}  ${{int(${is_running})}}

Assert IRQ Is ${state:(Set|Unset)}
    ${irqState}=  Execute Command   sysbus.timer IRQ
    Should Contain                  ${irqState}  GPIO: ${state.lower()}

# Up-count holds TOP for one counter clock, then wraps. At 25 kHz that clock is 40 us.
Advance Past Top
    Execute Command                 emulation RunFor "0.00004"

Timer Should Overflow
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    # Configure the timer to count up, no one-shot mode
    Configure Timer                 False  False
    # Enable all implemented interrupts
    Enable All Interrupts
    # TOP is the counter maximum. After two seconds the counter equals TOP.
    # The next tick wraps to 0 and sets the overflow flag.
    ${top_val}=  Set Variable       ${{${FREQUENCY} * 2}}
    Write Register                  ${REGS.TOP}  ${top_val}
    Assert Timer Is Running         False
    # Start the timer
    Start Command
    Assert Timer Is Running         True
    Assert Counter Value            0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${FREQUENCY}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${top_val}
    Assert IRQ Is Unset
    Advance Past Top
    # Check that (only) the overflow interrupt fired
    Assert IRQ Is Set
    Assert Overflow Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    # Upon overflow, expect the timer to restart from 0
    Assert Counter Value            0
    # Go around one more time
    Execute Command                 emulation RunFor "2"
    Assert Counter Value            ${top_val}
    Assert IRQ Is Unset
    Advance Past Top
    Assert IRQ Is Set
    Assert Overflow Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${FREQUENCY}
    Assert IRQ Is Unset
    # Stop the timer
    Stop Command
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    Assert Counter Value            0

Timer Should Underflow
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    # Configure the timer to count down, no one-shot mode
    Configure Timer                 True  False
    # Enable all implemented interrupts
    Enable All Interrupts
    # Set top value so that the counter underflows right at the 2 second mark
    ${top_val}=  Set Variable       ${{${FREQUENCY} * 2}}
    Write Register                  ${REGS.TOP}  ${top_val}
    Assert Timer Is Running         False
    # Start the timer
    Start Command
    Assert Timer Is Running         True
    Assert Counter Value            ${top_val}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${FREQUENCY}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the underflow interrupt fired
    Assert IRQ Is Set
    Assert Underflow Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    # Upon underflow, expect the timer to restart from the top value
    Assert Counter Value            ${top_val}
    # Go around one more time
    Execute Command                 emulation RunFor "2"
    Assert IRQ Is Set
    Assert Underflow Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${FREQUENCY}
    Assert IRQ Is Unset
    # Stop the timer
    Stop Command
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    Assert Counter Value            0

One Shot Timer Should Stop After Overflow
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    # Configure the timer to count up, one-shot mode
    Configure Timer                 False  True
    # Enable all implemented interrupts
    Enable All Interrupts
    # TOP is the counter maximum. After two seconds the counter equals TOP.
    # The next tick wraps to 0, sets overflow, and one-shot mode stops the timer.
    ${top_val}=  Set Variable       ${{${FREQUENCY} * 2}}
    Write Register                  ${REGS.TOP}  ${top_val}
    Assert Timer Is Running         False
    # Start the timer
    Start Command
    Assert Timer Is Running         True
    Assert Counter Value            0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${FREQUENCY}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${top_val}
    Assert IRQ Is Unset
    Advance Past Top
    # Check that (only) the overflow interrupt fired
    Assert IRQ Is Set
    Assert Overflow Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    # Check that the timer is no longer running
    Assert Timer Is Running         False
    Execute Command                 emulation RunFor "2"
    Assert IRQ Is Unset

Compare Channels Should Fire
    [Arguments]                     ${ip_version}
    Create Machine                  ${ip_version}
    Assert IRQ Is Unset
    Assert Timer Is Running         False
    # Set Channel 0 to hit the compare event right at the 3 second mark
    Write Register                  ${REGS.CC0_OC}  ${{${FREQUENCY} * 3}}
    Write Register                  ${REGS.CC0_CFG}  0x2
    # Set Channel 1 to hit the compare event right at the 4 second mark
    Write Register                  ${REGS.CC1_OC}  ${{${FREQUENCY} * 4}}
    Write Register                  ${REGS.CC1_CFG}  0x2
    # Configure the timer to count up, no one-shot mode
    Configure Timer                 False  False
    # Enable all implemented interrupts
    Enable All Interrupts
    # TOP is the counter maximum. After five seconds the counter equals TOP.
    Write Register                  ${REGS.TOP}  ${{${FREQUENCY} * 5}}
    Assert Timer Is Running         False
    # Start the timer
    Start Command
    Assert Timer Is Running         True
    Assert Counter Value            0
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${FREQUENCY}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert Counter Value            ${{${FREQUENCY} * 2}}
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the CC0 interrupt fires
    Assert IRQ Is Set
    Assert CC0 Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the CC1 interrupt fires
    Assert IRQ Is Set
    Assert CC1 Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # CNT is 16 bits on some IP versions, so a TOP above 0xFFFF is not visible there.
    # Overflow is still the tick after the counter reaches TOP.
    Assert IRQ Is Unset
    Advance Past Top
    # Check that (only) the overflow interrupt fired
    Assert IRQ Is Set
    Assert Overflow Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    # Go around one more time
    Execute Command                 emulation RunFor "3"
    # Check that (only) the CC0 interrupt fires
    Assert IRQ Is Set
    Assert CC0 Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    # Check that (only) the CC1 interrupt fires
    Assert IRQ Is Set
    Assert CC1 Interrupt Flag
    # Clear interrupts
    Clear Interrupt Flags
    Assert IRQ Is Unset
    Execute Command                 emulation RunFor "1"
    Assert IRQ Is Unset
    Advance Past Top
    # Check that (only) the overflow interrupt fired
    Assert IRQ Is Set
    Assert Overflow Interrupt Flag

*** Test Cases ***
Should Overflow When Counting Up
    [Template]                      Timer Should Overflow
    0
    1
    2

Should Underflow When Counting Down
    [Template]                      Timer Should Underflow
    0
    1
    2

Should Stop After Overflow In One Shot Mode
    [Template]                      One Shot Timer Should Stop After Overflow
    0
    1
    2

Should Fire Compare Channel Interrupts
    [Template]                      Compare Channels Should Fire
    0
    1
    2

Should Wrap 32-bit Counter At Reset TOP
    # TOP resets to 0xFFFF, so a 32-bit counter wraps there until software raises it.
    Create Width Machine            32
    Write Register                  ${REGS.IEN}  0x1
    Enable Timer Peripheral
    Start Command
    Write Register                  ${REGS.CNT}  0xFFFE
    Execute Command                 emulation RunFor "0.001"
    Assert Counter Value            0xFFFF
    Register Should Be Equal        ${REGS.IF}  0
    Execute Command                 emulation RunFor "0.001"
    Assert Counter Value            0
    Assert Overflow Interrupt Flag

Should Wrap 32-bit Counter At Programmed TOP
    Create Width Machine            32
    Write Register                  ${REGS.TOP}  0xFFFFFFFF
    Write Register                  ${REGS.CC0_OC}  0xFFFFFFFE
    Write Register                  ${REGS.CC0_CFG}  0x2
    Write Register                  ${REGS.IEN}  0x11
    Enable Timer Peripheral
    Start Command
    Write Register                  ${REGS.CNT}  0xFFFFFFFD
    Execute Command                 emulation RunFor "0.002"
    Assert Counter Value            0xFFFFFFFF
    Assert CC0 Interrupt Flag
    Execute Command                 emulation RunFor "0.001"
    Assert Counter Value            0
    Register Should Be Equal        ${REGS.IF}  0x11

Should Wrap 16-bit Counter After TOP
    Create Width Machine            16
    Write Register                  ${REGS.TOP}  0xFFFF
    Write Register                  ${REGS.IEN}  0x1
    Enable Timer Peripheral
    Start Command
    Write Register                  ${REGS.CNT}  0xFFFE
    Execute Command                 emulation RunFor "0.001"
    Assert Counter Value            0xFFFF
    Register Should Be Equal        ${REGS.IF}  0
    Execute Command                 emulation RunFor "0.001"
    Assert Counter Value            0
    Assert Overflow Interrupt Flag
