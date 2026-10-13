*** Variables ***
${MEMORY_START}                     0x80000000
${TRAP_VECTOR}                      0x1000
${PROGRAM_COUNTER}                  0x80000000
${ILLEGAL_INSTRUCTION}              2
${PLATFORM_STRING}                  SEPARATOR=\n
...                                 ram: Memory.MappedMemory @ sysbus ${MEMORY_START} {
...                                 ${SPACE*4}size: 0x10000
...                                 }
...                                 trap: Memory.MappedMemory @ sysbus ${TRAP_VECTOR} {
...                                 ${SPACE*4}size: 0x1000
...                                 }

*** Keywords ***
Create RISC-V Machine
    [Arguments]                     ${cpu_type}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM_STRING}"""
    ${cpu}=                         Catenate    SEPARATOR=\n
    ...                             cpu: CPU.RiscV64 @ sysbus {
    ...                             ${SPACE*4}cpuType: "${cpu_type}";
    ...                             ${SPACE*4}timeProvider: empty
    ...                             }
    Execute Command                 machine LoadPlatformDescriptionFromString """${cpu}"""
    Execute Command                 cpu PC ${PROGRAM_COUNTER}
    Execute Command                 cpu MTVEC ${TRAP_VECTOR}
    Execute Command                 sysbus WriteDoubleWord ${TRAP_VECTOR} 0x0000006f

Assemble At PC
    [Arguments]                     ${assembly}
    Execute Command                 cpu AssembleBlock `cpu PC` """${assembly}"""

Illegal Instruction Should Trap
    [Arguments]                     ${expected_pc}=${PROGRAM_COUNTER}
    ${pc}=                          Execute Command    cpu PC
    Should Be Equal As Numbers      ${pc}    ${TRAP_VECTOR}
    ${mcause}=                      Execute Command    cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}    ${ILLEGAL_INSTRUCTION}
    ${mepc}=                        Execute Command    cpu MEPC
    Should Be Equal As Numbers      ${mepc}    ${expected_pc}

*** Test Cases ***
FCLASS.H Canonicalizes A Malformed Half Value
    Create RISC-V Machine           rv64gc_zfh
    Execute Command                 cpu SetRegister "MSTATUS" 0x6000
    Execute Command                 cpu SetRegister "a1" 0x3c00
    Assemble At PC                  fmv.d.x f10, a1
    Execute Command                 cpu Step
    Assemble At PC                  fclass.h a0, f10
    Execute Command                 cpu Step
    Register Should Be Equal        a0    0x200

ZBKB-Only CPU Executes A Dual-Owner Instruction
    Create RISC-V Machine           rv64gc_zbkb
    Execute Command                 cpu SetRegister "a0" 0xffff
    Execute Command                 cpu SetRegister "a1" 0x0f0f
    Assemble At PC                  andn a2, a0, a1
    Execute Command                 cpu Step
    Register Should Be Equal        a2    0xf0f0

ZCB Instruction Requires Its Additional Extension
    Create RISC-V Machine           rv64i_zca_zcb_zicsr
    Execute Command                 sysbus WriteWord ${PROGRAM_COUNTER} 0x9c69
    Execute Command                 cpu Step
    Illegal Instruction Should Trap

Scalar M Instruction Requires M
    Create RISC-V Machine           rv64i_zicsr
    Execute Command                 cpu SetRegister "a1" 6
    Execute Command                 cpu SetRegister "a2" 7
    Execute Command                 sysbus WriteDoubleWord ${PROGRAM_COUNTER} 0x025283b3
    Execute Command                 cpu Step
    Illegal Instruction Should Trap

Removed SFENCE.VM Encoding Is Illegal
    Create RISC-V Machine           rv64gc
    Execute Command                 sysbus WriteDoubleWord ${PROGRAM_COUNTER} 0x10400073
    Execute Command                 cpu Step
    Illegal Instruction Should Trap

SFENCE.VMA Control Remains Legal
    Create RISC-V Machine           rv64gc
    Execute Command                 sysbus WriteDoubleWord ${PROGRAM_COUNTER} 0x12000073
    Execute Command                 cpu Step
    ${pc}=                          Execute Command    cpu PC
    Should Be Equal As Numbers      ${pc}    0x80000004
