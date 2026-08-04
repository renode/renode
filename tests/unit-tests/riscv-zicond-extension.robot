*** Variables ***
${MEMORY_START}                     0x80000000
${PLATFORM_STRING}                  SEPARATOR=\n
...                                 dram: Memory.MappedMemory @ sysbus ${MEMORY_START} {
...                                 ${SPACE*4}size: 0x80000000
...                                 }
...                                 mtvec: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }
...
${PROGRAM_COUNTER}                  0x80000000

${mtvec}                            0x1010
${illegal_instruction}              0x2

*** Keywords ***
Create ${bits:(64|32)} Bit Machine
    [Arguments]                     ${extensions}=zicond
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM_STRING}"""
    ${cpu}=                         Catenate  SEPARATOR=\n
    ...                             cpu: CPU.RiscV${bits} @ sysbus {
    ...                             ${SPACE*4}cpuType: "rv${bits}gc_${extensions}";
    ...                             ${SPACE*4}timeProvider: empty
    ...                             }
    ...
    ...                               # This CPU is only used for AssembleBlock, as there is currently
    ...                               # no possibility to create a custom LLVM assembler
    ...                             cpu_zicond: CPU.RiscV${bits} @ sysbus {
    ...                             ${SPACE*4}cpuType: "rv${bits}gc_zicond";
    ...                             ${SPACE*4}timeProvider: empty
    ...                             }
    Execute Command                 machine LoadPlatformDescriptionFromString """${cpu}"""
    Execute Command                 cpu PC ${PROGRAM_COUNTER}
    Execute Command                 cpu_zicond IsHalted true
    Execute Command                 cpu_zicond ExecutionMode SingleStep

Create ${bits:(64|32)} Bit Machine Without Zicond
    Create ${bits} Bit Machine      extensions=${EMPTY}

Execute Instruction
    [Arguments]                     ${assembly}
    Execute Command                 cpu_zicond AssembleBlock `cpu PC` """${assembly}"""
    Execute Command                 cpu Step

Czero.${cond:(Eqz|Nez)} Should Trap As Illegal Instruction
    Execute Instruction             czero.${cond} a0, a1, a2
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  ${mtvec}

    ${mcause}=                      Execute Command  cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}  ${illegal_instruction}

    ${mepc}=                        Execute Command  cpu MEPC
    Should Be Equal As Numbers      ${mepc}  ${PROGRAM_COUNTER}

Should ${result:(Pass Through|Zero)} When ${instruction} Condition Is ${condition}
    Execute Command                 cpu SetRegister "a0" 0x1234
    Execute Command                 cpu SetRegister "a1" ${condition}

    Execute Instruction             ${instruction} a2, a0, a1
    IF  '${result}' == 'Zero'
        Register Should Be Equal        a2  0  cpuName=cpu
    ELSE
        Register Should Be Equal        a2  0x1234  cpuName=cpu
    END

*** Test Cases ***
# czero.eqz: rd = (rs2 == 0) ? 0 : rs1
Czero.eqz Should Pass Through On RV32
    Create 32 Bit Machine
    Should Pass Through When Czero.eqz Condition Is 0x1

Czero.eqz Should Pass Through On RV64
    Create 64 Bit Machine
    Should Pass Through When Czero.eqz Condition Is 0x1

Czero.eqz Should Handle Nonzero Selector With Low 32 Bits Zeroed
    Create 64 Bit Machine
    Should Pass Through When Czero.eqz Condition Is 0x100000000

Czero.eqz Should Zero On RV32
    Create 32 Bit Machine
    Should Zero When Czero.eqz Condition Is 0x0

Czero.eqz Should Zero On RV64
    Create 64 Bit Machine
    Should Zero When Czero.eqz Condition Is 0x0

Should Trap With Czero.Eqz When Zicond Extension Is Disabled On RV64
    Create 64 Bit Machine Without Zicond
    Czero.Eqz Should Trap As Illegal Instruction

Should Trap With Czero.Eqz When Zicond Extension Is Disabled On RV32
    Create 32 Bit Machine Without Zicond
    Czero.Eqz Should Trap As Illegal Instruction

# czero.nez: rd = (rs2 != 0) ? 0 : rs1

Czero.nez Should Pass Through On RV32
    Create 32 Bit Machine
    Should Pass Through When Czero.nez Condition Is 0x0

Czero.nez Should Pass Through On RV64
    Create 64 Bit Machine
    Should Pass Through When Czero.nez Condition Is 0x0

Czero.nez Should Zero On RV32
    Create 32 Bit Machine
    Should Zero When Czero.nez Condition Is 0x1

Czero.nez Should Zero On RV64
    Create 64 Bit Machine
    Should Zero When Czero.nez Condition Is 0x1

Czero.nez Should Handle Nonzero Selector With Low 32 Bits Zeroed
    Create 64 Bit Machine
    Should Zero When Czero.nez Condition Is 0x100000000

Should Trap With Czero.Nez When Zicond Extension Is Disabled On RV64
    Create 64 Bit Machine Without Zicond
    Czero.Nez Should Trap As Illegal Instruction

Should Trap With Czero.Nez When Zicond Extension Is Disabled On RV32
    Create 32 Bit Machine Without Zicond
    Czero.Nez Should Trap As Illegal Instruction

# rd aliased with rs1 must not be clobbered before the condition is evaluated.

Should Handle Destination Aliased With Rs1 For Czero.Eqz
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xCAFE
    Execute Command                 cpu SetRegister "a1" 0x1
    Execute Instruction             czero.eqz a0, a0, a1
    Register Should Be Equal        a0  0xCAFE  cpuName=cpu

    Execute Command                 cpu SetRegister "a0" 0xCAFE
    Execute Command                 cpu SetRegister "a1" 0x0
    Execute Instruction             czero.eqz a0, a0, a1
    Register Should Be Equal        a0  0x0  cpuName=cpu

Should Handle Destination Aliased With Rs1 For Czero.Nez
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xCAFE
    Execute Command                 cpu SetRegister "a1" 0x0
    Execute Instruction             czero.nez a0, a0, a1
    Register Should Be Equal        a0  0xCAFE  cpuName=cpu

    Execute Command                 cpu SetRegister "a0" 0xCAFE
    Execute Command                 cpu SetRegister "a1" 0x1
    Execute Instruction             czero.nez a0, a0, a1
    Register Should Be Equal        a0  0x0  cpuName=cpu

# Full register width must be preserved - no accidental 32-bit truncation on RV64,
# and the sign-extended pattern of a negative value must be preserved on RV32.

Should Not Truncate Full 64 Bit Value On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xDEADBEEFCAFEBABE
    Execute Command                 cpu SetRegister "a1" 0x1
    Execute Instruction             czero.eqz a2, a0, a1
    Register Should Be Equal        a2  0xDEADBEEFCAFEBABE  cpuName=cpu

Should Preserve Sign Extended Value On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xFFFFFFFF
    Execute Command                 cpu SetRegister "a1" 0x1
    Execute Instruction             czero.eqz a2, a0, a1
    Register Should Be Equal        a2  0xFFFFFFFF  cpuName=cpu
