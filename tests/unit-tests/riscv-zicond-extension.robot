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

# Registers used (x-register numbers)
${x0}                               0
${a0}                               10
${a1}                               11
${a2}                               12

*** Keywords ***
Create ${bits:(64|32)} Bit Machine
    [Arguments]                     ${extensions}=zicond
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM_STRING}"""
    ${cpu}=  Catenate               SEPARATOR=\n
    ...                             cpu: CPU.RiscV${bits} @ sysbus {
    ...                             ${SPACE*4}cpuType: "rv${bits}gc_${extensions}";
    ...                             ${SPACE*4}timeProvider: empty
    ...                             }
    Execute Command                 machine LoadPlatformDescriptionFromString """${cpu}"""
    Execute Command                 cpu PC ${PROGRAM_COUNTER}

Create ${bits:(64|32)} Bit Machine Without Zicond
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM_STRING}"""
    ${cpu}=  Catenate               SEPARATOR=\n
    ...                             cpu: CPU.RiscV${bits} @ sysbus {
    ...                             ${SPACE*4}cpuType: "rv${bits}gc";
    ...                             ${SPACE*4}timeProvider: empty
    ...                             }
    Execute Command                 machine LoadPlatformDescriptionFromString """${cpu}"""
    Execute Command                 cpu PC ${PROGRAM_COUNTER}

# Encodes czero.eqz / czero.nez rd, rs1, rs2 (OP major opcode 0x33, funct7 = 0b0000111,
# funct3 = 0b101 for eqz, 0b111 for nez). Hand-encoded because raw opcodes let the same
# test run regardless of whether the bundled LLVM assembler knows the mnemonic yet.
Encode Czero.${cond:(Eqz|Nez)} Opcode
    [Arguments]                     ${rd}=${a2}    ${rs1}=${a0}    ${rs2}=${a1}
    IF    "${cond}" == "Eqz"
        ${funct3}=                      Set Variable    0x5
    ELSE
        ${funct3}=                      Set Variable    0x7
    END
    ${opcode}=                      Set Variable    ${{0x33 | (${rd} << 7) | (${funct3} << 12) | (${rs1} << 15) | (${rs2} << 20) | (0x07 << 25)}}
    [return]                        ${opcode}

Load Czero.${cond:(Eqz|Nez)} To Memory
    [Arguments]                     ${address}=${PROGRAM_COUNTER}    ${rd}=${a2}    ${rs1}=${a0}    ${rs2}=${a1}
    ${opcode}=                      Encode Czero.${cond} Opcode    rd=${rd}    rs1=${rs1}    rs2=${rs2}
    Execute Command                 sysbus WriteDoubleWord ${address} ${opcode}
    [return]                        ${opcode}

Step Czero.${cond:(Eqz|Nez)} Instruction
    [Arguments]                     ${address}=${PROGRAM_COUNTER}    ${rd}=${a2}    ${rs1}=${a0}    ${rs2}=${a1}
    Load Czero.${cond} To Memory    address=${address}    rd=${rd}    rs1=${rs1}    rs2=${rs2}
    Execute Command                 cpu Step

# Used for the LLVM AssembleBlock-based tests.
Execute Instruction
    [Arguments]                     ${assembly}
    Execute Command                 cpu AssembleBlock `cpu PC` """${assembly}"""
    Execute Command                 cpu Step

    # Check that the instruction did not fault
    ${pc}=  Execute Command         cpu PC
    Should Not Be Equal             ${pc.strip()}    ${mtvec}

Czero.${cond:(Eqz|Nez)} Should Trap As Illegal Instruction
    Step Czero.${cond} Instruction

    PC Should Be Equal              ${mtvec}

    ${mcause}=                      Execute Command    cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}    ${illegal_instruction}

    ${mepc}=                        Execute Command    cpu MEPC
    Should Be Equal As Numbers      ${mepc}    ${PROGRAM_COUNTER}

*** Test Cases ***
# czero.eqz: rd = (rs2 == 0) ? 0 : rs1

Should Pass Through Rs1 When Czero.Eqz Condition Is Nonzero On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0x1234
    Execute Command                 cpu SetRegister ${a1} 0x1
    Step Czero.Eqz Instruction
    Register Should Be Equal        ${a2}    0x1234

Should Pass Through Rs1 When Czero.Eqz Condition Is Nonzero On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0x1234
    Execute Command                 cpu SetRegister ${a1} 0x1
    Step Czero.Eqz Instruction
    Register Should Be Equal        ${a2}    0x1234

Should Zero Result When Czero.Eqz Condition Is Zero On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0x1234
    Execute Command                 cpu SetRegister ${a1} 0x0
    Step Czero.Eqz Instruction
    Register Should Be Equal        ${a2}    0x0

Should Zero Result When Czero.Eqz Condition Is Zero On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0x1234
    Execute Command                 cpu SetRegister ${a1} 0x0
    Step Czero.Eqz Instruction
    Register Should Be Equal        ${a2}    0x0

# czero.nez: rd = (rs2 != 0) ? 0 : rs1

Should Zero Result When Czero.Nez Condition Is Nonzero On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0x1234
    Execute Command                 cpu SetRegister ${a1} 0x1
    Step Czero.Nez Instruction
    Register Should Be Equal        ${a2}    0x0

Should Zero Result When Czero.Nez Condition Is Nonzero On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0x1234
    Execute Command                 cpu SetRegister ${a1} 0x1
    Step Czero.Nez Instruction
    Register Should Be Equal        ${a2}    0x0

Should Pass Through Rs1 When Czero.Nez Condition Is Zero On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0x1234
    Execute Command                 cpu SetRegister ${a1} 0x0
    Step Czero.Nez Instruction
    Register Should Be Equal        ${a2}    0x1234

Should Pass Through Rs1 When Czero.Nez Condition Is Zero On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0x1234
    Execute Command                 cpu SetRegister ${a1} 0x0
    Step Czero.Nez Instruction
    Register Should Be Equal        ${a2}    0x1234

# x0 is hardwired to zero, so using it as rs2 must behave exactly like rs2 == 0.

Should Treat X0 As Always Zero Condition For Czero.Eqz
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0xDEAD
    # Poison a1 - it should be irrelevant, only the register field (x0) matters.
    Execute Command                 cpu SetRegister ${a1} 0xFFFFFFFF
    Step Czero.Eqz Instruction       rs2=${x0}
    Register Should Be Equal        ${a2}    0x0

Should Treat X0 As Always Zero Condition For Czero.Nez
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0xDEAD
    Execute Command                 cpu SetRegister ${a1} 0xFFFFFFFF
    Step Czero.Nez Instruction       rs2=${x0}
    Register Should Be Equal        ${a2}    0xDEAD

# rd aliased with rs1 must not be clobbered before the condition is evaluated.

Should Handle Destination Aliased With Rs1 For Czero.Eqz
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0xCAFE
    Execute Command                 cpu SetRegister ${a1} 0x1
    Step Czero.Eqz Instruction       rd=${a0}    rs1=${a0}    rs2=${a1}
    Register Should Be Equal        ${a0}    0xCAFE

    Execute Command                 cpu SetRegister ${a0} 0xCAFE
    Execute Command                 cpu SetRegister ${a1} 0x0
    Step Czero.Eqz Instruction       address=0x80000004    rd=${a0}    rs1=${a0}    rs2=${a1}
    Register Should Be Equal        ${a0}    0x0

Should Handle Destination Aliased With Rs1 For Czero.Nez
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0xCAFE
    Execute Command                 cpu SetRegister ${a1} 0x0
    Step Czero.Nez Instruction       rd=${a0}    rs1=${a0}    rs2=${a1}
    Register Should Be Equal        ${a0}    0xCAFE

    Execute Command                 cpu SetRegister ${a0} 0xCAFE
    Execute Command                 cpu SetRegister ${a1} 0x1
    Step Czero.Nez Instruction       address=0x80000004    rd=${a0}    rs1=${a0}    rs2=${a1}
    Register Should Be Equal        ${a0}    0x0

# Full register width must be preserved - no accidental 32-bit truncation on RV64,
# and the sign-extended pattern of a negative value must be preserved on RV32.

Should Not Truncate Full 64 Bit Value On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0xDEADBEEFCAFEBABE
    Execute Command                 cpu SetRegister ${a1} 0x1
    Step Czero.Eqz Instruction
    Register Should Be Equal        ${a2}    0xDEADBEEFCAFEBABE

Should Preserve Sign Extended Value On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister ${a0} 0xFFFFFFFF
    Execute Command                 cpu SetRegister ${a1} 0x1
    Step Czero.Eqz Instruction
    Register Should Be Equal        ${a2}    0xFFFFFFFF

# LLVM assembler/disassembler support (czero.eqz / czero.nez mnemonics).

Should Assemble And Execute Czero.Eqz Via LLVM On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xBADC0FFEE
    Execute Command                 cpu SetRegister "a1" 0x1
    Execute Instruction             czero.eqz a2, a0, a1
    Register Should Be Equal        a2    0xBADC0FFEE

Should Assemble And Execute Czero.Eqz Via LLVM On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xBADC0FFE
    Execute Command                 cpu SetRegister "a1" 0x0
    Execute Instruction             czero.eqz a2, a0, a1
    Register Should Be Equal        a2    0x0

Should Assemble And Execute Czero.Nez Via LLVM On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xBADC0FFEE
    Execute Command                 cpu SetRegister "a1" 0x1
    Execute Instruction             czero.nez a2, a0, a1
    Register Should Be Equal        a2    0x0

Should Assemble And Execute Czero.Nez Via LLVM On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xBADC0FFE
    Execute Command                 cpu SetRegister "a1" 0x0
    Execute Instruction             czero.nez a2, a0, a1
    Register Should Be Equal        a2    0xBADC0FFE

# Both instructions must trap as illegal when Zicond is not enabled for the CPU.

Should Trap With Czero.Eqz When Zicond Extension Is Disabled On RV64
    Create 64 Bit Machine Without Zicond
    Czero.Eqz Should Trap As Illegal Instruction

Should Trap With Czero.Eqz When Zicond Extension Is Disabled On RV32
    Create 32 Bit Machine Without Zicond
    Czero.Eqz Should Trap As Illegal Instruction

Should Trap With Czero.Nez When Zicond Extension Is Disabled On RV64
    Create 64 Bit Machine Without Zicond
    Czero.Nez Should Trap As Illegal Instruction

Should Trap With Czero.Nez When Zicond Extension Is Disabled On RV32
    Create 32 Bit Machine Without Zicond
    Czero.Nez Should Trap As Illegal Instruction
