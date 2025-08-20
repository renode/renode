*** Variables ***
${PROGRAM_COUNTER}                  0x20600000
${mtvec}                            0x1010
${mitcnt0}                          0x7D2
${mitb0}                            0x7D3
${mitctl0}                          0x7D4
${mitcnt1}                          0x7D5
${mitb1}                            0x7D6
${mitctl1}                          0x7D7

${a0}                               10
${a1}                               11

${Timer0IntBit}                     0x20000000
${Timer1IntBit}                     0x10000000

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
...                                 li a1, ${Timer0IntBit}
...                                 csrw mie, a1
...                                 li a1, 0x1808
...                                 csrw mstatus, a1
...                                 li a1, 100000
...                                 csrw ${mitb0}, a1
...                                 loop:
...                                 j loop

${INTERRUPT1_PROG}                  SEPARATOR=\n
...                                 li a1, ${Timer1IntBit}
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
...                                 li a1, ${Timer1IntBit}
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

*** Test Cases ***

MITCTL Should Have Correct Default Values
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${BASIC_PROG}"""
    Execute Command                 cpu Step
    Register Should Be Equal        ${a0}   0x1
    Execute Command                 cpu Step
    Register Should Be Equal        ${a0}   0x1

MITCNT Should Increment
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${BASIC_PROG}"""
    Execute Command                 emulation RunFor "0.001s"
    ${val}=                         Execute Command         cpu GetRegister ${a0}
    Should Not Be Equal As Integers     ${val}      0
    ${val}=                         Execute Command         cpu GetRegister ${a1}
    Should Not Be Equal As Integers     ${val}      0

Timer 0 Should Trigger Interrupt
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${INTERRUPT0_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    ${pc}=                          Execute Command         cpu PC
    Should Be Equal As Integers     ${pc}       ${mtvec}
    ${mcause}=                      Execute Command         cpu MCAUSE
    Should Be Equal As Integers     ${mcause}    0x8000001D

Timer 0 Should Not Trigger Interrupt When MIE Bit Not Set
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${INTERRUPT0_DISABLED_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    ${pc}=                          Execute Command         cpu PC
    Should Not Be Equal As Integers     ${pc}       ${mtvec}

Timer 1 Should Trigger Interrupt
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${INTERRUPT1_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    ${pc}=                          Execute Command         cpu PC
    Should Be Equal As Integers     ${pc}       ${mtvec}
    ${mcause}=                      Execute Command         cpu MCAUSE
    Should Be Equal As Integers     ${mcause}    0x8000001C

Timer 1 Should Not Trigger Interrupt When MIE Bit Not Set
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${INTERRUPT1_DISABLED_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    ${pc}=                          Execute Command         cpu PC
    Should Not Be Equal As Integers     ${pc}       ${mtvec}

Cascade Mode Should Fire Interrupt1 After Correct Amount of Time
    Create Machine
    Execute Command                 cpu AssembleBlock ${PROGRAM_COUNTER} """${CASCADE_MODE_PROG}"""
    Execute Command                 emulation RunFor "0.00167s"
    ${pc}=                          Execute Command         cpu PC
    Should Not Be Equal As Integers     ${pc}       ${mtvec}
    Execute Command                 emulation RunFor "0.0167s"
    ${pc}=                          Execute Command         cpu PC
    Should Be Equal As Integers     ${pc}       ${mtvec}
    ${mcause}=                      Execute Command         cpu MCAUSE
    Should Be Equal As Integers     ${mcause}    0x8000001C
