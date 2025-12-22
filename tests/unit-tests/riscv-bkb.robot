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

*** Keywords ***
Create ${bits:(64|32)} Bit Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM_STRING}"""
    ${cpu}=  Catenate               SEPARATOR=\n
    ...                             cpu: CPU.RiscV${bits} @ sysbus {
    ...                             ${SPACE*4}cpuType: "rv${bits}gc_zbkb";
    ...                             ${SPACE*4}timeProvider: empty
    ...                             }
    Execute Command                 machine LoadPlatformDescriptionFromString """${cpu}"""
    Execute Command                 cpu PC ${PROGRAM_COUNTER}

Execute Instruction
    [Arguments]                     ${assembly}
    Execute Command                 cpu AssembleBlock `cpu PC` """${assembly}"""
    Execute Command                 cpu Step

    # Check that the instruction did not fault
    ${pc}=  Execute Command         cpu PC
    Should Not Be Equal             ${pc.strip()}  ${mtvec}

Test Packh Instruction
    Execute Command                 cpu SetRegister "a0" 0xffffffcd
    Execute Command                 cpu SetRegister "a1" 0xffffffab

    Execute Instruction             packh a2, a0, a1
    Register Should Be Equal        a2      0xabcd

*** Test Cases ***
Should Execute Pack Instruction On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xffffbeef
    Execute Command                 cpu SetRegister "a1" 0xffffdead

    Execute Instruction             pack a2, a0, a1
    Register Should Be Equal        a2      0xdeadbeef

Should Execute Pack Instruction On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xffffffffbad0cafe
    Execute Command                 cpu SetRegister "a1" 0xffffffffdeadbeef

    Execute Instruction             pack a2, a0, a1
    Register Should Be Equal        a2      0xdeadbeefbad0cafe

Should Execute Packh Instruction On RV32
    Create 32 Bit Machine
    Test Packh Instruction

Should Execute Packh Instruction On RV64
    Create 64 Bit Machine
    Test Packh Instruction

# The `packw` instruction is RV64 only
Should Execute Packw Instruction
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xffffffffffffbeef
    Execute Command                 cpu SetRegister "a1" 0xffffffffffffdead

    Execute Instruction             packw a2, a0, a1
    Register Should Be Equal        a2      0xdeadbeef

# The `zip` instruction is RV32 only
Should Execute Zip Instruction
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xffffffff
    Execute Instruction             zip a1, a0
    Register Should Be Equal        a1      0xffffffff

    Execute Command                 cpu SetRegister "a0" 0xffff
    Execute Instruction             zip a1, a0
    Register Should Be Equal        a1      0x55555555

    Execute Command                 cpu SetRegister "a0" 0xffff0000
    Execute Instruction             zip a1, a0
    Register Should Be Equal        a1      0xaaaaaaaa

    Execute Command                 cpu SetRegister "a0" 0xdeadbeef
    Execute Instruction             zip a1, a0
    Register Should Be Equal        a1      0xe7fcdcf7

# The `unzip` instruction is RV32 only
Should Execute Unzip Instruction
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xffffffff
    Execute Instruction             unzip a1, a0
    Register Should Be Equal        a1      0xffffffff

    Execute Command                 cpu SetRegister "a0" 0x55555555
    Execute Instruction             unzip a1, a0
    Register Should Be Equal        a1      0xffff

    Execute Command                 cpu SetRegister "a0" 0xaaaaaaaa
    Execute Instruction             unzip a1, a0
    Register Should Be Equal        a1      0xffff0000

Should Execute Brev8 Instruction On RV64
    Create 64 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xffffffffffffffff
    Execute Instruction             brev8 a1, a0
    Register Should Be Equal        a1      0xffffffffffffffff

    Execute Command                 cpu SetRegister "a0" 0xdeadbeafbad0cafe
    Execute Instruction             brev8 a1, a0
    Register Should Be Equal        a1      0x7BB57DF55D0B537F

Should Execute Brev8 Instruction On RV32
    Create 32 Bit Machine
    Execute Command                 cpu SetRegister "a0" 0xffffffff
    Execute Instruction             brev8 a1, a0
    Register Should Be Equal        a1      0xffffffff

    Execute Command                 cpu SetRegister "a0" 0xdeadbeaf
    Execute Instruction             brev8 a1, a0
    Register Should Be Equal        a1      0x7BB57DF5

