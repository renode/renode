*** Variables ***
${LINUX_PROMPT}                                 \#${SPACE}

*** Keywords ***
Boot Linux And Login
    [Arguments]                     ${testerId}=0  ${smp_count}=4
    # Verify that the GIC system register interface is not enabled
    # Wait for a message that gets logged early in boot, before any CPU features are printed
    Wait For Line On Uart           Booting Linux on physical CPU           testerId=${testerId}

    # Then run for a while looking for `CPU features: detected: GIC system register CPU interface`
    Should Not Be On Uart           GIC system register CPU interface       testerId=${testerId}  timeout=2

    # By waiting for the messages that follow all CPU feature printing with `timeout=0` we ensure
    # that the previous "Should Not Be On Uart" covered the printing of all of the CPU features
    # (all prints occurred before we finished waiting for completion of `Should Not Be On Uart`).
    # This also verifies SMP support.
    Wait For Line On Uart           SMP: Total of ${smp_count} processors activated  testerId=${testerId}  timeout=0
    Wait For Line On Uart           CPU: All CPU(s) started at EL2                   testerId=${testerId}  timeout=0
    Wait For Prompt On Uart         buildroot login:                                 testerId=${testerId}  timeout=50
    Write Line To Uart              root                                             testerId=${testerId}
    Wait For Prompt On Uart         ${LINUX_PROMPT}                                  testerId=${testerId}

Check Exit Code
    [Arguments]                     ${testerId}=0
    Write Line To Uart              echo $?                                 testerId=${testerId}
    Wait For Line On Uart           0                                       testerId=${testerId}
    Wait For Prompt On Uart         ${LINUX_PROMPT}                         testerId=${testerId}

Execute Linux Command
    [Arguments]                     ${command}  ${testerId}=0  ${timeout}=5
    Write Line To Uart              ${command}                              testerId=${testerId}
    Wait For Prompt On Uart         ${LINUX_PROMPT}                         testerId=${testerId}  timeout=${timeout}
    Check Exit Code                 testerId=${testerId}

Execute Linux Command Non Blocking
    [Arguments]                     ${command}  ${testerId}=0
    Write Line To Uart              ${command}                              testerId=${testerId}
