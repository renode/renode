*** Variables ***
${UART0}                            sysbus.uart0
${UART1}                            sysbus.uart1

${URI}                              @https://dl.antmicro.com/projects/renode

${HELLO_ELF}                        ${URI}/cortex-r52--hirtos-hello.elf-s_140356-d44a0b48e22a17fa8cb83ef08243ec23942812c0
${HELLO_PARTITIONS_ELF}             ${URI}/cortex-r52--hirtos-hello_partitions.elf-s_285392-644559248d6c6d752fe0dc1b46e3a467cce75841

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/cortex-r52.repl

Create Multicore Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/cortex-r52_smp.repl
    Execute Command                 machine SetSerialExecution True

Wait For Lines Per Thread
    [Arguments]                     @{lines}  ${testerId}
    FOR  ${thread}  IN RANGE  1  8
        ${id}=                          Evaluate  str(${thread}+1)
        ${prio}=                        Evaluate  str(31-${thread})
        ${thread}=                      Evaluate  str(${thread})
        FOR  ${line}  IN  @{lines}
            ${line}=                        Replace String  ${line}  %THREAD%  ${thread}
            ${line}=                        Replace String  ${line}  %ID%  ${id}
            ${line}=                        Replace String  ${line}  %PRIO%  ${prio}
            Wait For Line On Uart           ${line}  treatAsRegex=true  testerId=${testerId}
        END
    END

Wait For Hello Sample
    [Arguments]                     ${testerId}  ${cpu}=0
    Wait For Line On Uart           HiRTOS running on CPU ${cpu}  testerId=${testerId}

    Wait For Line On Uart           FVP ARMv8-R Hello running on CPU ${cpu}  testerId=${testerId}
    Wait For Line On Uart           HiRTOS: Thread scheduler started  testerId=${testerId}
    Wait For Line On Uart           HiRTOS: Timer thread started  testerId=${testerId}

    # First, check if all threads have been started
    Wait For Lines Per Thread       Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 1  testerId=${testerId}

    Wait For Line On Uart           HiRTOS: Idle thread started  testerId=${testerId}

    # Then, make sure each of them has been woken up at least once
    Wait For Lines Per Thread       Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups [^1]\d*  testerId=${testerId}

Wait For Hello Partitions Sample
    [Arguments]                     ${testerId}  ${cpu}=0
    Wait For Line On Uart           HiRTOS Separation Kernel running on CPU ${cpu}  testerId=${testerId}

    # Check if Partition 1 has been started
    Wait For Line On Uart           HiRTOS running on CPU ${cpu}  testerId=${testerId}
    Wait For Line On Uart           Hello Partition 1 running on CPU ${cpu}  testerId=${testerId}
    Wait For Line On Uart           HiRTOS: Thread scheduler started  testerId=${testerId}
    Wait For Line On Uart           HiRTOS: Timer thread started  testerId=${testerId}

    Wait For Lines Per Thread       Partition 1: Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 1  testerId=${testerId}

    Wait For Line On Uart           HiRTOS: Idle thread started  testerId=${testerId}

    # Check if Partition 2 has been started
    Wait For Line On Uart           HiRTOS running on CPU ${cpu}  testerId=${testerId}
    Wait For Line On Uart           Hello Partition 2 on CPU ${cpu}  testerId=${testerId}
    Wait For Line On Uart           HiRTOS: Thread scheduler started  testerId=${testerId}
    Wait For Line On Uart           HiRTOS: Timer thread started  testerId=${testerId}

    Wait For Lines Per Thread       Partition 2: Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups 1  testerId=${testerId}

    Wait For Line On Uart           HiRTOS: Idle thread started  testerId=${testerId}

    # Finally, make sure each thread has been woken up at least once
    Wait For Lines Per Thread       Partition 1: Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups [^1]\d*
    ...                             Partition 2: Thread %THREAD% \\(id %ID%, prio %PRIO%\\): .* Wakeups [^1]\d*
    ...                             testerId=${testerId}

*** Test Cases ***
Should Run Hello Sample On One Core
    Create Machine
    ${tester}=                      Create Terminal Tester  ${UART0}  defaultPauseEmulation=true
    Execute Command                 sysbus LoadELF ${HELLO_ELF}

    Wait For Hello Sample           ${tester}

Should Run Hello Partitions Sample On One Core
    Create Machine
    ${tester}=                      Create Terminal Tester  ${UART0}  defaultPauseEmulation=true
    Execute Command                 sysbus LoadELF ${HELLO_PARTITIONS_ELF}

    Wait For Hello Partitions Sample  ${tester}

Should Run Hello Sample On Two Cores
    Create Multicore Machine
    ${cpu0_tester}=                 Create Terminal Tester  ${UART0}
    ${cpu1_tester}=                 Create Terminal Tester  ${UART1}
    Execute Command                 sysbus LoadELF ${HELLO_ELF}

    Wait For Hello Sample           ${cpu0_tester}  cpu=0
    Wait For Hello Sample           ${cpu1_tester}  cpu=1

Should Run Hello Partitions Sample On Two Cores
    Create Multicore Machine
    ${cpu0_tester}=                 Create Terminal Tester  ${UART0}
    ${cpu1_tester}=                 Create Terminal Tester  ${UART1}
    Execute Command                 sysbus LoadELF ${HELLO_PARTITIONS_ELF}

    Wait For Hello Partitions Sample  ${cpu0_tester}  cpu=0
    Wait For Hello Partitions Sample  ${cpu1_tester}  cpu=1
