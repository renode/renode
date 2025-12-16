*** Variables ***
${PROGRAM_COUNTER}             0x80000000
${RESET_VECTOR_VALUE}          0x80001000
${AOSMU_BASE}                  0xF0100000
${RESET_VECTOR_OFFSET}         0x10
${SECURE_CON_OFFSET}           0xC
${CLK_SRC_OFFSET}              0x4

*** Keywords ***
Create Machine
    Execute Command            include @platforms/cpus/egis_et171.repl
    Execute Command            cpu0 PC ${PROGRAM_COUNTER}
    Execute Command            cpu0 AssembleBlock ${RESET_VECTOR_VALUE} "loop: j loop"
    Create Log Tester          0

*** Test Cases ***
Soft Reset Should Enter At Reset Vector
    Create Machine
    ${PROG}=  Catenate         SEPARATOR=\n
    ...                        li a0, ${AOSMU_BASE}
    ...                        li t0, ${RESET_VECTOR_VALUE}
    ...                        sw t0, ${RESET_VECTOR_OFFSET}(a0)
    ...                        li t0, 0x4 # Warm reset bit
    ...                        sw t0, ${SECURE_CON_OFFSET}(a0)
    ...                        loop: j loop

    Execute Command            cpu0 AssembleBlock `cpu0 PC` """${PROG}"""
    Execute Command            emulation RunFor "0.0001"

    PC Should Be Equal         ${RESET_VECTOR_VALUE}

MTimer Should Respect APB Clock Frequency
    Create Machine
    # Halt the cpu as we don't need it to test the mtimer
    Execute Command                 cpu0 IsHalted True
    # Root clock divider /4, APB clock divider /8, clock source 205MHz, resulting frequency is 3203125 Hz
    ${clock_config}=  Evaluate      ((0x3 << 4) | (0x5 << 1) | 0x1)
    Execute Command                 syscon WriteDoubleWord ${CLK_SRC_OFFSET} ${clock_config}
    Execute Command                 mtimer WriteQuadWord 0 0
    Execute Command                 emulation RunFor "1s"
    ${after}=  Execute Command      mtimer ReadQuadWord 0
    Should Be Equal As Numbers      ${after}  3203125
