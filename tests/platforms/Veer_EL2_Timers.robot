*** Variables ***
${PROGRAM_COUNTER}                  0x20600000
${mtvec}                            0x1010
${mitcnt0}                          0x7D2
${mitb0}                            0x7D3
${mitctl0}                          0x7D4
${mitcnt1}                          0x7D5
${mitb1}                            0x7D6
${mitctl1}                          0x7D7
${mpmc}                             0x7C6
${mcpc}                             0x7C2

${timer0Int}                        29
${timer1Int}                        28

${mcauseForTimer0}                  0x8000001D
${mcauseForTimer1}                  0x8000001C

${BASIC_PROG}                       SEPARATOR=\n
...                                 csrr a0, ${mitctl0}
...                                 csrr a0, ${mitctl1}
...                                 addi a1, x0, 10
...                                 for_loop:
...                                 addi a1, a1, -1
...                                 bnez a1, for_loop
...                                 csrr a0, ${mitcnt0}
...                                 csrr a1, ${mitcnt1}
...                                 loop:
...                                 j loop

${HANDLER_PROG}                     SEPARATOR=\n
...                                 trap:
...                                 j trap

${INTERRUPT0_PROG}                  SEPARATOR=\n
...                                 li a1, ${1 << ${timer0Int}}
...                                 csrw mie, a1
...                                 li a1, 0x1808
...                                 csrw mstatus, a1
...                                 li a1, 100000
...                                 csrw ${mitb0}, a1
...                                 loop:
...                                 j loop

${INTERRUPT1_PROG}                  SEPARATOR=\n
...                                 li a1, ${1 << ${timer1Int}}
...                                 csrw mie, a1
...                                 li a1, 0x1808
...                                 csrw mstatus, a1
...                                 li a1, 100000
...                                 csrw ${mitb1}, a1
...                                 loop:
...                                 j loop

${INTERRUPT0_DISABLED_PROG}         SEPARATOR=\n
...                                 li a1, 0x1808
...                                 csrw mstatus, a1
...                                 li a1, 100000
...                                 csrw ${mitb0}, a1
...                                 loop:
...                                 j loop

${INTERRUPT1_DISABLED_PROG}         SEPARATOR=\n
...                                 li a1, 0x1808
...                                 csrw mstatus, a1
...                                 li a1, 100000
...                                 csrw ${mitb1}, a1
...                                 loop:
...                                 j loop

${CASCADE_MODE_PROG}                SEPARATOR=\n
...                                 li a1, ${1 << ${timer1Int}}
...                                 csrw mie, a1
...                                 li a1, 0x9
...                                 csrw ${mitctl1}, a1
...                                 li a1, 100000
...                                 csrw ${mitb0}, a1
...                                 li a1, 100
...                                 csrw ${mitb1}, a1
...                                 li a1, 0x1808
...                                 csrw mstatus, a1
...                                 loop:
...                                 j loop

*** Keywords ***

Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/tock_veer_el2_sim.repl
    Execute Command                 cpu PC ${PROGRAM_COUNTER}
    Execute Command                 cpu AssembleBlock ${mtvec} """${HANDLER_PROG}"""

Pc Should Not Be Equal
    [Arguments]                     ${value}
    ${pc}=  Execute Command         cpu PC
    Should Not Be Equal As Integers  ${pc}  ${value}

Timer ${number:(0|1)} Should Handle FwHalt ${enabled:(With|Without)} HaltEnable
    Create Machine

    ${control_bits}=  Evaluate      0x1 if "${enabled}" == "Without" else 0x3  # enabled and halt_en bits

    ${PROG}=  Catenate              SEPARATOR=\n
    ...                             li a1, ${1 << ${timer${number}Int}}
    ...                             csrw mie, a1
    ...                             li a1, 0x1808
    ...                             csrw mstatus, a1
    ...                             li a1, ${control_bits}
    ...                             csrw ${mitctl${number}}, a1
    ...                             li a1, 600000 # 0.001s with a 600MHz timer
    ...                             csrw ${mitb${number}}, a1
    ...                             li a1, 1
    ...                             csrw ${mpmc}, a1
    ...                             loop:
    ...                             j loop

    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${PROG}"""
    Execute Command                 emulation RunFor "0.0011s"

    IF  $enabled == "With"
        Pc Should Be Equal          ${mtvec}
        # Return to the loop to check that the interrupt got cleared properly
        Execute Command             cpu AssembleBlock `cpu PC` "mret"
        Execute Command             emulation RunFor "0.0005s"
        Pc Should Not Be Equal      ${mtvec}
    ELSE
        Pc Should Not Be Equal      ${mtvec}
    END
    Reset Emulation

Timer ${number:(0|1)} Should Handle PAUSE ${enabled:(With|Without)} PauseEnable
    Create Machine

    ${control_bits}=  Evaluate      0x1 if "${enabled}" == "Without" else 0x5  # enabled and pause_en bits

    ${PROG}=  Catenate              SEPARATOR=\n
    ...                             li a1, ${1 << ${timer${number}Int}}
    ...                             csrw mie, a1
    ...                             li a1, 0x1808
    ...                             csrw mstatus, a1
    ...                             li a1, ${control_bits}
    ...                             csrw ${mitctl${number}}, a1
    ...                             li a1, 600000 # 0.001s with a 600MHz timer
    ...                             csrw ${mitb${number}}, a1
    ...                             li a1, 1200000 # 0.002s with a 600MHz timer
    ...                             csrw ${mcpc}, a1
    ...                             li t0, 0xdeadbeef
    ...                             loop:
    ...                             j loop

    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${PROG}"""
    Execute Command                 emulation RunFor "0.0001s"
    # Timer has not fired yet, should still be in pause
    Register Should Be Equal        T0  0
    Pc Should Not Be Equal          ${mtvec}
    Execute Command                 emulation RunFor "0.001s"
    # Timer has now fired
    IF  $enabled == "With"
        Pc Should Be Equal          ${mtvec}
        Register Should Be Equal    T0  0
    ELSE
        # Should still be in PAUSE
        Pc Should Not Be Equal      ${mtvec}
        Register Should Be Equal    T0  0

        Execute Command             emulation RunFor "0.0011s"
        # Should now have exited PAUSE
        Pc Should Not Be Equal      ${mtvec}
        Register Should Be Equal    T0  0xdeadbeef
    END
    Reset Emulation

*** Test Cases ***

MITCTL Should Have Correct Default Values
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${BASIC_PROG}"""
    Execute Command                 cpu Step
    Register Should Be Equal        A0   0x1
    Execute Command                 cpu Step
    Register Should Be Equal        A0   0x1

MITCNT Should Increment
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${BASIC_PROG}"""
    Execute Command                 emulation RunFor "0.001s"
    ${val}=  Execute Command        cpu GetRegister "A0"
    Should Not Be Equal As Integers     ${val}      0
    ${val}=  Execute Command        cpu GetRegister "A1"
    Should Not Be Equal As Integers     ${val}      0

Timer 0 Should Trigger Interrupt
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${INTERRUPT0_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    Pc Should Be Equal              ${mtvec}
    Register Should Be Equal        MCAUSE  ${mcauseForTimer0}

Timer 0 Should Not Trigger Interrupt When MIE Bit Not Set
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${INTERRUPT0_DISABLED_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    Pc Should Not Be Equal          ${mtvec}

Timer 1 Should Trigger Interrupt
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${INTERRUPT1_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    Pc Should Be Equal              ${mtvec}
    Register Should Be Equal        MCAUSE    ${mcauseForTimer1}

Timer 1 Should Not Trigger Interrupt When MIE Bit Not Set
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${INTERRUPT1_DISABLED_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    Pc Should Not Be Equal          ${mtvec}

Cascade Mode Should Fire Interrupt1 After Correct Amount of Time
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${CASCADE_MODE_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    Pc Should Not Be Equal          ${mtvec}
    Execute Command                 emulation RunFor "0.0167s"
    Pc Should Be Equal              ${mtvec}
    Register Should Be Equal        MCAUSE  ${mcauseForTimer1}
