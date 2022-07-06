*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/leon3_zephyr.resc
${UART}                       sysbus.uart
${PROMPT}                     uart:~$

*** Keywords ***
Prepare Machine
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}

ASR18 Should Be Equal
    [Arguments]  ${expected}

    Register Should Be Equal  39  ${expected}

*** Test Cases ***
Should Boot Zephyr
    [Documentation]           Boots Zephyr on the Leon3 platform.
    [Tags]                    zephyr  uart
    Prepare Machine

    Start Emulation

    Wait For Prompt On Uart   ${PROMPT}

    Provides                  booted-zephyr

Should Print Version
    [Documentation]           Tests shell responsiveness in Zephyr on the Leon3 platform.
    [Tags]                    zephyr  uart
    Requires                  booted-zephyr

    Write Line To Uart        version
    Wait For Line On Uart     Zephyr version 2.6.99

Should Handle WRASR
    Prepare Machine

    # sethi  %hi(0xa5a5a400), %g1
    Execute Command           sysbus WriteDoubleWord 0x40000000 0x69692903
    # or     %g1, 0x1a5, %g1
    Execute Command           sysbus WriteDoubleWord 0x40000004 0xa5611082
    # orn    %g0, %g0, %g2
    Execute Command           sysbus WriteDoubleWord 0x40000008 0x00003084
    # wr     0x1555, %asr18
    Execute Command           sysbus WriteDoubleWord 0x4000000c 0x553580a5
    # wr     %g1, %asr18
    Execute Command           sysbus WriteDoubleWord 0x40000010 0x010080a5
    # wr     %g2, 0x1555, %asr18
    Execute Command           sysbus WriteDoubleWord 0x40000014 0x55b580a5
    # wr     %g1, %g2, %asr18
    Execute Command           sysbus WriteDoubleWord 0x40000018 0x024080a5
    # wr     %g2, %asr15
    Execute Command           sysbus WriteDoubleWord 0x4000001c 0x0200809f
    # nop
    Execute Command           sysbus WriteDoubleWord 0x40000020 0x00000001
    # ba .
    Execute Command           sysbus WriteDoubleWord 0x40000024 0x00008010
    # nop
    Execute Command           sysbus WriteDoubleWord 0x40000028 0x00000001

    Execute Command           cpu ExecutionMode SingleStepBlocking
    Start Emulation
    PC Should Be Equal        0x40000000

    Execute Command           cpu Step 3
    PC Should Be Equal        0x4000000c
    ASR18 Should Be Equal     0x0

    Execute Command           cpu Step
    PC Should Be Equal        0x40000010
    ASR18 Should Be Equal     0xfffff555

    Execute Command           cpu Step
    PC Should Be Equal        0x40000014
    ASR18 Should Be Equal     0xa5a5a5a5

    Execute Command           cpu Step
    PC Should Be Equal        0x40000018
    ASR18 Should Be Equal     0xaaa

    Execute Command           cpu Step
    PC Should Be Equal        0x4000001c
    ASR18 Should Be Equal     0x5a5a5a5a

    Execute Command           cpu Step
    # If we get here, we didn't crash on the write to ASR15.
    PC Should Be Equal        0x40000020
    ASR18 Should Be Equal     0x5a5a5a5a
