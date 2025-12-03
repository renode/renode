*** Variables ***
${MEMORY_START}                     0x80000000
${PMP_ENTRIES}                      16
${TEST_CONFIG}                      0x3

*** Keywords ***
Create RV ${bits:(32|64)} Machine
    Execute Command                 mach create
    Create Log Tester               0
    ${PLATFORM_STRING}=  Catenate   SEPARATOR=\n
    ...                             dram: Memory.MappedMemory @ sysbus ${MEMORY_START} {
    ...                             ${SPACE*4}size: 0x80000000
    ...                             }
    ...                             mtvec: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }
    ...
    ...                             cpu: CPU.RiscV${bits} @ sysbus {
    ...                             ${SPACE*4}cpuType: "rv${bits}gc_zicsr";
    ...                             ${SPACE*4}timeProvider: empty
    ...                             }
    ...                             pmp: Miscellaneous.RiscVExternalPMP @ cpu {
    ...                             ${SPACE*4}numberOfPMPEntries: ${PMP_ENTRIES}
    ...                             }
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM_STRING}"""
    Wait For Log Entry              cpu: Enabling External PMP

Assemble At Current PC
    [Arguments]                     ${program}
    ${length}=  Execute Command     cpu AssembleBlock `cpu PC` ${program}
    ${length}=  Convert To Integer  ${length}
    RETURN                          ${length}

Assemble And Step Program
    [Arguments]                         ${program}
    ${length}=                          Assemble At Current PC  ${program}
    ${pc}=  Execute Command             cpu PC
    ${pc}=  Convert To Integer          ${pc}
    ${last_pc}=  Evaluate               ${pc} + ${length}
    # Do at most length steps, in case an exception happens
    WHILE  ${pc} != ${last_pc}   limit=${length}
        ${pc}=  Execute Command         cpu Step
        ${pc}=  Convert To Integer      ${pc}
    END

Test Config For ${bits:(32|64)} Bit Config Register
    ${entries_per_csr}=  Evaluate    4 if ${bits} == 32 else 8
    ${config}=  Evaluate             0
    FOR  ${entry}  IN RANGE  ${entries_per_csr}
        ${config}=  Evaluate         (${config} << 8) | ${TEST_CONFIG}
    END
    RETURN                           ${config}

Should Access All ${bits:(32|64)} Bit Address Registers From Monitor
    Create RV ${bits} Machine
    FOR  ${index}  IN RANGE  ${PMP_ENTRIES}
        Execute Command              cpu.pmp AddressCSRWrite ${index} ${index}
        ${reg}=  Execute Command     cpu.pmp AddressCSRRead ${index}
        Should Be Equal As Numbers   ${reg}  ${index}
    END
    Should Not Be In Log            Attempted to read from invalid PMP
    Should Not Be In Log            Attempted to write to invalid PMP

Should Access All ${bits:(32|64)} Bit Config Registers From Monitor
    Create RV ${bits} Machine
    ${cfg_reg_number}=  Evaluate    ${PMP_ENTRIES}/4 if ${bits} == 32 else ${PMP_ENTRIES}/8
    ${step}=  Evaluate              1 if ${bits} == 32 else 2
    ${config}=  Test Config For ${bits} Bit Config Register
    FOR  ${index}  IN RANGE  ${cfg_reg_number}  ${step}
        Execute Command              cpu.pmp ConfigCSRWrite ${index} ${config}
        ${reg}=  Execute Command     cpu.pmp ConfigCSRRead ${index}
        Should Be Equal As Numbers   ${reg}  ${config}
    END
    Should Not Be In Log            Attempted to read from invalid PMP
    Should Not Be In Log            Attempted to write to invalid PMP

Should Access All ${bits:(32|64)} Bit Address Registers From CPU
    Create RV ${bits} Machine
    Assemble And Step Program       "li a0, 0;"

    FOR  ${register}  IN RANGE  ${PMP_ENTRIES}
        Assemble And Step Program   "csrw pmpaddr${register}, a0; csrr t0, pmpaddr${register}"
        Register Should Be Equal    A0  ${register}
        Register Should Be Equal    T0  ${register}
        Assemble And Step Program   "addi a0, a0, 1"
    END
    Register Should Be Equal        A0  ${PMP_ENTRIES}
    Should Not Be In Log            Attempted to read from invalid PMP
    Should Not Be In Log            Attempted to write to invalid PMP

Should Access All ${bits:(32|64)} Bit Config Registers From CPU
    Create RV ${bits} Machine
    ${cfg_reg_number}=  Evaluate    ${PMP_ENTRIES}/4 if ${bits} == 32 else ${PMP_ENTRIES}/8
    ${step}=  Evaluate              1 if ${bits} == 32 else 2
    ${config}=  Test Config For ${bits} Bit Config Register
    Assemble And Step Program       "li a0, ${config}"

    FOR  ${register}  IN RANGE  ${cfg_reg_number}  ${step}
        Assemble And Step Program   "csrw pmpcfg${register}, a0; csrr t0, pmpcfg${register}"
        Register Should Be Equal    A0  ${config}
        Register Should Be Equal    T0  ${config}
    END

    Should Not Be In Log            Attempted to read from invalid PMP
    Should Not Be In Log            Attempted to write to invalid PMP

*** Test Cases ***
Should Access All 32-Bit Config Registers From Monitor
    Should Access All 32 Bit Config Registers From Monitor

Should Access All 64-Bit Config Registers From Monitor
    Should Access All 32 Bit Config Registers From Monitor

Should Access All 32-Bit Address Registers From Monitor
    Should Access All 32 Bit Address Registers From Monitor

Should Access All 64-Bit Address Registers From Monitor
    Should Access All 64 Bit Address Registers From Monitor

Should Access All 32-Bit Address Registers From CPU
    Should Access All 32 Bit Address Registers From CPU

Should Access All 64-Bit Address Registers From CPU
    Should Access All 64 Bit Address Registers From CPU

Should Access All 32-Bit Config Registers From CPU
    Should Access All 32 Bit Config Registers From CPU

Should Access All 64-Bit Config Registers From CPU
    Should Access All 64 Bit Config Registers From CPU

Should Print Error When Addessing Invalid Registers
    Create RV 32 Machine
    ${invalid_entry}=  Evaluate  ${PMP_ENTRIES} + 1
    Execute Command              cpu.pmp ConfigCSRWrite ${invalid_entry} ${TEST_CONFIG}
    Wait For Log Entry           Attempted to write to invalid PMP config register ${invalid_entry}
    Execute Command              cpu.pmp ConfigCSRRead ${invalid_entry}
    Wait For Log Entry           Attempted to read from invalid PMP config register ${invalid_entry}
    Execute Command              cpu.pmp AddressCSRWrite ${invalid_entry} 0xbadcafe
    Wait For Log Entry           Attempted to write to invalid PMP address register ${invalid_entry}
    Execute Command              cpu.pmp AddressCSRRead ${invalid_entry}
    Wait For Log Entry           Attempted to read from invalid PMP address register ${invalid_entry}

    Assemble And Step Program    "csrw pmpaddr${invalid_entry}, a0"
    Wait For Log Entry           Attempted to write to invalid PMP address register ${invalid_entry}
    Assemble And Step Program    "csrr t0, pmpaddr${invalid_entry}"
    Wait For Log Entry           Attempted to read from invalid PMP address register ${invalid_entry}
    ${invalid_cfg}=  Evaluate    int(${PMP_ENTRIES}/4 + 1)
    Assemble And Step Program    "csrw pmpcfg${invalid_cfg}, a0"
    Wait For Log Entry           Attempted to read from invalid PMP config register ${invalid_cfg}
    Assemble And Step Program    "csrr t0, pmpcfg${invalid_cfg}"
    Wait For Log Entry           Attempted to read from invalid PMP config register ${invalid_cfg}
