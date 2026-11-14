*** Comments ***
PROTIMER capture/compare tests shared by the xG22, xG24 and xG301 LPW models.

A channel with BASEMATCHEN and WRAPMATCHEN represents one compound timestamp comparison. Both
counter words must match on the same tick. Series 2 models use a 16-bit BASECNT and a different
register layout from Series 3, so Configure LPW Model supplies model-specific addresses and fields.

The cross-wrap tests shrink BASECNTTOP to 0xFF so WRAPCNT advances during a short test run.

*** Variables ***
${PROTIMER_CTRL_REG}          0x0008
${PROTIMER_CMD_REG}           0x000C
${PROTIMER_BASECNT_REG}       0x001C
${PROTIMER_WRAPCNT_REG}       0x0020
${PROTIMER_CMD_START}         0x1

${SHORT_BASECNT_TOP}          0xFF
${WRAPCNT_TOP}                0xFFFFFFFF
${FAR_BASE_TARGET}            0x5A00

*** Keywords ***
Configure LPW Model
    [Arguments]  ${model}
    IF  '${model}' == 'xg22'
        Set Suite Variable     ${PLATFORM_FILE}             platforms/boards/silabs/brd4182a.repl
        Configure Series 2 Registers
    ELSE IF  '${model}' == 'xg24'
        Set Suite Variable     ${PLATFORM_FILE}             platforms/boards/silabs/brd4186c.repl
        Configure Series 2 Registers
    ELSE IF  '${model}' == 'xg301'
        Set Suite Variable     ${PLATFORM_FILE}             platforms/boards/silabs/brd1019a.repl
        Configure Series 3 Registers
    ELSE
        Fail                   Unsupported LPW model: ${model}
    END

Configure Series 2 Registers
    Set Suite Variable         ${PROTIMER_BLOCK_ADDRESS}    0xB801C000
    # DEBUGRUN | PRECNTSRC_CLOCK | BASECNTSRC_PRECNTOF | WRAPCNTSRC_BASECNTOF
    Set Suite Variable         ${PROTIMER_CTRL_VALUE}       0x21102
    Set Suite Variable         ${PROTIMER_PRECOUNT_TOP_VALUE}  0x017F00
    Set Suite Variable         ${CC_CTRL_COMPOUND}          0x19
    Set Suite Variable         ${CC_CTRL_BASE_ONLY}         0x09
    Set Suite Variable         ${CC_CTRL_WRAP_ONLY}         0x11
    Set Suite Variable         ${PROTIMER_PRECNT_TOP_REG}   0x0030
    Set Suite Variable         ${PROTIMER_BASECNT_TOP_REG}  0x0034
    Set Suite Variable         ${PROTIMER_WRAPCNT_TOP_REG}  0x0038
    Set Suite Variable         ${PROTIMER_IF_REG}           0x0064
    Set Suite Variable         ${PROTIMER_CC3_CTRL_REG}     0x0130
    Set Suite Variable         ${PROTIMER_CC3_BASE_REG}     0x0138
    Set Suite Variable         ${PROTIMER_CC3_WRAP_REG}     0x013C
    Set Suite Variable         ${PROTIMER_IF_CC3}           0x800

Configure Series 3 Registers
    Set Suite Variable         ${PROTIMER_BLOCK_ADDRESS}    0xA021C000
    # DEBUGRUN | PRECNTSRC_CLOCK | BASECNTSRC_PRECNTOF | WRAPCNTSRC_BASECNTOF
    Set Suite Variable         ${PROTIMER_CTRL_VALUE}       0x942
    Set Suite Variable         ${PROTIMER_PRECOUNT_TOP_VALUE}  0x017F0000
    Set Suite Variable         ${CC_CTRL_COMPOUND}          0x31
    Set Suite Variable         ${CC_CTRL_BASE_ONLY}         0x11
    Set Suite Variable         ${CC_CTRL_WRAP_ONLY}         0x21
    Set Suite Variable         ${PROTIMER_PRECNT_TOP_REG}   0x0034
    Set Suite Variable         ${PROTIMER_BASECNT_TOP_REG}  0x0038
    Set Suite Variable         ${PROTIMER_WRAPCNT_TOP_REG}  0x003C
    Set Suite Variable         ${PROTIMER_IF_REG}           0x007C
    Set Suite Variable         ${PROTIMER_CC3_CTRL_REG}     0x0160
    Set Suite Variable         ${PROTIMER_CC3_BASE_REG}     0x0168
    Set Suite Variable         ${PROTIMER_CC3_WRAP_REG}     0x016C
    Set Suite Variable         ${PROTIMER_IF_CC3}           0x8

Create Machine
    [Arguments]  ${model}
    Configure LPW Model         ${model}
    Reset Emulation
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescription @${PLATFORM_FILE}
    Execute Command             cpu IsHalted true
    Execute Command             logLevel 3

Write ProTimer Register
    [Arguments]  ${offset}  ${value}
    Execute Command             sysbus WriteDoubleWord ${{${PROTIMER_BLOCK_ADDRESS} + ${offset}}} ${value}

Start Protimer
    [Arguments]  ${basecnt_top}
    Write ProTimer Register     ${PROTIMER_CTRL_REG}  ${PROTIMER_CTRL_VALUE}
    Write ProTimer Register     ${PROTIMER_PRECNT_TOP_REG}  ${PROTIMER_PRECOUNT_TOP_VALUE}
    Write ProTimer Register     ${PROTIMER_BASECNT_TOP_REG}  ${basecnt_top}
    Write ProTimer Register     ${PROTIMER_WRAPCNT_TOP_REG}  ${WRAPCNT_TOP}
    Write ProTimer Register     ${PROTIMER_IF_REG}  0x0
    Write ProTimer Register     ${PROTIMER_CMD_REG}  ${PROTIMER_CMD_START}

Arm Cc3
    [Arguments]  ${wrap}  ${base}  ${ctrl}=${CC_CTRL_COMPOUND}
    Write ProTimer Register     ${PROTIMER_CC3_WRAP_REG}  ${wrap}
    Write ProTimer Register     ${PROTIMER_CC3_BASE_REG}  ${base}
    Write ProTimer Register     ${PROTIMER_CC3_CTRL_REG}  ${ctrl}

Compare Flag Should Be ${state:(Set|Clear)}
    ${flags}=                   Execute Command  sysbus ReadDoubleWord ${{${PROTIMER_BLOCK_ADDRESS} + ${PROTIMER_IF_REG}}}
    Should Be Equal As Integers  ${{int($flags.strip(), 16) & ${PROTIMER_IF_CC3}}}  ${{${PROTIMER_IF_CC3} if '${state}' == 'Set' else 0}}

Compound Compare Fires When Base Reaches Target In Matching Wrap
    [Arguments]  ${model}
    Create Machine              ${model}
    Start Protimer              ${WRAPCNT_TOP}
    Write ProTimer Register     ${PROTIMER_WRAPCNT_REG}  0x0
    Write ProTimer Register     ${PROTIMER_BASECNT_REG}  ${{${FAR_BASE_TARGET} - 20}}
    Arm Cc3                     0x0  ${FAR_BASE_TARGET}
    Execute Command             emulation RunFor "0.0001"
    Compare Flag Should Be Clear
    Execute Command             emulation RunFor "0.0002"
    Compare Flag Should Be Set

Compound Compare Does Not Fire Before Both Words Match
    [Arguments]  ${model}
    Create Machine              ${model}
    Start Protimer              ${SHORT_BASECNT_TOP}
    Arm Cc3                     0x2  0x40
    Execute Command             emulation RunFor "0.004"
    Compare Flag Should Be Clear
    Execute Command             emulation RunFor "0.0014"
    Compare Flag Should Be Clear
    Execute Command             emulation RunFor "0.0006"
    Compare Flag Should Be Set

Compound Compare Fires At Start Of Target Wrap
    [Arguments]  ${model}
    Create Machine              ${model}
    Start Protimer              ${SHORT_BASECNT_TOP}
    Arm Cc3                     0x1  0x0
    Execute Command             emulation RunFor "0.002"
    Compare Flag Should Be Clear
    Execute Command             emulation RunFor "0.001"
    Compare Flag Should Be Set

Base Only Compare Fires On Base Match
    [Arguments]  ${model}
    Create Machine              ${model}
    Start Protimer              ${SHORT_BASECNT_TOP}
    Arm Cc3                     0x2  0x40  ${CC_CTRL_BASE_ONLY}
    Execute Command             emulation RunFor "0.001"
    Compare Flag Should Be Set

Wrap Only Compare Fires On Wrap Match
    [Arguments]  ${model}
    Create Machine              ${model}
    Start Protimer              ${SHORT_BASECNT_TOP}
    Arm Cc3                     0x2  0x40  ${CC_CTRL_WRAP_ONLY}
    Execute Command             emulation RunFor "0.004"
    Compare Flag Should Be Clear
    Execute Command             emulation RunFor "0.0015"
    Compare Flag Should Be Set

*** Test Cases ***
Compound Compare Should Fire When Base Reaches Target In Matching Wrap
    [Template]                      Compound Compare Fires When Base Reaches Target In Matching Wrap
    xg22
    xg24
    xg301

Compound Compare Should Not Fire Before Both Words Match
    [Template]                      Compound Compare Does Not Fire Before Both Words Match
    xg22
    xg24
    xg301

Compound Compare Should Fire At Start Of Target Wrap
    [Template]                      Compound Compare Fires At Start Of Target Wrap
    xg22
    xg24
    xg301

Base Only Compare Should Fire On Base Match
    [Template]                      Base Only Compare Fires On Base Match
    xg22
    xg24
    xg301

Wrap Only Compare Should Fire On Wrap Match
    [Template]                      Wrap Only Compare Fires On Wrap Match
    xg22
    xg24
    xg301
