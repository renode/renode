*** Settings ***
Test Setup                      Create Machine

*** Variables ***
${FREQUENCY}                    25000
${PLATFORM}                     SEPARATOR=\n
...  """
...  sysrtc: Timers.SiLabs_SYSRTC_2 @ sysbus <0x0, +0x4000>
...  ${SPACE*4}frequency: ${FREQUENCY}
...  hfxo: Miscellaneous.SiLabs.SiLabs_HFXO_5 @ sysbus <0x4000, +0x4000>
...  """
# Registers
${CMD}                          0x0010
${STATUS}                       0x0014
${CNT}                          0x0018
${MS_CNT}                       0x0024
${MS_CMP}                       0x0028
${IF}                           0x0030
${IEN}                          0x0034
${GRP0_IF}                      0x0050
${GRP0_IEN}                     0x0054
${GRP0_CTRL}                    0x0058
${GRP0_CMP0}                    0x005C
${GRP0_CMP1}                    0x0060
${GRP0_PRETRIG}                 0x006C
${GRP1_IF}                      0x0080
${GRP1_IEN}                     0x0084
${GRP1_CTRL}                    0x0088
${GRP1_CMP0}                    0x008C
${GRP1_CMP1}                    0x0090
${GRP1_PRETRIG}                 0x009C

*** Keywords ***
Create Machine
    Renode Test Setup
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${PLATFORM}

Register Should Be
    [Arguments]                 ${register}  ${expected}
    ${value}=                   Execute Command  sysrtc ReadDoubleWord ${register}
    Should Be Equal As Integers  ${value}  ${expected}

Group Flags Should Be
    [Arguments]                 ${group0}  ${group1}
    Register Should Be          ${GRP0_IF}  ${group0}
    Register Should Be          ${GRP1_IF}  ${group1}

IRQs Should Be
    [Arguments]                 ${app}  ${appAlternate}  ${ms}
    FOR  ${irq}  ${state}  IN  AppIRQ  ${app}  AppAlternateIRQ  ${appAlternate}  MsIRQ  ${ms}
        ${irqState}=            Execute Command  sysrtc ${irq}
        Should Contain          ${irqState}  GPIO: ${state}
    END

# Start the Counter and let it count for one second
Start Counter
    Execute Command             sysrtc WriteDoubleWord ${CMD} 0x1
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${FREQUENCY}

# Start the MS Counter and let it count for one second
Start MS Counter
    Execute Command             sysrtc WriteDoubleWord ${CMD} 0x4
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 2 }}
    Register Should Be          ${MS_CNT}  1000

Pretrigger Step
    [Arguments]                 ${time}  ${count}  ${group0Flags}  ${group1Flags}  ${group0Pretrigger}  ${group1Pretrigger}
    # Advance the counter
    Execute Command             emulation RunFor "${time}"
    Register Should Be          ${CNT}  ${count}
    # Check Compare and Pretrigger
    Group Flags Should Be       ${group0Flags}  ${group1Flags}
    Register Should Be          ${GRP0_PRETRIG}  ${group0Pretrigger}
    Register Should Be          ${GRP1_PRETRIG}  ${group1Pretrigger}

*** Test Cases ***
Should Count With Counter And MS Counter
    # Start the Counter
    Execute Command             sysrtc WriteDoubleWord ${CMD} 0x1
    Register Should Be          ${STATUS}  0x1
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${FREQUENCY}
    #Start the MS Counter
    Execute Command             sysrtc WriteDoubleWord ${CMD} 0x4
    Register Should Be          ${STATUS}  0x9
    Register Should Be          ${MS_CNT}  0
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 2 }}
    Register Should Be          ${MS_CNT}  1000
    # Restart the Counter to verify that MS Counter is not reset
    Execute Command             sysrtc WriteDoubleWord ${CMD} 0x1
    Register Should Be          ${CNT}  0
    Register Should Be          ${MS_CNT}  1000
    # Stop MS counter
    Execute Command             sysrtc WriteDoubleWord ${CMD} 0x8
    Register Should Be          ${STATUS}  0x1
    Register Should Be          ${MS_CNT}  0
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${FREQUENCY}
    Register Should Be          ${MS_CNT}  0
    # Start MS counter again to check that it started back from 0
    Execute Command             sysrtc WriteDoubleWord ${CMD} 0x4
    Register Should Be          ${STATUS}  0x9
    Register Should Be          ${MS_CNT}  0
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 2 }}
    Register Should Be          ${MS_CNT}  1000

Should Compare In Group 0 And 1
    Start Counter
    # Configure compare values for both group0 and group1 and enable them
    Execute Command             sysrtc WriteDoubleWord ${GRP0_CMP0} ${{ ${FREQUENCY} * 2.5 }}
    Execute Command             sysrtc WriteDoubleWord ${GRP1_CMP0} ${{ ${FREQUENCY} * 3.5 }}
    Execute Command             sysrtc WriteDoubleWord ${GRP0_CMP1} ${{ ${FREQUENCY} * 4.5 }}
    Execute Command             sysrtc WriteDoubleWord ${GRP1_CMP1} ${{ ${FREQUENCY} * 5.5 }}
    Execute Command             sysrtc WriteDoubleWord ${GRP0_CTRL} 0x3
    Execute Command             sysrtc WriteDoubleWord ${GRP0_IEN} 0xF
    Register Should Be          ${IF}  0
    Execute Command             sysrtc WriteDoubleWord ${GRP1_CTRL} 0x3
    Execute Command             sysrtc WriteDoubleWord ${GRP1_IEN} 0xFF
    Register Should Be          ${IF}  0
    IRQs Should Be              unset  unset  unset
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 2 }}
    Group Flags Should Be       0  0
    IRQs Should Be              unset  unset  unset
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 3 }}
    Group Flags Should Be       0x2  0
    IRQs Should Be              set  unset  unset
    Execute Command             sysrtc WriteDoubleWord ${GRP0_IF} 0
    IRQs Should Be              unset  unset  unset
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 4 }}
    Group Flags Should Be       0x0  0x22
    IRQs Should Be              set  set  unset
    Execute Command             sysrtc WriteDoubleWord ${GRP1_IF} 0
    IRQs Should Be              unset  unset  unset
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 5 }}
    Group Flags Should Be       0x4  0x0
    IRQs Should Be              set  unset  unset
    Execute Command             sysrtc WriteDoubleWord ${GRP0_IF} 0
    IRQs Should Be              unset  unset  unset
    # Disable App group1 IRQ, check that App Alternate IRQ still gets set.
    Execute Command             sysrtc WriteDoubleWord ${GRP1_IEN} 0xF0
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 6 }}
    Group Flags Should Be       0x0  0x44
    IRQs Should Be              unset  set  unset
    Execute Command             sysrtc WriteDoubleWord ${GRP1_IF} 0
    IRQs Should Be              unset  unset  unset

Should Overflow In Group 0 And 1
    Start Counter
    # Enable group0 and group1 overflow interrupts
    Execute Command             sysrtc WriteDoubleWord ${GRP0_IEN} 0x1
    Execute Command             sysrtc WriteDoubleWord ${GRP1_IEN} 0x11
    # Set Counter to be very close to overflow
    Execute Command             sysrtc WriteDoubleWord ${CNT} 0xFFFFFFFE
    IRQs Should Be              unset  unset  unset
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} - 1 }}
    IRQs Should Be              set  set  unset
    Group Flags Should Be       0x1  0x11
    Execute Command             sysrtc WriteDoubleWord ${GRP0_IF} 0
    Execute Command             sysrtc WriteDoubleWord ${GRP1_IF} 0
    IRQs Should Be              unset  unset  unset
    # Enable only group1 alternate overflow interrupts
    Execute Command             sysrtc WriteDoubleWord ${GRP0_IEN} 0x0
    Execute Command             sysrtc WriteDoubleWord ${GRP1_IEN} 0x10
    # Set Counter to be very close to overflow
    Execute Command             sysrtc WriteDoubleWord ${CNT} 0xFFFFFFFE
    IRQs Should Be              unset  unset  unset
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} - 1 }}
    IRQs Should Be              unset  set  unset
    Group Flags Should Be       0x1  0x11
    Execute Command             sysrtc WriteDoubleWord ${GRP0_IF} 0
    Execute Command             sysrtc WriteDoubleWord ${GRP1_IF} 0
    IRQs Should Be              unset  unset  unset

Should Compare MS Counter
    Start Counter
    Start MS Counter
    # Set the MS compare value and enable the related interrupt
    Execute Command             sysrtc WriteDoubleWord ${MS_CMP} 2500
    Execute Command             sysrtc WriteDoubleWord ${IEN} 0x2
    IRQs Should Be              unset  unset  unset
    Register Should Be          ${IF}  0x0
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 3 }}
    Register Should Be          ${MS_CNT}  2000
    IRQs Should Be              unset  unset  unset
    Register Should Be          ${IF}  0x0
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 4 }}
    Register Should Be          ${MS_CNT}  3000
    IRQs Should Be              unset  unset  set
    Register Should Be          ${IF}  0x2

Should Overflow MS Counter
    Start Counter
    Start MS Counter
    # Enable MS overflow interrupt
    Execute Command             sysrtc WriteDoubleWord ${IEN} 0x1
    IRQs Should Be              unset  unset  unset
    # Set MS Counter base value to be very close to overflow
    Execute Command             sysrtc MsTimerCounter 0xFFFFFFFE
    Register Should Be          ${MS_CNT}  0xFFFFFFFE
    Execute Command             emulation RunFor "1"
    Register Should Be          ${CNT}  ${{ ${FREQUENCY} * 3 }}
    Register Should Be          ${MS_CNT}  999
    IRQs Should Be              unset  unset  set
    Execute Command             sysrtc WriteDoubleWord ${IF} 0x0
    IRQs Should Be              unset  unset  unset

Should Pretrigger In Group 0 And 1
    Start Counter
    # Configure Compare value
    Execute Command             sysrtc WriteDoubleWord ${GRP0_CMP0} ${{ ${FREQUENCY} * 2 }}
    Execute Command             sysrtc WriteDoubleWord ${GRP1_CMP0} ${{ ${FREQUENCY} * 2 }}
    # Configure Pretrigger
    Execute Command             sysrtc WriteDoubleWord ${GRP0_PRETRIG} 0x37
    Execute Command             sysrtc WriteDoubleWord ${GRP1_PRETRIG} 0xBF
    # Enable Compare
    Execute Command             sysrtc WriteDoubleWord ${GRP0_CTRL} 0x1
    Execute Command             sysrtc WriteDoubleWord ${GRP1_CTRL} 0x1
    #                           time     count                         group IF   pretrigger
    Pretrigger Step             0.9992   ${{ ${FREQUENCY} * 2 - 20 }}  0x0  0x0   0x37   0xBF
    Pretrigger Step             0.00028  ${{ ${FREQUENCY} * 2 - 13 }}  0x0  0x0   0x37   0x1BF
    Pretrigger Step             0.00016  ${{ ${FREQUENCY} * 2 - 9 }}   0x0  0x0   0x37   0x3BF
    Pretrigger Step             0.00016  ${{ ${FREQUENCY} * 2 - 5 }}   0x0  0x0   0x137  0x3BF
    Pretrigger Step             0.00016  ${{ ${FREQUENCY} * 2 - 1 }}   0x0  0x0   0x337  0x3BF
    Pretrigger Step             0.00016  ${{ ${FREQUENCY} * 2 + 3 }}   0x2  0x22  0x337  0x3BF
