*** Variables ***
${REPL_WITH_EXTENSIONS}             SEPARATOR=\n
...                                 """
...                                 cpu: CPU.CV32E40P @ sysbus
...                                 ${SPACE*4}hartId: 0
...                                 ${SPACE*4}cpuType: "rv32imc_zicsr_zifencei_zba_zbb_zbs_zcb_zcmp_zcmt"
...                                 ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.PrivUnratified
...                                 ${SPACE*4}timeProvider: empty
...
...                                 # This CPU is only used for AssembleBlock, as there is currently
...                                 # no possibility to create a custom LLVM assembler
...                                 cpu_ext: CPU.CV32E40P @ sysbus
...                                 ${SPACE*4}hartId: 0
...                                 ${SPACE*4}cpuType: "rv32imc_zicsr_zifencei_zba_zbb_zbs_zcb_zcmp_zcmt"
...                                 ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.PrivUnratified
...                                 ${SPACE*4}timeProvider: empty
...                                 sram: Memory.MappedMemory @ sysbus 0x1000
...                                 ${SPACE*4}size: 0x8000
...                                 """

${REPL_NO_EXTENSIONS}               SEPARATOR=\n
...                                 """
...                                 cpu: CPU.CV32E40P @ sysbus
...                                 ${SPACE*4}hartId: 0
...                                 ${SPACE*4}cpuType: "rv32imc_zicsr_zifencei_zba_zbb_zbs"
...                                 ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.PrivUnratified
...                                 ${SPACE*4}timeProvider: empty
...
...                                 # This CPU is only used for AssembleBlock, as there is currently
...                                 # no possibility to create a custom LLVM assembler
...                                 cpu_ext: CPU.CV32E40P @ sysbus
...                                 ${SPACE*4}hartId: 0
...                                 ${SPACE*4}cpuType: "rv32imc_zicsr_zifencei_zba_zbb_zbs_zcb_zcmp_zcmt"
...                                 ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.PrivUnratified
...                                 ${SPACE*4}timeProvider: empty
...                                 sram: Memory.MappedMemory @ sysbus 0x1000
...                                 ${SPACE*4}size: 0x8000
...                                 """

*** Keywords ***
Assemble At Current PC
    [Arguments]                     ${program}
    Execute Command                 cpu_ext AssembleBlock `cpu PC` '${program}'

Check Trap Vector
    [Arguments]                     ${pc}  ${mcause}  ${mtval}  ${mepc}

    ${actual_pc}=                   Execute Command  cpu PC
    Should Be Equal As Numbers      ${actual_pc}  ${pc}
    ${actual_mcause}=               Execute Command  cpu MCAUSE
    Should Be Equal As Numbers      ${actual_mcause}  ${mcause}
    ${actual_mtval}=                Execute Command  cpu MTVAL
    Should Be Equal As Numbers      ${actual_mtval}  ${mtval}
    ${actual_mepc}=                 Execute Command  cpu MEPC
    Should Be Equal As Numbers      ${actual_mepc}  ${mepc}

Should Trap
    [Arguments]                     ${insn}  ${pc}=0x2000
    Execute Command                 cpu PC ${pc}
    Assemble At Current PC          ${insn}
    ${opcode}=                      Execute Command  sysbus ReadWord `cpu PC`
    Execute Command                 cpu Step
    Check Trap Vector               0x3000  2  ${opcode}  ${pc}

Create Machine With Extensions
    Execute Command                 mach create "zcmp_test"
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL_WITH_EXTENSIONS}
    Execute Command                 cpu_ext IsHalted true

Create Machine Without Extensions
    Execute Command                 mach create "zcmp_test"
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL_NO_EXTENSIONS}
    Execute Command                 cpu_ext IsHalted true

*** Test Cases ***
Zcb Load Instructions Test
    Create Machine With Extensions
    # Setup test memory with known data
    Execute Command                 sysbus WriteDoubleWord 0x1000 0x12345678
    Execute Command                 sysbus WriteDoubleWord 0x1004 0x9ABCDEF0

    # Test c.lbu - Load byte unsigned
    Execute Command                 cpu PC 0x2000
    Execute Command                 cpu SetRegister 8 0x1000  # x8 = base address
    Assemble At Current PC          c.lbu x8, 0(x8)
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0x78  # Should load unsigned byte

    # Test c.lhu - Load halfword unsigned
    Execute Command                 cpu PC 0x2004
    Execute Command                 cpu SetRegister 8 0x1000  # x8 = base address
    Assemble At Current PC          c.lhu x8, 0(x8)
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0x5678  # Should load halfword unsigned

    # Test c.lh - Load halfword signed
    Execute Command                 cpu PC 0x2008
    Execute Command                 cpu SetRegister 8 0x1004  # x8 = address with negative halfword
    Assemble At Current PC          c.lh x8, 0(x8)
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0xFFFFDEF0  # Should sign extend negative halfword

Zcb Store Instructions Test
    Create Machine With Extensions

    # Test c.sb - Store byte
    Execute Command                 cpu PC 0x2000
    Execute Command                 cpu SetRegister 8 0x1000  # x8 = base address
    Execute Command                 cpu SetRegister 9 0x000000AB  # x9 = byte value to store
    Assemble At Current PC          c.sb x9, 0(x8)
    Execute Command                 cpu Step
    ${mem_value}=                   Execute Command  sysbus ReadByte 0x1000
    Should Be Equal As Integers     ${mem_value}  0xAB  # Should store byte

    # Test c.sh - Store halfword
    Execute Command                 cpu PC 0x2004
    Execute Command                 cpu SetRegister 8 0x1002  # x8 = base address + 2
    Execute Command                 cpu SetRegister 9 0x0000CDEF  # x9 = halfword value
    Assemble At Current PC          c.sh x9, 0(x8)
    Execute Command                 cpu Step
    ${mem_value}=                   Execute Command  sysbus ReadWord 0x1002
    Should Be Equal As Integers     ${mem_value}  0x0000CDEF  # Should store halfword

Zcb Extend Instructions Test
    Create Machine With Extensions

    # Test c.zext.b - Zero extend byte
    Execute Command                 cpu PC 0x2000
    Execute Command                 cpu SetRegister 8 0x123456AB  # x8 = value with byte to extend
    Assemble At Current PC          c.zext.b x8
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0x000000AB  # Should zero extend LSB

    # Test c.sext.b - Sign extend byte
    Execute Command                 cpu PC 0x2004
    Execute Command                 cpu SetRegister 8 0x000000FF  # x8 = test value with negative byte
    Assemble At Current PC          c.sext.b x8
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0xFFFFFFFF  # Should sign extend negative byte

    # Test c.not - Bitwise NOT
    Execute Command                 cpu PC 0x2008
    Execute Command                 cpu SetRegister 8 0x12345678  # x8 = test value
    Assemble At Current PC          c.not x8
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0xEDCBA987  # Should be bitwise NOT

    # Test c.zext.h - Zero extend halfword
    Execute Command                 cpu PC 0x200C
    Execute Command                 cpu SetRegister 8 0x12345678  # x8 = value with halfword to extend
    Assemble At Current PC          c.zext.h x8
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0x00005678  # Should zero extend lower halfword

    # Test c.sext.h - Sign extend halfword
    Execute Command                 cpu PC 0x2010
    Execute Command                 cpu SetRegister 8 0x1234FFFF  # x8 = value with negative halfword
    Assemble At Current PC          c.sext.h x8
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0xFFFFFFFF  # Should sign extend negative halfword

Zcb Arithmetic Instructions Test
    Create Machine With Extensions

    # Test c.mul
    Execute Command                 cpu PC 0x2000
    Execute Command                 cpu SetRegister 8 0x00000003  # x8 = 3 (rd'/rs1' = 0)
    Execute Command                 cpu SetRegister 9 0x00000005  # x9 = 5 (rs2' = 1)
    Assemble At Current PC          c.mul x8, x9
    Execute Command                 cpu Step
    ${reg_value}=                   Execute Command  cpu GetRegister 8
    Should Be Equal As Integers     ${reg_value}  0x0000000F  # Should be 3 * 5 = 15

Zcb Extension Gating Test
    Create Machine Without Extensions

    # Setup trap handler - infinite loop at trap vector
    Execute Command                 cpu MTVEC 0x3000
    Execute Command                 sysbus WriteDoubleWord 0x3000 0x0000006f  # j . (infinite loop)

    Should Trap                     c.lbu x8, 0(x8)
    Should Trap                     c.lhu x8, 0(x8)
    Should Trap                     c.lh x8, 0(x8)
    Should Trap                     c.sb x9, 0(x8)
    Should Trap                     c.sh x9, 0(x8)
    Should Trap                     c.zext.b x8
    Should Trap                     c.sext.b x8
    Should Trap                     c.zext.h x8
    Should Trap                     c.sext.h x8
    Should Trap                     c.not x8
    Should Trap                     c.mul x8, x9

Zcmp PUSH Instruction Test
    Create Machine With Extensions

    # Test all valid rlist values: 4-15
    # For each rlist, we use spimm=0 for simplicity

    # Set up initial register values - all saved registers (ra, s0-s11)
    Execute Command                 sysbus.cpu SetRegister 2 0x8000  # sp = 0x8000
    Execute Command                 sysbus.cpu SetRegister 1 0x12345678  # ra (x1)
    Execute Command                 sysbus.cpu SetRegister 8 0x11111111  # s0 (x8)
    Execute Command                 sysbus.cpu SetRegister 9 0x22222222  # s1 (x9)
    Execute Command                 sysbus.cpu SetRegister 18 0x33333333  # s2 (x18)
    Execute Command                 sysbus.cpu SetRegister 19 0x44444444  # s3 (x19)
    Execute Command                 sysbus.cpu SetRegister 20 0x55555555  # s4 (x20)
    Execute Command                 sysbus.cpu SetRegister 21 0x66666666  # s5 (x21)
    Execute Command                 sysbus.cpu SetRegister 22 0x77777777  # s6 (x22)
    Execute Command                 sysbus.cpu SetRegister 23 0x88888888  # s7 (x23)
    Execute Command                 sysbus.cpu SetRegister 24 0x99999999  # s8 (x24)
    Execute Command                 sysbus.cpu SetRegister 25 0xAAAAAAAA  # s9 (x25)
    Execute Command                 sysbus.cpu SetRegister 26 0xBBBBBBBB  # s10 (x26)
    Execute Command                 sysbus.cpu SetRegister 27 0xCCCCCCCC  # s11 (x27)

    # Test rlist=4: cm.push {ra}, -16
    Execute Command                 sysbus.cpu PC 0x2000
    Assemble At Current PC          cm.push {ra}, -16
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FF0  # 0x8000 - 16
    ${stored_ra}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_ra}  0x12345678

    # Test rlist=5: cm.push {ra, s0}, -16
    Execute Command                 sysbus.cpu SetRegister 2 0x8000  # Reset sp
    Execute Command                 sysbus.cpu PC 0x2004
    Assemble At Current PC          cm.push {ra, s0}, -16
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FF0  # 0x8000 - 16
    ${stored_s0}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s0}  0x11111111
    ${stored_ra}=                   Execute Command  sysbus ReadDoubleWord 0x7FF8
    Should Be Equal As Numbers      ${stored_ra}  0x12345678

    # Test rlist=6: cm.push {ra, s0-s1}, -16
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x2008
    Assemble At Current PC          cm.push {ra, s0-s1}, -16
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FF0  # 0x8000 - 16
    ${stored_s1}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s1}  0x22222222
    ${stored_s0}=                   Execute Command  sysbus ReadDoubleWord 0x7FF8
    Should Be Equal As Numbers      ${stored_s0}  0x11111111
    ${stored_ra}=                   Execute Command  sysbus ReadDoubleWord 0x7FF4
    Should Be Equal As Numbers      ${stored_ra}  0x12345678

    # Test rlist=7: cm.push {ra, s0-s2}, -16
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x200C
    Assemble At Current PC          cm.push {ra, s0-s2}, -16
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FF0  # 0x8000 - 16
    ${stored_s2}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s2}  0x33333333

    # Test rlist=8: cm.push {ra, s0-s3}, -32
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x2010
    Assemble At Current PC          cm.push {ra, s0-s3}, -32
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FE0  # 0x8000 - 32
    ${stored_s3}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s3}  0x44444444

    # Test rlist=9: cm.push {ra, s0-s4}, -32
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x2014
    Assemble At Current PC          cm.push {ra, s0-s4}, -32
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FE0  # 0x8000 - 32
    ${stored_s4}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s4}  0x55555555

    # Test rlist=10: cm.push {ra, s0-s5}, -32
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x2018
    Assemble At Current PC          cm.push {ra, s0-s5}, -32
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FE0  # 0x8000 - 32
    ${stored_s5}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s5}  0x66666666

    # Test rlist=11: cm.push {ra, s0-s6}, -32
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x201C
    Assemble At Current PC          cm.push {ra, s0-s6}, -32
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FE0  # 0x8000 - 32
    ${stored_s6}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s6}  0x77777777

    # Test rlist=12: cm.push {ra, s0-s7}, -48
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x2020
    Assemble At Current PC          cm.push {ra, s0-s7}, -48
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FD0  # 0x8000 - 48
    ${stored_s7}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s7}  0x88888888

    # Test rlist=13: cm.push {ra, s0-s8}, -48
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x2024
    Assemble At Current PC          cm.push {ra, s0-s8}, -48
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FD0  # 0x8000 - 48
    ${stored_s8}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s8}  0x99999999

    # Test rlist=14: cm.push {ra, s0-s9}, -48
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x2028
    Assemble At Current PC          cm.push {ra, s0-s9}, -48
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FD0  # 0x8000 - 48
    ${stored_s9}=                   Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s9}  0xAAAAAAAA

    # Test rlist=15: cm.push {ra, s0-s11}, -64
    Execute Command                 sysbus.cpu SetRegister 2 0x8000
    Execute Command                 sysbus.cpu PC 0x202C
    Assemble At Current PC          cm.push {ra, s0-s11}, -64
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7FC0  # 0x8000 - 64
    ${stored_s11}=                  Execute Command  sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s11}  0xCCCCCCCC
    ${stored_s10}=                  Execute Command  sysbus ReadDoubleWord 0x7FF8
    Should Be Equal As Numbers      ${stored_s10}  0xBBBBBBBB

Zcmp POP Instruction Test
    Create Machine With Extensions

    # Test all valid rlist values: 4-15
    # For each rlist, we use spimm=0 for simplicity
    # POP loads from addresses: sp + stack_adj - reg_size, working backwards
    Execute Command                 sysbus.cpu SetRegister 2 0x6000  # Set sp within valid RAM range

    # Test rlist=4: cm.pop {ra}, +16
    # Loads from: 0x6000+16-4=0x600C
    Execute Command                 sysbus WriteDoubleWord 0x600C 0x12345678  # ra
    Execute Command                 sysbus.cpu PC 0x3000
    Assemble At Current PC          cm.pop {ra}, 16
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6010
    ${ra}=                          Execute Command  sysbus.cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x12345678

    # Test rlist=5: cm.pop {ra, s0}, +16
    # Loads from: s0@0x600C, ra@0x6008
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x600C 0x11111111  # s0
    Execute Command                 sysbus WriteDoubleWord 0x6008 0x12340001  # ra
    Execute Command                 sysbus.cpu PC 0x3004
    Assemble At Current PC          cm.pop {ra, s0}, 16
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6010
    ${s0}=                          Execute Command  sysbus.cpu GetRegister 8
    Should Be Equal As Numbers      ${s0}  0x11111111

    # Test rlist=6: cm.pop {ra, s0-s1}, +16
    # Loads from: s1@0x600C, s0@0x6008, ra@0x6004
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x600C 0x22222222  # s1
    Execute Command                 sysbus WriteDoubleWord 0x6008 0x11110001  # s0
    Execute Command                 sysbus WriteDoubleWord 0x6004 0x12340002  # ra
    Execute Command                 sysbus.cpu PC 0x3008
    Assemble At Current PC          cm.pop {ra, s0-s1}, 16
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6010
    ${s1}=                          Execute Command  sysbus.cpu GetRegister 9
    Should Be Equal As Numbers      ${s1}  0x22222222

    # Test rlist=7: cm.pop {ra, s0-s2}, +16
    # Loads from: s2@0x600C, s1@0x6008, s0@0x6004, ra@0x6000
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x600C 0x33333333  # s2
    Execute Command                 sysbus.cpu PC 0x300C
    Assemble At Current PC          cm.pop {ra, s0-s2}, 16
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6010
    ${s2}=                          Execute Command  sysbus.cpu GetRegister 18
    Should Be Equal As Numbers      ${s2}  0x33333333

    # Test rlist=8: cm.pop {ra, s0-s3}, +32
    # Loads from: s3@0x601C (sp+32-4)
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x601C 0x44444444  # s3
    Execute Command                 sysbus.cpu PC 0x3010
    Assemble At Current PC          cm.pop {ra, s0-s3}, 32
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6020
    ${s3}=                          Execute Command  sysbus.cpu GetRegister 19
    Should Be Equal As Numbers      ${s3}  0x44444444

    # Test rlist=9: cm.pop {ra, s0-s4}, +32
    # Loads from: s4@0x601C
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x601C 0x55555555  # s4
    Execute Command                 sysbus.cpu PC 0x3014
    Assemble At Current PC          cm.pop {ra, s0-s4}, 32
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6020
    ${s4}=                          Execute Command  sysbus.cpu GetRegister 20
    Should Be Equal As Numbers      ${s4}  0x55555555

    # Test rlist=10: cm.pop {ra, s0-s5}, +32
    # Loads from: s5@0x601C
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x601C 0x66666666  # s5
    Execute Command                 sysbus.cpu PC 0x3018
    Assemble At Current PC          cm.pop {ra, s0-s5}, 32
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6020
    ${s5}=                          Execute Command  sysbus.cpu GetRegister 21
    Should Be Equal As Numbers      ${s5}  0x66666666

    # Test rlist=11: cm.pop {ra, s0-s6}, +32
    # Loads from: s6@0x601C
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x601C 0x77777777  # s6
    Execute Command                 sysbus.cpu PC 0x301C
    Assemble At Current PC          cm.pop {ra, s0-s6}, 32
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6020
    ${s6}=                          Execute Command  sysbus.cpu GetRegister 22
    Should Be Equal As Numbers      ${s6}  0x77777777

    # Test rlist=12: cm.pop {ra, s0-s7}, +48
    # Loads from: s7@0x602C (sp+48-4)
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x602C 0x88888888  # s7
    Execute Command                 sysbus.cpu PC 0x3020
    Assemble At Current PC          cm.pop {ra, s0-s7}, 48
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6030
    ${s7}=                          Execute Command  sysbus.cpu GetRegister 23
    Should Be Equal As Numbers      ${s7}  0x88888888

    # Test rlist=13: cm.pop {ra, s0-s8}, +48
    # Loads from: s8@0x602C
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x602C 0x99999999  # s8
    Execute Command                 sysbus.cpu PC 0x3024
    Assemble At Current PC          cm.pop {ra, s0-s8}, 48
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6030
    ${s8}=                          Execute Command  sysbus.cpu GetRegister 24
    Should Be Equal As Numbers      ${s8}  0x99999999

    # Test rlist=14: cm.pop {ra, s0-s9}, +48
    # Loads from: s9@0x602C
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x602C 0xAAAAAAAA  # s9
    Execute Command                 sysbus.cpu PC 0x3028
    Assemble At Current PC          cm.pop {ra, s0-s9}, 48
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6030
    ${s9}=                          Execute Command  sysbus.cpu GetRegister 25
    Should Be Equal As Numbers      ${s9}  0xAAAAAAAA

    # Test rlist=15: cm.pop {ra, s0-s11}, +64
    # Loads from: s11@0x603C (sp+64-4), s10@0x6038
    Execute Command                 sysbus.cpu SetRegister 2 0x6000
    Execute Command                 sysbus WriteDoubleWord 0x603C 0xCCCCCCCC  # s11
    Execute Command                 sysbus WriteDoubleWord 0x6038 0xBBBBBBBB  # s10
    Execute Command                 sysbus.cpu PC 0x302C
    Assemble At Current PC          cm.pop {ra, s0-s11}, 64
    Execute Command                 sysbus.cpu Step
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x6040
    ${s11}=                         Execute Command  sysbus.cpu GetRegister 27
    Should Be Equal As Numbers      ${s11}  0xCCCCCCCC
    ${s10}=                         Execute Command  sysbus.cpu GetRegister 26
    Should Be Equal As Numbers      ${s10}  0xBBBBBBBB

Zcmp POPRET Instruction Test
    Create Machine With Extensions

    # Test C.POPRET instruction (cm.popret) - combines pop and return
    # Set up stack with data in same layout that PUSH would create (at top of allocated space)
    Execute Command                 sysbus.cpu SetRegister 2 0x7000  # Set sp within valid RAM range

    # For cm.popret {ra}, +16: ra at sp+16-4=0x700C
    Execute Command                 sysbus WriteDoubleWord 0x700C 0x8000  # ra = return address 0x8000
    Execute Command                 sysbus WriteDoubleWord 0x8000 0x0000006f  # Write "j ." at return address (infinite loop for test)

    # For cm.popret {ra, s0}, +32: ra at 0x7018, s0 at 0x701C
    Execute Command                 sysbus WriteDoubleWord 0x7018 0x8000  # ra for second test
    Execute Command                 sysbus WriteDoubleWord 0x701C 0xABCD1234  # s0 value

    # For cm.popret {ra, s0-s1}, +48: ra at 0x7024, s0 at 0x7028, s1 at 0x702C
    Execute Command                 sysbus WriteDoubleWord 0x7024 0x8000  # ra for third test
    Execute Command                 sysbus WriteDoubleWord 0x7028 0xABCD1234  # s0 value
    Execute Command                 sysbus WriteDoubleWord 0x702C 0x56789ABC  # s1 value

    # Clear registers before testing popret
    Execute Command                 sysbus.cpu SetRegister 1 0x00000000  # Clear ra
    Execute Command                 sysbus.cpu SetRegister 8 0x00000000  # Clear s0
    Execute Command                 sysbus.cpu SetRegister 9 0x00000000  # Clear s1

    # Test cm.popret {ra}, +16 (rlist=4, spimm=0)
    # Encoding: [15:13]=101, [12:8]=11110, [7:4]=0100, [3:2]=00, [1:0]=10
    Execute Command                 sysbus.cpu PC 0x3000
    Assemble At Current PC          cm.popret {ra}, 16
    Execute Command                 sysbus.cpu Step

    # Verify stack pointer increased by 16
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7010  # 0x7000 + 16

    # Verify ra was loaded
    ${ra}=                          Execute Command  sysbus.cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x8000

    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}  0x8000  # Should have jumped to ra

    # Test cm.popret {ra, s0}, +32 (rlist=5, spimm=1)
    # Reset for next test
    Execute Command                 sysbus.cpu SetRegister 2 0x7000  # Reset sp
    Execute Command                 sysbus.cpu SetRegister 1 0x00000000  # Clear ra
    Execute Command                 sysbus.cpu SetRegister 8 0x00000000  # Clear s0

    # Encoding: [15:13]=101, [12:8]=11110, [7:4]=0101, [3:2]=01, [1:0]=10
    Execute Command                 sysbus.cpu PC 0x3004
    Assemble At Current PC          cm.popret {ra, s0}, 32
    Execute Command                 sysbus.cpu Step

    # Verify stack pointer increased by 32 (16 base + 16 extra)
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7020  # 0x7000 + 32

    # Verify ra was loaded
    ${ra}=                          Execute Command  sysbus.cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x8000

    # Verify s0 was loaded
    ${s0}=                          Execute Command  sysbus.cpu GetRegister 8
    Should Be Equal As Numbers      ${s0}  0xABCD1234

    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}  0x8000  # Should have jumped to ra

    # Test cm.popret {ra, s0-s1}, +48 (rlist=6, spimm=2)
    # Reset for final test
    Execute Command                 sysbus.cpu SetRegister 2 0x7000  # Reset sp
    Execute Command                 sysbus.cpu SetRegister 1 0x00000000  # Clear ra
    Execute Command                 sysbus.cpu SetRegister 8 0x00000000  # Clear s0
    Execute Command                 sysbus.cpu SetRegister 9 0x00000000  # Clear s1

    # Encoding: [15:13]=101, [12:8]=11110, [7:4]=0110, [3:2]=10, [1:0]=10
    Execute Command                 sysbus.cpu PC 0x3008
    Assemble At Current PC          cm.popret {ra, s0-s1}, 48
    Execute Command                 sysbus.cpu Step

    # Verify stack pointer increased by 48 (16 base + 32 extra)
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7030  # 0x7000 + 48

    # Verify all registers were loaded correctly
    ${ra}=                          Execute Command  sysbus.cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x8000
    ${s0}=                          Execute Command  sysbus.cpu GetRegister 8
    Should Be Equal As Numbers      ${s0}  0xABCD1234
    ${s1}=                          Execute Command  sysbus.cpu GetRegister 9
    Should Be Equal As Numbers      ${s1}  0x56789ABC

    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}  0x8000  # Should have jumped to ra

Zcmp POPRETZ Instruction Test
    Create Machine With Extensions

    # Test C.POPRETZ instruction (cm.popretz) - combines pop, set a0=0, and return
    # Set up stack with data in same layout that PUSH would create (at top of allocated space)
    Execute Command                 sysbus.cpu SetRegister 2 0x7000  # Set sp within valid RAM range

    # For cm.popretz {ra}, +16: ra at sp+16-4=0x700C
    Execute Command                 sysbus WriteDoubleWord 0x700C 0x8000  # ra = return address 0x8000
    Execute Command                 sysbus WriteDoubleWord 0x8000 0x0000006f  # Write "j ." at return address (infinite loop for test)

    # For cm.popretz {ra, s0}, +32: ra at 0x7018, s0 at 0x701C
    Execute Command                 sysbus WriteDoubleWord 0x7018 0x8000  # ra for second test
    Execute Command                 sysbus WriteDoubleWord 0x701C 0x11223344  # s0 value

    # For cm.popretz {ra, s0-s1}, +48: ra at 0x7024, s0 at 0x7028, s1 at 0x702C
    Execute Command                 sysbus WriteDoubleWord 0x7024 0x8000  # ra for third test
    Execute Command                 sysbus WriteDoubleWord 0x7028 0x11223344  # s0 value
    Execute Command                 sysbus WriteDoubleWord 0x702C 0x55667788  # s1 value

    # Clear registers before testing popretz
    Execute Command                 sysbus.cpu SetRegister 1 0x00000000  # Clear ra
    Execute Command                 sysbus.cpu SetRegister 8 0x00000000  # Clear s0
    Execute Command                 sysbus.cpu SetRegister 9 0x00000000  # Clear s1
    Execute Command                 sysbus.cpu SetRegister 10 0xFFFFFFFF  # Set a0 to non-zero value

    # Test cm.popretz {ra}, +16 (rlist=4, spimm=0)
    # Encoding: [15:13]=101, [12:8]=11100, [7:4]=0100, [3:2]=00, [1:0]=10
    Execute Command                 sysbus.cpu PC 0x3000
    Assemble At Current PC          cm.popretz {ra}, 16
    Execute Command                 sysbus.cpu Step

    # Verify stack pointer increased by 16
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7010  # 0x7000 + 16

    # Verify ra was loaded
    ${ra}=                          Execute Command  sysbus.cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x8000

    # Verify a0 was set to 0
    ${a0}=                          Execute Command  sysbus.cpu GetRegister 10
    Should Be Equal As Numbers      ${a0}  0x0  # Should be 0

    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}  0x8000  # Should have jumped to ra

    # Test cm.popretz {ra, s0}, +32 (rlist=5, spimm=1)
    # Reset for next test
    Execute Command                 sysbus.cpu SetRegister 2 0x7000  # Reset sp
    Execute Command                 sysbus.cpu SetRegister 1 0x00000000  # Clear ra
    Execute Command                 sysbus.cpu SetRegister 8 0x00000000  # Clear s0
    Execute Command                 sysbus.cpu SetRegister 10 0x12345678  # Set a0 to non-zero value

    # Encoding: [15:13]=101, [12:8]=11100, [7:4]=0101, [3:2]=01, [1:0]=10
    Execute Command                 sysbus.cpu PC 0x3004
    Assemble At Current PC          cm.popretz {ra, s0}, 32
    Execute Command                 sysbus.cpu Step

    # Verify stack pointer increased by 32 (16 base + 16 extra)
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7020  # 0x7000 + 32

    # Verify ra was loaded
    ${ra}=                          Execute Command  sysbus.cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x8000

    # Verify s0 was loaded
    ${s0}=                          Execute Command  sysbus.cpu GetRegister 8
    Should Be Equal As Numbers      ${s0}  0x11223344

    # Verify a0 was set to 0 (not the original non-zero value)
    ${a0}=                          Execute Command  sysbus.cpu GetRegister 10
    Should Be Equal As Numbers      ${a0}  0x0  # Should be 0, not 0x12345678

    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}  0x8000  # Should have jumped to ra

    # Test cm.popretz {ra, s0-s1}, +48 (rlist=6, spimm=2)
    # Reset for final test
    Execute Command                 sysbus.cpu SetRegister 2 0x7000  # Reset sp
    Execute Command                 sysbus.cpu SetRegister 1 0x00000000  # Clear ra
    Execute Command                 sysbus.cpu SetRegister 8 0x00000000  # Clear s0
    Execute Command                 sysbus.cpu SetRegister 9 0x00000000  # Clear s1
    Execute Command                 sysbus.cpu SetRegister 10 0xAABBCCDD  # Set a0 to non-zero value

    # Encoding: [15:13]=101, [12:8]=11100, [7:4]=0110, [3:2]=10, [1:0]=10
    Execute Command                 sysbus.cpu PC 0x3008
    Assemble At Current PC          cm.popretz {ra, s0-s1}, 48
    Execute Command                 sysbus.cpu Step

    # Verify stack pointer increased by 48 (16 base + 32 extra)
    ${sp}=                          Execute Command  sysbus.cpu GetRegister 2
    Should Be Equal As Numbers      ${sp}  0x7030  # 0x7000 + 48

    # Verify all registers were loaded correctly
    ${ra}=                          Execute Command  sysbus.cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x8000
    ${s0}=                          Execute Command  sysbus.cpu GetRegister 8
    Should Be Equal As Numbers      ${s0}  0x11223344
    ${s1}=                          Execute Command  sysbus.cpu GetRegister 9
    Should Be Equal As Numbers      ${s1}  0x55667788

    # Verify a0 was set to 0 (critical test - this is what differentiates POPRETZ from POPRET)
    ${a0}=                          Execute Command  sysbus.cpu GetRegister 10
    Should Be Equal As Numbers      ${a0}  0x0  # Should be 0, not 0xAABBCCDD

    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}  0x8000  # Should have jumped to ra

Zcmp MVSA01 Instruction Test
    Create Machine With Extensions

    # Test C.MVSA01 instruction (cm.mvsa01) - move a0→r1s', a1→r2s'
    Execute Command                 cpu PC 0x2000

    # Setup: Set a0 and a1 to known values
    Execute Command                 cpu SetRegister 10 0x12345678  # a0 = test value 1
    Execute Command                 cpu SetRegister 11 0x9ABCDEF0  # a1 = test value 2
    Execute Command                 cpu SetRegister 8 0x00000000  # s0 = 0 (clear destination)
    Execute Command                 cpu SetRegister 9 0x00000000  # s1 = 0 (clear destination)

    # Test 1: C.MVSA01 s0, s1 (move a0→s0, a1→s1)
    Assemble At Current PC          cm.mvsa01 s0, s1
    Execute Command                 cpu Step

    # Verify: s0 should contain a0 value, s1 should contain a1 value
    ${s0_value}=                    Execute Command  cpu GetRegister 8
    Should Be Equal As Numbers      ${s0_value}  0x12345678  # s0 should equal original a0
    ${s1_value}=                    Execute Command  cpu GetRegister 9
    Should Be Equal As Numbers      ${s1_value}  0x9ABCDEF0  # s1 should equal original a1

    # Test 2: C.MVSA01 s2, s3 (move a0→s2, a1→s3)
    Execute Command                 cpu PC 0x2004
    Execute Command                 cpu SetRegister 10 0xDEADBEEF  # a0 = new test value
    Execute Command                 cpu SetRegister 11 0xCAFEBABE  # a1 = new test value
    Execute Command                 cpu SetRegister 18 0x00000000  # s2 = 0 (clear destination)
    Execute Command                 cpu SetRegister 19 0x00000000  # s3 = 0 (clear destination)

    Assemble At Current PC          cm.mvsa01 s2, s3
    Execute Command                 cpu Step

    # Verify: s2 should contain a0 value, s3 should contain a1 value
    ${s2_value}=                    Execute Command  cpu GetRegister 18
    Should Be Equal As Numbers      ${s2_value}  0xDEADBEEF  # s2 should equal a0
    ${s3_value}=                    Execute Command  cpu GetRegister 19
    Should Be Equal As Numbers      ${s3_value}  0xCAFEBABE  # s3 should equal a1

Zcmp MVA01S Instruction Test
    Create Machine With Extensions

    # Test C.MVA01S instruction (cm.mva01s) - move r1s'→a0, r2s'→a1
    Execute Command                 cpu PC 0x2000

    # Setup: Set s-registers to known values and clear a0/a1
    Execute Command                 cpu SetRegister 8 0x11111111  # s0 = test value 1
    Execute Command                 cpu SetRegister 9 0x22222222  # s1 = test value 2
    Execute Command                 cpu SetRegister 10 0x00000000  # a0 = 0 (clear destination)
    Execute Command                 cpu SetRegister 11 0x00000000  # a1 = 0 (clear destination)

    # Test 1: C.MVA01S s0, s1 (move s0→a0, s1→a1)
    Assemble At Current PC          cm.mva01s s0, s1
    Execute Command                 cpu Step

    # Verify: a0 should contain s0 value, a1 should contain s1 value
    ${a0_value}=                    Execute Command  cpu GetRegister 10
    Should Be Equal As Numbers      ${a0_value}  0x11111111  # a0 should equal original s0
    ${a1_value}=                    Execute Command  cpu GetRegister 11
    Should Be Equal As Numbers      ${a1_value}  0x22222222  # a1 should equal original s1

    # Test 2: C.MVA01S s4, s5 (move s4→a0, s5→a1)
    Execute Command                 cpu PC 0x2004
    Execute Command                 cpu SetRegister 20 0x33333333  # s4 = new test value
    Execute Command                 cpu SetRegister 21 0x44444444  # s5 = new test value
    Execute Command                 cpu SetRegister 10 0x00000000  # a0 = 0 (clear destination)
    Execute Command                 cpu SetRegister 11 0x00000000  # a1 = 0 (clear destination)

    Assemble At Current PC          cm.mva01s s4, s5
    Execute Command                 cpu Step

    # Verify: a0 should contain s4 value, a1 should contain s5 value
    ${a0_value}=                    Execute Command  cpu GetRegister 10
    Should Be Equal As Numbers      ${a0_value}  0x33333333  # a0 should equal s4
    ${a1_value}=                    Execute Command  cpu GetRegister 11
    Should Be Equal As Numbers      ${a1_value}  0x44444444  # a1 should equal s5

Zcmp Extension Gating Test
    Create Machine Without Extensions

    # Setup trap handler - infinite loop at trap vector
    Execute Command                 cpu MTVEC 0x3000
    Execute Command                 sysbus WriteDoubleWord 0x3000 0x0000006f  # j . (infinite loop)

    Should Trap                     cm.push {ra}, -16
    Should Trap                     cm.pop {ra}, 16
    Should Trap                     cm.popret {ra}, 16
    Should Trap                     cm.popretz {ra}, 16
    Should Trap                     cm.mvsa01 s0, s1
    Should Trap                     cm.mva01s s0, s1

Zcmt JT Instruction Test
    Create Machine With Extensions

    # Test cm.jt instruction (cm.jt) - table-based jump via JVT CSR
    # Set up Jump Vector Table (JVT) at known memory location
    Execute Command                 cpu JVT 0x4000  # Set JVT CSR to table base address 0x4000

    # Initialize jump table entries (4-byte entries for RV32)
    Execute Command                 sysbus WriteDoubleWord 0x4000 0x5000  # Table[0] -> 0x5000
    Execute Command                 sysbus WriteDoubleWord 0x4004 0x5100  # Table[1] -> 0x5100
    Execute Command                 sysbus WriteDoubleWord 0x4008 0x5200  # Table[2] -> 0x5200
    Execute Command                 sysbus WriteDoubleWord 0x407C 0x5300  # Table[31] -> 0x5300

    # Test 1: cm.jt with index 0
    # CMJT format: [15:13]=101 [12:10]=000 [9:2]=00000000 (index < 32), [1:0]=10
    Execute Command                 cpu PC 0x3000
    Assemble At Current PC          cm.jt 0
    Execute Command                 cpu Step

    # Verify PC jumped to table[0] target (0x5000)
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  0x5000  # Should jump to table[0]

    # Test 2: cm.jt with index 1 (bits [9:2] = 00000001)
    Execute Command                 cpu PC 0x3004
    Assemble At Current PC          cm.jt 1
    Execute Command                 cpu Step

    # Verify PC jumped to table[1] target (0x5100)
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  0x5100  # Should jump to table[1]

    # Test 3: cm.jt with index 2 (bits [9:2] = 00000010)
    Execute Command                 cpu PC 0x3008
    Assemble At Current PC          cm.jt 2
    Execute Command                 cpu Step

    # Verify PC jumped to table[2] target (0x5200)
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  0x5200  # Should jump to table[2]

    # Test 4: cm.jt with index 31 (bits [9:2] = 00011111)
    Execute Command                 cpu PC 0x300C
    Assemble At Current PC          cm.jt 31
    Execute Command                 cpu Step

    # Verify PC jumped to table[31] target (0x5300)
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  0x5300  # Should jump to table[31]

Zcmt JALT Instruction Test
    Create Machine With Extensions

    # Setup JVT CSR to point to jump table at 0x4000
    Execute Command                 cpu JVT 0x4000

    # Setup jump table in memory
    # table[32] = 0x5000, table[33] = 0x5100, table[34] = 0x5200, table[63] = 0x5300
    Execute Command                 sysbus WriteDoubleWord 0x4080 0x00005000  # table[32]
    Execute Command                 sysbus WriteDoubleWord 0x4084 0x00005100  # table[33]
    Execute Command                 sysbus WriteDoubleWord 0x4088 0x00005200  # table[34]
    Execute Command                 sysbus WriteDoubleWord 0x40FC 0x00005300  # table[63]

    # Test 1: cm.jalt with index 32 (bits [9:2] = 00100000)
    # Encoding: [15:13]=101, [12:10]=000, [9:2]=00100000, [1:0]=10
    Execute Command                 cpu PC 0x3000
    Execute Command                 cpu SetRegister 1 0x0  # Clear ra before test
    Assemble At Current PC          cm.jalt 32
    Execute Command                 cpu Step

    # Verify PC jumped to table[32] target (0x5000)
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  0x5000  # Should jump to table[32]

    # Verify ra was set to return address (PC + 2)
    ${ra}=                          Execute Command  cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x3002  # Should be 0x3000 + 2

    # Test 2: cm.jalt with index 33 (bits [9:2] = 00100001)
    Execute Command                 cpu PC 0x3004
    Execute Command                 cpu SetRegister 1 0x0  # Clear ra before test
    Assemble At Current PC          cm.jalt 33
    Execute Command                 cpu Step

    # Verify PC jumped to table[33] target (0x5100)
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  0x5100  # Should jump to table[33]

    # Verify ra was set to return address (PC + 2)
    ${ra}=                          Execute Command  cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x3006  # Should be 0x3004 + 2

    # Test 3: cm.jalt with index 34 (bits [9:2] = 00100010)
    Execute Command                 cpu PC 0x3008
    Execute Command                 cpu SetRegister 1 0x0  # Clear ra before test
    Assemble At Current PC          cm.jalt 34
    Execute Command                 cpu Step

    # Verify PC jumped to table[34] target (0x5200)
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  0x5200  # Should jump to table[34]

    # Verify ra was set to return address (PC + 2)
    ${ra}=                          Execute Command  cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x300A  # Should be 0x3008 + 2

    # Test 4: cm.jalt with index 63 (bits [9:2] = 00111111)
    Execute Command                 cpu PC 0x300C
    Execute Command                 cpu SetRegister 1 0x0  # Clear ra before test
    Assemble At Current PC          cm.jalt 63
    Execute Command                 cpu Step

    # Verify PC jumped to table[63] target (0x5300)
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  0x5300  # Should jump to table[63]

    # Verify ra was set to return address (PC + 2)
    ${ra}=                          Execute Command  cpu GetRegister 1
    Should Be Equal As Numbers      ${ra}  0x300E  # Should be 0x300C + 2

Zcmt Extension Gating Test
    Create Machine Without Extensions

    # Setup trap handler - infinite loop at trap vector
    Execute Command                 cpu MTVEC 0x3000
    Execute Command                 sysbus WriteDoubleWord 0x3000 0x0000006f  # j . (infinite loop)

    Should Trap                     cm.jt 0
    Should Trap                     cm.jalt 32
