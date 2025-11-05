*** Variables ***
${MAPPED_MEMORY_START}              0x80000000
${MAPPED_MEMORY_OFFSET_WINDOW}      0x81000000
${ARRAY_MEMORY_START}               0x90000000
${ARRAY_MEMORY_OFFSET_WINDOW}       0x91000000
${INITIAL_PC}                       0x2000
${OFFSET}                           0x4000

${QuadWord_TEST_WORD}               0xFEEDFACECAFEBEEF
${DoubleWord_TEST_WORD}             0xDEADBEEF
${Word_TEST_WORD}                   0xFACE
${Byte_TEST_WORD}                   0xBE

*** Keywords ***
Create Machine
    Execute Command                 include "${CURDIR}/offset-bus-registrations.repl"
    Execute Command                 cpu PC ${INITIAL_PC}

Assemble At Current Pc
    [Arguments]                     ${program}
    ${length}=  Execute Command     cpu AssembleBlock `cpu PC` ${program}
    ${length}=  Convert To Integer  ${length}
    RETURN                          ${length}

Assemble And Step Program
    [Arguments]                         ${program}
    ${length}=  Assemble At Current Pc  ${program}
    ${pc}=  Execute Command             cpu PC
    ${current_pc}=  Convert To Integer  ${pc}
    ${last_pc}=  Evaluate               ${current_pc} + ${length}
    # Do at most length steps, in case an exception happens
    WHILE  ${current_pc} != ${last_pc}   limit=${length}
        ${current_pc}=  Execute Command     cpu Step
        ${current_pc}=  Convert To Integer  ${current_pc}
    END

Sysbus Should Read ${size:Byte|Word|DoubleWord|QuadWord} From Correct Offset
    Create Machine
    Execute Command                 dram Write${size} ${OFFSET} ${${size}_TEST_WORD}
    ${value}=  Execute Command      sysbus Read${size} ${${MAPPED_MEMORY_START}+${OFFSET}}
    ${cpu_val}=  Execute Command    sysbus Read${size} ${MAPPED_MEMORY_OFFSET_WINDOW} cpu
    Should Be Equal                 ${value}  ${cpu_val}

    Execute Command                 mmio Write${size} ${OFFSET} ${${size}_TEST_WORD}
    ${value}=  Execute Command      sysbus Read${size} ${${ARRAY_MEMORY_START}+${OFFSET}}
    ${cpu_val}=  Execute Command    sysbus Read${size} ${ARRAY_MEMORY_OFFSET_WINDOW} cpu
    Should Be Equal                 ${value}  ${cpu_val}

Sysbus Should Write ${size:Byte|Word|DoubleWord|QuadWord} From Correct Offset
    Create Machine
    Execute Command                 sysbus Write${size} ${MAPPED_MEMORY_OFFSET_WINDOW} ${${size}_TEST_WORD} cpu
    ${value}=  Execute Command      dram Read${size} ${OFFSET}
    Should Be Equal As Numbers      ${value}  ${${size}_TEST_WORD}

    Execute Command                 sysbus Write${size} ${ARRAY__MEMORY_OFFSET_WINDOW} ${${size}_TEST_WORD} cpu
    ${value}=  Execute Command      mmio Read${size} ${OFFSET}
    Should Be Equal As Numbers      ${value}  ${${size}_TEST_WORD}


*** Test Cases ***
Cpu Should Read From Correct Offset From Mapped Memory
    Create Machine
    Execute Command                 dram WriteQuadWord ${OFFSET} ${QuadWord_TEST_WORD}
    ${PROG}=  Catenate              SEPARATOR=\n
    ...                             li t0, ${MAPPED_MEMORY_OFFSET_WINDOW}
    ...                             ld a0, 0(t0)

    Assemble And Step Program       """${PROG}"""

    Register Should Be Equal        A0  ${QuadWord_TEST_WORD}

Cpu Should Read From Correct Offset From Array Memory
    Create Machine
    Execute Command                 mmio WriteQuadWord ${OFFSET} ${QuadWord_TEST_WORD}
    ${PROG}=  Catenate              SEPARATOR=\n
    ...                             li t0, ${ARRAY_MEMORY_OFFSET_WINDOW}
    ...                             ld a0, 0(t0)

    Assemble And Step Program       """${PROG}"""

    Register Should Be Equal        A0  ${QuadWord_TEST_WORD}


Sysbus Should Read QuadWord
    Sysbus Should Read QuadWord From Correct Offset

Sysbus Should Write QuadWord
    Sysbus Should Write QuadWord From Correct Offset

Sysbus Should Read DoubleWord
    Sysbus Should Read DoubleWord From Correct Offset

Sysbus Should Write DoubleWord
    Sysbus Should Write DoubleWord From Correct Offset

Sysbus Should Read Word
    Sysbus Should Read Word From Correct Offset

Sysbus Should Write Word
    Sysbus Should Write Word From Correct Offset

Sysbus Should Read Byte
    Sysbus Should Read Word From Correct Offset

Sysbus Should Write Byte
    Sysbus Should Write Byte From Correct Offset
