*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/gr716_zephyr.resc
${SYNCHRONIZATION_BIN}        @https://dl.antmicro.com/projects/renode/gr716a_mini-zephyr-synchronization.elf-s_326772-0b5df5d77c3c1db76ad1fe52116005ac4e2f273c
${UART}                       sysbus.uart
${PROMPT}                     uart:~$

*** Keywords ***
Prepare Machine
    [Arguments]               ${bin}=${None}
    IF  ${{$bin is not None}}
        Execute Command           $bin = ${bin}
    END
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}  defaultPauseEmulation=true

*** Test Cases ***
Should Boot Zephyr
    [Documentation]           Boots Zephyr on the GR716 platform.
    [Tags]                    zephyr  uart
    Prepare Machine

    Start Emulation

    Wait For Prompt On Uart   ${PROMPT}

    Provides                  booted-zephyr

Should Print Version
    [Documentation]           Tests shell responsiveness in Zephyr on the GR716 platform.
    [Tags]                    zephyr  uart
    Requires                  booted-zephyr

    Write Line To Uart        version
    Wait For Line On Uart     Zephyr version 2.6.99

Should Run Zephyr Synchronization Sample
    Prepare Machine           ${SYNCHRONIZATION_BIN}

    Wait For Line On Uart     thread_a: Hello World from cpu 0 on gr716a_mini!

    # The sample does k_busy_wait(100000) + k_msleep(500) = 600 ms
    Execute Command           emulation RunFor "0.59"
    Should Not Be On Uart     thread_b: Hello World from cpu 0 on gr716a_mini!  timeout=0
    Wait For Line On Uart     thread_b: Hello World from cpu 0 on gr716a_mini!  timeout=0.02

    Execute Command           emulation RunFor "0.59"
    Should Not Be On Uart     thread_a: Hello World from cpu 0 on gr716a_mini!  timeout=0
    Wait For Line On Uart     thread_a: Hello World from cpu 0 on gr716a_mini!  timeout=0.02
