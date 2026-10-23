*** Variables ***
${FREQUENCY}                    25000
${REPL_STRING}=                 SEPARATOR=
...  """                                                                  ${\n}
...  sysrtc: Timers.SiLabs_SYSRTC_2 @ sysbus <0x0, +0x4000>               ${\n}
...  ${SPACE*4}frequency: ${FREQUENCY}                                    ${\n}
...  hfxo: Miscellaneous.SiLabs.SiLabs_HFXO_5 @ sysbus <0x4000, +0x4000>  ${\n}
...  """
# Registers
${CMD_REG}                      0x0010
${STATUS_REG}                   0x0014
${CNT_REG}                      0x0018
${MS_CNT_REG}                   0x0024
${MS_CMP_REG}                   0x0028
${IF_REG}                       0x0030
${IEN_REG}                      0x0034
${GRP0_IF_REG}                  0x0050
${GRP0_IEN_REG}                 0x0054
${GRP0_CTRL_REG}                0x0058
${GRP0_CMP0_REG}                0x005C
${GRP0_CMP1_REG}                0x0060
${GRP0_PRETRIG_REG}             0x006C
${GRP1_IF_REG}                  0x0080
${GRP1_IEN_REG}                 0x0084
${GRP1_CTRL_REG}                0x0088
${GRP1_CMP0_REG}                0x008C
${GRP1_CMP1_REG}                0x0090
${GRP1_PRETRIG_REG}             0x009C

*** Keywords ***
Create Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL_STRING}

Start Command
    Execute Command             sysbus.sysrtc WriteDoubleWord ${CMD_REG} 0x1

Stop Command
    Execute Command             sysbus.sysrtc WriteDoubleWord ${CMD_REG} 0x2

Ms Start Command
    Execute Command             sysbus.sysrtc WriteDoubleWord ${CMD_REG} 0x4

Ms Stop Command
    Execute Command             sysbus.sysrtc WriteDoubleWord ${CMD_REG} 0x8

Assert App IRQ Is Set
    ${irqState}=                    Execute Command  sysbus.sysrtc AppIRQ
    Should Contain                  ${irqState}  GPIO: set

Assert App IRQ Is Unset
    ${irqState}=                    Execute Command  sysbus.sysrtc AppIRQ
    Should Contain                  ${irqState}  GPIO: unset

Assert App Alternate IRQ Is Set
    ${irqState}=                    Execute Command  sysbus.sysrtc AppAlternateIRQ
    Should Contain                  ${irqState}  GPIO: set

Assert App Alternate IRQ Is Unset
    ${irqState}=                    Execute Command  sysbus.sysrtc AppAlternateIRQ
    Should Contain                  ${irqState}  GPIO: unset

Assert MS IRQ Is Set
    ${irqState}=                    Execute Command  sysbus.sysrtc MsIRQ
    Should Contain                  ${irqState}  GPIO: set

Assert MS IRQ Is Unset
    ${irqState}=                    Execute Command  sysbus.sysrtc MsIRQ
    Should Contain                  ${irqState}  GPIO: unset

*** Test Cases ***
Counter/MS Counter
    Create Machine
    # Start the Counter
    Start Command
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x1
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    #Start the MS Counter
    Ms Start Command
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x9
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  1000
    # Restart the Counter to verify that MS Counter is not reset
    Start Command
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  1000
    # Stop MS counter
    Ms Stop Command
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x1
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    # Start MS counter again to check that it started back from 0
    Ms Start Command
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${STATUS_REG}
    Should Be Equal As Integers   ${read_val}  0x9
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  1000

Group0/1 Compare
    Create Machine
    # Start the Counter
    Start Command
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Configure compare values for both group0 and group1 and enable them
    ${set_val}                    evaluate  ${FREQUENCY} * 2.5
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_CMP0_REG} ${set_val}
    ${set_val}                    evaluate  ${FREQUENCY} * 3.5
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_CMP0_REG} ${set_val}
    ${set_val}                    evaluate  ${FREQUENCY} * 4.5
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_CMP1_REG} ${set_val}
    ${set_val}                    evaluate  ${FREQUENCY} * 5.5
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_CMP1_REG} ${set_val}
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_CTRL_REG} 0x3
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_IEN_REG} 0xF
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_CTRL_REG} 0x3
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_IEN_REG} 0xFF
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 3
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x2
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0
    Assert App IRQ Is Set
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_IF_REG} 0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 4
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x22
    Assert App IRQ Is Set
    Assert App Alternate IRQ Is Set
    Assert Ms IRQ Is Unset
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_IF_REG} 0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 5
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x4
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    Assert App IRQ Is Set
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_IF_REG} 0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    # Disable App group1 IRQ, check that App Alternate IRQ still gets set.
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_IEN_REG} 0xF0
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 6
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x44
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Set
    Assert Ms IRQ Is Unset
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_IF_REG} 0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset

Group0/1 Overflow
    Create Machine
    # Start the Counter
    Start Command
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Enable group0 and group1 overflow interrupts
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_IEN_REG} 0x1
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_IEN_REG} 0x11
    # Set Counter to be very close to overflow
    Execute Command               sysbus.sysrtc WriteDoubleWord ${CNT_REG} 0xFFFFFFFE
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} - 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Assert App IRQ Is Set
    Assert App Alternate IRQ Is Set
    Assert Ms IRQ Is Unset
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x1
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x11
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_IF_REG} 0
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_IF_REG} 0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    # Enable only group1 alternate overflow interrupts
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_IEN_REG} 0x0
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_IEN_REG} 0x10
    # Set Counter to be very close to overflow
    Execute Command               sysbus.sysrtc WriteDoubleWord ${CNT_REG} 0xFFFFFFFE
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} - 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Set
    Assert Ms IRQ Is Unset
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x1
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x11
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_IF_REG} 0
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_IF_REG} 0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset

MS Compare
    Create Machine
    # Start the Counter
    Start Command
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Start the MS Counter
    Ms Start Command
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  1000
    # Set the MS compare value and enable the related interrupt
    Execute Command               sysbus.sysrtc WriteDoubleWord ${MS_CMP_REG} 2500
    Execute Command               sysbus.sysrtc WriteDoubleWord ${IEN_REG} 0x2
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 3
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  2000
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 4
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  3000
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Set
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${IF_REG}
    Should Be Equal As Integers   ${read_val}  0x2

MS Overflow
    Create Machine
    # Start the Counter
    Start Command
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Start the MS Counter
    Ms Start Command
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  1000
    # Enable MS overflow interrupt
    Execute Command               sysbus.sysrtc WriteDoubleWord ${IEN_REG} 0x1
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset
    # Set MS Counter base value to be very close to overflow
    Execute Command               sysbus.sysrtc MsTimerCounter 0xFFFFFFFE
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  0xFFFFFFFE
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 3
    Should Be Equal As Integers   ${read_val}  ${check_val}
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${MS_CNT_REG}
    Should Be Equal As Integers   ${read_val}  999
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Set
    Execute Command               sysbus.sysrtc WriteDoubleWord ${IF_REG} 0x0
    Assert App IRQ Is Unset
    Assert App Alternate IRQ Is Unset
    Assert Ms IRQ Is Unset

Group0/1 Pretrigger
    Create Machine
    # Start the Counter
    Start Command
    Execute Command               emulation RunFor "1"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Configure Compare value
    ${set_val}                    evaluate  ${FREQUENCY} * 2
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_CMP0_REG} ${set_val}
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_CMP0_REG} ${set_val}
    # Configure Pretrigger
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_PRETRIG_REG} 0x37
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_PRETRIG_REG} 0xBF
    # Enable Compare
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP0_CTRL_REG} 0x1
    Execute Command               sysbus.sysrtc WriteDoubleWord ${GRP1_CTRL_REG} 0x1
    # Advance the counter
    Execute Command               emulation RunFor "0.9992"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2 - 20
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Check Compare and Pretrigger
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x37
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0xBF
    # Advance the counter
    Execute Command               emulation RunFor "0.00028"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2 - 13
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Check Compare and Pretrigger
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x37
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x1BF
    # Advance the counter
    Execute Command               emulation RunFor "0.00016"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2 - 9
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Check Compare and Pretrigger
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x37
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x3BF
    # Advance the counter
    Execute Command               emulation RunFor "0.00016"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2 - 5
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Check Compare and Pretrigger
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x137
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x3BF
    # Advance the counter
    Execute Command               emulation RunFor "0.00016"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2 - 1
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Check Compare and Pretrigger
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x0
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x337
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x3BF
    # Advance the counter
    Execute Command               emulation RunFor "0.00016"
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${CNT_REG}
    ${check_val}                  evaluate  ${FREQUENCY} * 2 + 3
    Should Be Equal As Integers   ${read_val}  ${check_val}
    # Check Compare and Pretrigger
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x2
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_IF_REG}
    Should Be Equal As Integers   ${read_val}  0x22
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP0_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x337
    ${read_val}=                  Execute Command  sysbus.sysrtc ReadDoubleWord ${GRP1_PRETRIG_REG}
    Should Be Equal As Integers   ${read_val}  0x3BF