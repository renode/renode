*** Variables ***
${UART0}                            sysbus.uart0

${URI}                              @https://dl.antmicro.com/projects/renode

${HELLO_ELF}                        ${URI}/cortex-r52--hirtos-hello.elf-s_140356-d44a0b48e22a17fa8cb83ef08243ec23942812c0
${HELLO_PARTITIONS_ELF}             ${URI}/cortex-r52--hirtos-hello_partitions.elf-s_285392-644559248d6c6d752fe0dc1b46e3a467cce75841

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/cortex-r52.repl

Wait For Lines Per Thread
    [Arguments]                     @{lines}
    FOR  ${thread}  IN RANGE  1  8
        ${id}=                          Evaluate  str(${thread}+1)
        ${prio}=                        Evaluate  str(31-${thread})
        ${thread}=                      Evaluate  str(${thread})
        FOR  ${line}  IN  @{lines}
            ${line}=                        Replace String  ${line}  %THREAD%  ${thread}
            ${line}=                        Replace String  ${line}  %ID%  ${id}
            ${line}=                        Replace String  ${line}  %PRIO%  ${prio}
            Wait For Line On Uart           ${line}  treatAsRegex=true
        END
    END

*** Test Cases ***
Should Run Hello Sample On One Core
    Create Machine
    Create Terminal Tester          ${UART0}  defaultPauseEmulation=true
    Execute Command                 sysbus LoadELF ${HELLO_ELF}

    Wait For Line On Uart           HiRTOS running on CPU 0

    Wait For Line On Uart           FVP ARMv8-R Hello running on CPU 0
    Wait For Line On Uart           HiRTOS: Thread scheduler started
    Wait For Line On Uart           HiRTOS: Timer thread started

    # First, check if all threads have been started
    Wait For Lines Per Thread       Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 1

    Wait For Line On Uart           HiRTOS: Idle thread started

    # Then, make sure each of them has been woken up at least once
    Wait For Lines Per Thread       Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 2

Should Run Hello Partitions Sample On One Core
    Create Machine
    Create Terminal Tester          ${UART0}  defaultPauseEmulation=true
    Execute Command                 sysbus LoadELF ${HELLO_PARTITIONS_ELF}

    Wait For Line On Uart           HiRTOS Separation Kernel running on CPU 0

    # Check if Partition 1 has been started
    Wait For Line On Uart           HiRTOS running on CPU 0
    Wait For Line On Uart           Hello Partition 1 running on CPU 0
    Wait For Line On Uart           HiRTOS: Thread scheduler started
    Wait For Line On Uart           HiRTOS: Timer thread started

    Wait For Lines Per Thread       Partition 1: Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 1

    Wait For Line On Uart           HiRTOS: Idle thread started

    # Check if Partition 2 has been started
    Wait For Line On Uart           HiRTOS running on CPU 0
    Wait For Line On Uart           Hello Partition 2 on CPU 0
    Wait For Line On Uart           HiRTOS: Thread scheduler started
    Wait For Line On Uart           HiRTOS: Timer thread started

    Wait For Lines Per Thread       Partition 2: Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 1

    Wait For Line On Uart           HiRTOS: Idle thread started

    # Finally, make sure each thread has been woken up at least once
    Wait For Lines Per Thread       Partition 1: Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 2
    ...                             Partition 2: Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 2
