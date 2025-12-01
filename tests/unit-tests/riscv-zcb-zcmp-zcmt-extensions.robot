*** Variables ***
${REPL_WITH_EXTENSIONS}=  SEPARATOR=\n
...  """
...  cpu: CPU.CV32E40P @ sysbus
...  ${SPACE*4}hartId: 0
...  ${SPACE*4}cpuType: "rv32imc_zicsr_zifencei_zba_zbb_zbs_zcb_zcmp_zcmt"
...  ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.PrivUnratified
...  ${SPACE*4}timeProvider: empty
...  sram: Memory.MappedMemory @ sysbus 0x1000
...  ${SPACE*4}size: 0x8000
...  """

${REPL_NO_EXTENSIONS}=  SEPARATOR=\n
...  """
...  cpu: CPU.CV32E40P @ sysbus
...  ${SPACE*4}hartId: 0
...  ${SPACE*4}cpuType: "rv32imc_zicsr_zifencei_zba_zbb_zbs"
...  ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.PrivUnratified
...  ${SPACE*4}timeProvider: empty
...  sram: Memory.MappedMemory @ sysbus 0x1000
...  ${SPACE*4}size: 0x8000
...  """


*** Keywords ***
Create Machine With Extensions
    Execute Command          mach create "zcmp_test"
    Execute Command          machine LoadPlatformDescriptionFromString ${REPL_WITH_EXTENSIONS}

Create Machine Without Extensions
    Execute Command          mach create "zcmp_test"
    Execute Command          machine LoadPlatformDescriptionFromString ${REPL_NO_EXTENSIONS}


*** Test Cases ***    
Zcb Load Instructions Test
    Create Machine With Extensions
    # Setup test memory with known data
    Execute Command          sysbus WriteDoubleWord 0x1000 0x12345678
    Execute Command          sysbus WriteDoubleWord 0x1004 0x9ABCDEF0
    
    # Test c.lbu - Load byte unsigned
    Execute Command              cpu PC 0x2000
    Execute Command              cpu SetRegisterUnsafe 8 0x1000       # x8 = base address  
    Execute Command              sysbus WriteWord 0x2000 0x8000       # c.lbu x8, 0(x8)
    Execute Command              cpu Step
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Integers  ${reg_value}  0x78         # Should load unsigned byte
    
    # Test c.lhu - Load halfword unsigned
    Execute Command              cpu PC 0x2004
    Execute Command              cpu SetRegisterUnsafe 8 0x1000       # x8 = base address
    Execute Command              sysbus WriteWord 0x2004 0x8400       # c.lhu x8, 0(x8)
    Execute Command              cpu Step
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Integers  ${reg_value}  0x5678       # Should load halfword unsigned
    
    # Test c.lh - Load halfword signed  
    Execute Command              cpu PC 0x2008
    Execute Command              cpu SetRegisterUnsafe 8 0x1004       # x8 = address with negative halfword
    Execute Command              sysbus WriteWord 0x2008 0x8440       # c.lh x8, 0(x8)
    Execute Command              cpu Step  
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Integers  ${reg_value}  0xFFFFDEF0   # Should sign extend negative halfword

Zcb Store Instructions Test
    Create Machine With Extensions
    
    # Test c.sb - Store byte
    Execute Command              cpu PC 0x2000
    Execute Command              cpu SetRegisterUnsafe 8 0x1000       # x8 = base address
    Execute Command              cpu SetRegisterUnsafe 9 0x000000AB   # x9 = byte value to store
    Execute Command              sysbus WriteWord 0x2000 0x8804       # c.sb x9, 0(x8)
    Execute Command              cpu Step
    ${mem_value}=                Execute Command  sysbus ReadByte 0x1000
    Should Be Equal As Integers  ${mem_value}  0xAB              # Should store byte
    
    # Test c.sh - Store halfword  
    Execute Command              cpu PC 0x2004
    Execute Command              cpu SetRegisterUnsafe 8 0x1002       # x8 = base address + 2
    Execute Command              cpu SetRegisterUnsafe 9 0x0000CDEF   # x9 = halfword value
    Execute Command              sysbus WriteWord 0x2004 0x8C04       # c.sh x9, 0(x8)
    Execute Command              cpu Step
    ${mem_value}=                Execute Command  sysbus ReadWord 0x1002
    Should Be Equal As Integers  ${mem_value}  0x0000CDEF        # Should store halfword

Zcb Extend Instructions Test
    Create Machine With Extensions
    
    # Test c.zext.b - Zero extend byte
    Execute Command              cpu PC 0x2000
    Execute Command              cpu SetRegisterUnsafe 8 0x123456AB   # x8 = value with byte to extend
    Execute Command              sysbus WriteWord 0x2000 0x9C61       # c.zext.b x8
    Execute Command              cpu Step
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Integers  ${reg_value}  0x000000AB        # Should zero extend LSB
    
    # Test c.sext.b - Sign extend byte
    Execute Command              cpu PC 0x2004
    Execute Command              cpu SetRegisterUnsafe 8 0x000000FF   # x8 = test value with negative byte
    Execute Command              sysbus WriteWord 0x2004 0x9C65       # c.sext.b x8
    Execute Command              cpu Step
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8  
    Should Be Equal As Integers  ${reg_value}  0xFFFFFFFF        # Should sign extend negative byte
    
    # Test c.not - Bitwise NOT
    Execute Command              cpu PC 0x2008
    Execute Command              cpu SetRegisterUnsafe 8 0x12345678   # x8 = test value
    Execute Command              sysbus WriteWord 0x2008 0x9C75       # c.not x8
    Execute Command              cpu Step
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Integers  ${reg_value}  0xEDCBA987        # Should be bitwise NOT
    
    # Test c.zext.h - Zero extend halfword
    Execute Command              cpu PC 0x200C
    Execute Command              cpu SetRegisterUnsafe 8 0x12345678   # x8 = value with halfword to extend
    Execute Command              sysbus WriteWord 0x200C 0x9C69       # c.zext.h x8
    Execute Command              cpu Step
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Integers  ${reg_value}  0x00005678        # Should zero extend lower halfword
    
    # Test c.sext.h - Sign extend halfword
    Execute Command              cpu PC 0x2010
    Execute Command              cpu SetRegisterUnsafe 8 0x1234FFFF   # x8 = value with negative halfword  
    Execute Command              sysbus WriteWord 0x2010 0x9C6D       # c.sext.h x8
    Execute Command              cpu Step
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Integers  ${reg_value}  0xFFFFFFFF        # Should sign extend negative halfword

Zcb Arithmetic Instructions Test
    Create Machine With Extensions
        
    # Test c.mul
    Execute Command              cpu PC 0x2000
    Execute Command              cpu SetRegisterUnsafe 8 0x00000003   # x8 = 3 (rd'/rs1' = 0)
    Execute Command              cpu SetRegisterUnsafe 9 0x00000005   # x9 = 5 (rs2' = 1)
    Execute Command              sysbus WriteWord 0x2000 0x9C45       # c.mul x8, x9
    Execute Command              cpu Step
    ${reg_value}=                Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Integers  ${reg_value}  0x0000000F        # Should be 3 * 5 = 15

Zcb Extension Gating Test
    Create Machine Without Extensions
    
    # Setup trap handler - infinite loop at trap vector
    Execute Command              cpu MTVEC 0x3000
    Execute Command              sysbus WriteDoubleWord 0x3000 0x0000006f   # j . (infinite loop)
    
    # Test c.lbu - should trap when Zcb disabled
    Execute Command              cpu PC 0x2000
    Execute Command              sysbus WriteWord 0x2000 0x8000       # c.lbu x8, 0(x8)
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x8000
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2000
    
    # Test c.lhu - should trap when Zcb disabled
    Execute Command              cpu PC 0x2004
    Execute Command              sysbus WriteWord 0x2004 0x8400       # c.lhu x8, 0(x8)
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x8400
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2004
    
    # Test c.lh - should trap when Zcb disabled
    Execute Command              cpu PC 0x2008
    Execute Command              sysbus WriteWord 0x2008 0x8440       # c.lh x8, 0(x8)
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x8440
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2008
    
    # Test c.sb - should trap when Zcb disabled
    Execute Command              cpu PC 0x200C
    Execute Command              sysbus WriteWord 0x200C 0x8804       # c.sb x9, 0(x8)
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x8804
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x200C
    
    # Test c.sh - should trap when Zcb disabled
    Execute Command              cpu PC 0x2010
    Execute Command              sysbus WriteWord 0x2010 0x8C04       # c.sh x9, 0(x8)
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x8C04
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2010
    
    # Test c.zext.b - should trap when Zcb disabled
    Execute Command              cpu PC 0x2014
    Execute Command              sysbus WriteWord 0x2014 0x9C61       # c.zext.b x8
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x9C61
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2014
    
    # Test c.sext.b - should trap when Zcb disabled
    Execute Command              cpu PC 0x2018
    Execute Command              sysbus WriteWord 0x2018 0x9C65       # c.sext.b x8
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x9C65
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2018
    
    # Test c.zext.h - should trap when Zcb disabled
    Execute Command              cpu PC 0x201C
    Execute Command              sysbus WriteWord 0x201C 0x9C69       # c.zext.h x8
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x9C69
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x201C
    
    # Test c.sext.h - should trap when Zcb disabled
    Execute Command              cpu PC 0x2020
    Execute Command              sysbus WriteWord 0x2020 0x9C6D       # c.sext.h x8
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x9C6D
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2020
    
    # Test c.not - should trap when Zcb disabled
    Execute Command              cpu PC 0x2024
    Execute Command              sysbus WriteWord 0x2024 0x9C75       # c.not x8
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x9C75
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2024
    
    # Test c.mul - should trap when Zcb disabled
    Execute Command              cpu PC 0x2028
    Execute Command              sysbus WriteWord 0x2028 0x9C45       # c.mul x8, x9
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0x9C45
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2028

Zcmp PUSH Instruction Test
    Create Machine With Extensions

    # Test all valid rlist values: 4-15
    # For each rlist, we use spimm=0 for simplicity
    
    # Set up initial register values - all saved registers (ra, s0-s11)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000    # sp = 0x8000
    Execute Command                  sysbus.cpu SetRegisterUnsafe 1 0x12345678    # ra (x1)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 8 0x11111111    # s0 (x8)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 9 0x22222222    # s1 (x9)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 18 0x33333333   # s2 (x18)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 19 0x44444444   # s3 (x19)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 20 0x55555555   # s4 (x20)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 21 0x66666666   # s5 (x21)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 22 0x77777777   # s6 (x22)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 23 0x88888888   # s7 (x23)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 24 0x99999999   # s8 (x24)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 25 0xAAAAAAAA   # s9 (x25)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 26 0xBBBBBBBB   # s10 (x26)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 27 0xCCCCCCCC   # s11 (x27)

    # Test rlist=4: cm.push {ra}, -16
    # Binary: 101 11000 0100 00 10 = 0xB842
    Execute Command                  sysbus WriteWord 0x2000 0xB842
    Execute Command                  sysbus.cpu PC 0x2000
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FF0    # 0x8000 - 16
    ${stored_ra}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_ra}                0x12345678
    
    # Test rlist=5: cm.push {ra, s0}, -16
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000    # Reset sp
    # Binary: 101 11000 0101 00 10 = 0xB852
    Execute Command                  sysbus WriteWord 0x2004 0xB852
    Execute Command                  sysbus.cpu PC 0x2004
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FF0    # 0x8000 - 16
    ${stored_s0}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s0}                0x11111111
    ${stored_ra}=                   Execute Command             sysbus ReadDoubleWord 0x7FF8
    Should Be Equal As Numbers      ${stored_ra}                0x12345678
    
    # Test rlist=6: cm.push {ra, s0-s1}, -16
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 0110 00 10 = 0xB862
    Execute Command                  sysbus WriteWord 0x2008 0xB862
    Execute Command                  sysbus.cpu PC 0x2008
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FF0    # 0x8000 - 16
    ${stored_s1}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s1}                0x22222222
    ${stored_s0}=                   Execute Command             sysbus ReadDoubleWord 0x7FF8
    Should Be Equal As Numbers      ${stored_s0}                0x11111111
    ${stored_ra}=                   Execute Command             sysbus ReadDoubleWord 0x7FF4
    Should Be Equal As Numbers      ${stored_ra}                0x12345678
    
    # Test rlist=7: cm.push {ra, s0-s2}, -16
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 0111 00 10 = 0xB872
    Execute Command                  sysbus WriteWord 0x200C 0xB872
    Execute Command                  sysbus.cpu PC 0x200C
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FF0    # 0x8000 - 16
    ${stored_s2}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s2}                0x33333333
    
    # Test rlist=8: cm.push {ra, s0-s3}, -32
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 1000 00 10 = 0xB882
    Execute Command                  sysbus WriteWord 0x2010 0xB882
    Execute Command                  sysbus.cpu PC 0x2010
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FE0    # 0x8000 - 32
    ${stored_s3}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s3}                0x44444444
    
    # Test rlist=9: cm.push {ra, s0-s4}, -32
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 1001 00 10 = 0xB892
    Execute Command                  sysbus WriteWord 0x2014 0xB892
    Execute Command                  sysbus.cpu PC 0x2014
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FE0    # 0x8000 - 32
    ${stored_s4}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s4}                0x55555555
    
    # Test rlist=10: cm.push {ra, s0-s5}, -32
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 1010 00 10 = 0xB8A2
    Execute Command                  sysbus WriteWord 0x2018 0xB8A2
    Execute Command                  sysbus.cpu PC 0x2018
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FE0    # 0x8000 - 32
    ${stored_s5}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s5}                0x66666666
    
    # Test rlist=11: cm.push {ra, s0-s6}, -32
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 1011 00 10 = 0xB8B2
    Execute Command                  sysbus WriteWord 0x201C 0xB8B2
    Execute Command                  sysbus.cpu PC 0x201C
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FE0    # 0x8000 - 32
    ${stored_s6}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s6}                0x77777777
    
    # Test rlist=12: cm.push {ra, s0-s7}, -48
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 1100 00 10 = 0xB8C2
    Execute Command                  sysbus WriteWord 0x2020 0xB8C2
    Execute Command                  sysbus.cpu PC 0x2020
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FD0    # 0x8000 - 48
    ${stored_s7}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s7}                0x88888888
    
    # Test rlist=13: cm.push {ra, s0-s8}, -48
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 1101 00 10 = 0xB8D2
    Execute Command                  sysbus WriteWord 0x2024 0xB8D2
    Execute Command                  sysbus.cpu PC 0x2024
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FD0    # 0x8000 - 48
    ${stored_s8}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s8}                0x99999999
    
    # Test rlist=14: cm.push {ra, s0-s9}, -48
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 1110 00 10 = 0xB8E2
    Execute Command                  sysbus WriteWord 0x2028 0xB8E2
    Execute Command                  sysbus.cpu PC 0x2028
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FD0    # 0x8000 - 48
    ${stored_s9}=                   Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s9}                0xAAAAAAAA
    
    # Test rlist=15: cm.push {ra, s0-s11}, -64
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x8000
    # Binary: 101 11000 1111 00 10 = 0xB8F2
    Execute Command                  sysbus WriteWord 0x202C 0xB8F2
    Execute Command                  sysbus.cpu PC 0x202C
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7FC0    # 0x8000 - 64
    ${stored_s11}=                  Execute Command             sysbus ReadDoubleWord 0x7FFC
    Should Be Equal As Numbers      ${stored_s11}               0xCCCCCCCC
    ${stored_s10}=                  Execute Command             sysbus ReadDoubleWord 0x7FF8
    Should Be Equal As Numbers      ${stored_s10}               0xBBBBBBBB

Zcmp POP Instruction Test
    Create Machine With Extensions
    
    # Test all valid rlist values: 4-15
    # For each rlist, we use spimm=0 for simplicity
    # POP loads from addresses: sp + stack_adj - reg_size, working backwards
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000    # Set sp within valid RAM range
    
    # Test rlist=4: cm.pop {ra}, +16
    # Loads from: 0x6000+16-4=0x600C
    Execute Command                  sysbus WriteDoubleWord 0x600C 0x12345678    # ra
    # Binary: 101 11010 0100 00 10 = 0xBA42
    Execute Command                  sysbus WriteWord 0x3000 0xBA42
    Execute Command                  sysbus.cpu PC 0x3000
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6010
    ${ra}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers      ${ra}                       0x12345678
    
    # Test rlist=5: cm.pop {ra, s0}, +16
    # Loads from: s0@0x600C, ra@0x6008
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x600C 0x11111111    # s0
    Execute Command                  sysbus WriteDoubleWord 0x6008 0x12340001    # ra
    # Binary: 101 11010 0101 00 10 = 0xBA52
    Execute Command                  sysbus WriteWord 0x3004 0xBA52
    Execute Command                  sysbus.cpu PC 0x3004
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6010
    ${s0}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 8
    Should Be Equal As Numbers      ${s0}                       0x11111111
    
    # Test rlist=6: cm.pop {ra, s0-s1}, +16
    # Loads from: s1@0x600C, s0@0x6008, ra@0x6004
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x600C 0x22222222    # s1
    Execute Command                  sysbus WriteDoubleWord 0x6008 0x11110001    # s0
    Execute Command                  sysbus WriteDoubleWord 0x6004 0x12340002    # ra
    # Binary: 101 11010 0110 00 10 = 0xBA62
    Execute Command                  sysbus WriteWord 0x3008 0xBA62
    Execute Command                  sysbus.cpu PC 0x3008
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6010
    ${s1}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 9
    Should Be Equal As Numbers      ${s1}                       0x22222222
    
    # Test rlist=7: cm.pop {ra, s0-s2}, +16
    # Loads from: s2@0x600C, s1@0x6008, s0@0x6004, ra@0x6000
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x600C 0x33333333    # s2
    # Binary: 101 11010 0111 00 10 = 0xBA72
    Execute Command                  sysbus WriteWord 0x300C 0xBA72
    Execute Command                  sysbus.cpu PC 0x300C
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6010
    ${s2}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 18
    Should Be Equal As Numbers      ${s2}                       0x33333333
    
    # Test rlist=8: cm.pop {ra, s0-s3}, +32
    # Loads from: s3@0x601C (sp+32-4)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x601C 0x44444444    # s3
    # Binary: 101 11010 1000 00 10 = 0xBA82
    Execute Command                  sysbus WriteWord 0x3010 0xBA82
    Execute Command                  sysbus.cpu PC 0x3010
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6020
    ${s3}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 19
    Should Be Equal As Numbers      ${s3}                       0x44444444
    
    # Test rlist=9: cm.pop {ra, s0-s4}, +32
    # Loads from: s4@0x601C
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x601C 0x55555555    # s4
    # Binary: 101 11010 1001 00 10 = 0xBA92
    Execute Command                  sysbus WriteWord 0x3014 0xBA92
    Execute Command                  sysbus.cpu PC 0x3014
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6020
    ${s4}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 20
    Should Be Equal As Numbers      ${s4}                       0x55555555
    
    # Test rlist=10: cm.pop {ra, s0-s5}, +32
    # Loads from: s5@0x601C
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x601C 0x66666666    # s5
    # Binary: 101 11010 1010 00 10 = 0xBAA2
    Execute Command                  sysbus WriteWord 0x3018 0xBAA2
    Execute Command                  sysbus.cpu PC 0x3018
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6020
    ${s5}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 21
    Should Be Equal As Numbers      ${s5}                       0x66666666
    
    # Test rlist=11: cm.pop {ra, s0-s6}, +32
    # Loads from: s6@0x601C
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x601C 0x77777777    # s6
    # Binary: 101 11010 1011 00 10 = 0xBAB2
    Execute Command                  sysbus WriteWord 0x301C 0xBAB2
    Execute Command                  sysbus.cpu PC 0x301C
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6020
    ${s6}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 22
    Should Be Equal As Numbers      ${s6}                       0x77777777
    
    # Test rlist=12: cm.pop {ra, s0-s7}, +48
    # Loads from: s7@0x602C (sp+48-4)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x602C 0x88888888    # s7
    # Binary: 101 11010 1100 00 10 = 0xBAC2
    Execute Command                  sysbus WriteWord 0x3020 0xBAC2
    Execute Command                  sysbus.cpu PC 0x3020
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6030
    ${s7}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 23
    Should Be Equal As Numbers      ${s7}                       0x88888888
    
    # Test rlist=13: cm.pop {ra, s0-s8}, +48
    # Loads from: s8@0x602C
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x602C 0x99999999    # s8
    # Binary: 101 11010 1101 00 10 = 0xBAD2
    Execute Command                  sysbus WriteWord 0x3024 0xBAD2
    Execute Command                  sysbus.cpu PC 0x3024
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6030
    ${s8}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 24
    Should Be Equal As Numbers      ${s8}                       0x99999999
    
    # Test rlist=14: cm.pop {ra, s0-s9}, +48
    # Loads from: s9@0x602C
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x602C 0xAAAAAAAA    # s9
    # Binary: 101 11010 1110 00 10 = 0xBAE2
    Execute Command                  sysbus WriteWord 0x3028 0xBAE2
    Execute Command                  sysbus.cpu PC 0x3028
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6030
    ${s9}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 25
    Should Be Equal As Numbers      ${s9}                       0xAAAAAAAA
    
    # Test rlist=15: cm.pop {ra, s0-s11}, +64
    # Loads from: s11@0x603C (sp+64-4), s10@0x6038
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x6000
    Execute Command                  sysbus WriteDoubleWord 0x603C 0xCCCCCCCC    # s11
    Execute Command                  sysbus WriteDoubleWord 0x6038 0xBBBBBBBB    # s10
    # Binary: 101 11010 1111 00 10 = 0xBAF2
    Execute Command                  sysbus WriteWord 0x302C 0xBAF2
    Execute Command                  sysbus.cpu PC 0x302C
    Execute Command                  sysbus.cpu Step
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x6040
    ${s11}=                         Execute Command             sysbus.cpu GetRegisterUnsafe 27
    Should Be Equal As Numbers      ${s11}                      0xCCCCCCCC
    ${s10}=                         Execute Command             sysbus.cpu GetRegisterUnsafe 26
    Should Be Equal As Numbers      ${s10}                      0xBBBBBBBB

Zcmp POPRET Instruction Test
    Create Machine With Extensions
    
    # Test C.POPRET instruction (cm.popret) - combines pop and return
    # Set up stack with data in same layout that PUSH would create (at top of allocated space)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x7000    # Set sp within valid RAM range
    
    # For cm.popret {ra}, +16: ra at sp+16-4=0x700C
    Execute Command                  sysbus WriteDoubleWord 0x700C 0x8000      # ra = return address 0x8000
    Execute Command                  sysbus WriteDoubleWord 0x8000 0x0000006f  # Write "j ." at return address (infinite loop for test)
    
    # For cm.popret {ra, s0}, +32: ra at 0x7018, s0 at 0x701C
    Execute Command                  sysbus WriteDoubleWord 0x7018 0x8000      # ra for second test
    Execute Command                  sysbus WriteDoubleWord 0x701C 0xABCD1234  # s0 value
    
    # For cm.popret {ra, s0-s1}, +48: ra at 0x7024, s0 at 0x7028, s1 at 0x702C
    Execute Command                  sysbus WriteDoubleWord 0x7024 0x8000      # ra for third test
    Execute Command                  sysbus WriteDoubleWord 0x7028 0xABCD1234  # s0 value
    Execute Command                  sysbus WriteDoubleWord 0x702C 0x56789ABC  # s1 value
    
    # Clear registers before testing popret
    Execute Command                  sysbus.cpu SetRegisterUnsafe 1 0x00000000    # Clear ra
    Execute Command                  sysbus.cpu SetRegisterUnsafe 8 0x00000000    # Clear s0
    Execute Command                  sysbus.cpu SetRegisterUnsafe 9 0x00000000    # Clear s1
    
    # Test cm.popret {ra}, +16 (rlist=4, spimm=0)
    # Encoding: [15:13]=101, [12:8]=11110, [7:4]=0100, [3:2]=00, [1:0]=10  
    # Binary: 101 11110 0100 00 10 = 0xBE42
    Execute Command                  sysbus WriteWord 0x3000 0xBE42
    Execute Command                  sysbus.cpu PC 0x3000
    Execute Command                  sysbus.cpu Step
    
    # Verify stack pointer increased by 16
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7010    # 0x7000 + 16
    
    # Verify ra was loaded  
    ${ra}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers      ${ra}                       0x8000
    
    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command             sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}                       0x8000    # Should have jumped to ra
    
    # Test cm.popret {ra, s0}, +32 (rlist=5, spimm=1)
    # Reset for next test
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x7000    # Reset sp
    Execute Command                  sysbus.cpu SetRegisterUnsafe 1 0x00000000    # Clear ra
    Execute Command                  sysbus.cpu SetRegisterUnsafe 8 0x00000000    # Clear s0
    
    # Encoding: [15:13]=101, [12:8]=11110, [7:4]=0101, [3:2]=01, [1:0]=10  
    # Binary: 101 11110 0101 01 10 = 0xBE56
    Execute Command                  sysbus WriteWord 0x3004 0xBE56
    Execute Command                  sysbus.cpu PC 0x3004
    Execute Command                  sysbus.cpu Step
    
    # Verify stack pointer increased by 32 (16 base + 16 extra)
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7020    # 0x7000 + 32
    
    # Verify ra was loaded
    ${ra}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers      ${ra}                       0x8000
    
    # Verify s0 was loaded
    ${s0}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 8  
    Should Be Equal As Numbers      ${s0}                       0xABCD1234
    
    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command             sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}                       0x8000    # Should have jumped to ra
    
    # Test cm.popret {ra, s0-s1}, +48 (rlist=6, spimm=2)
    # Reset for final test
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x7000    # Reset sp
    Execute Command                  sysbus.cpu SetRegisterUnsafe 1 0x00000000    # Clear ra
    Execute Command                  sysbus.cpu SetRegisterUnsafe 8 0x00000000    # Clear s0
    Execute Command                  sysbus.cpu SetRegisterUnsafe 9 0x00000000    # Clear s1
    
    # Encoding: [15:13]=101, [12:8]=11110, [7:4]=0110, [3:2]=10, [1:0]=10
    # Binary: 101 11110 0110 10 10 = 0xBE6A
    Execute Command                  sysbus WriteWord 0x3008 0xBE6A
    Execute Command                  sysbus.cpu PC 0x3008
    Execute Command                  sysbus.cpu Step
    
    # Verify stack pointer increased by 48 (16 base + 32 extra)
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7030    # 0x7000 + 48
    
    # Verify all registers were loaded correctly
    ${ra}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers      ${ra}                       0x8000
    ${s0}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 8
    Should Be Equal As Numbers      ${s0}                       0xABCD1234
    ${s1}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 9
    Should Be Equal As Numbers      ${s1}                       0x56789ABC
    
    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command             sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}                       0x8000    # Should have jumped to ra

Zcmp POPRETZ Instruction Test
    Create Machine With Extensions
    
    # Test C.POPRETZ instruction (cm.popretz) - combines pop, set a0=0, and return
    # Set up stack with data in same layout that PUSH would create (at top of allocated space)
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x7000    # Set sp within valid RAM range
    
    # For cm.popretz {ra}, +16: ra at sp+16-4=0x700C
    Execute Command                  sysbus WriteDoubleWord 0x700C 0x8000      # ra = return address 0x8000
    Execute Command                  sysbus WriteDoubleWord 0x8000 0x0000006f  # Write "j ." at return address (infinite loop for test)
    
    # For cm.popretz {ra, s0}, +32: ra at 0x7018, s0 at 0x701C
    Execute Command                  sysbus WriteDoubleWord 0x7018 0x8000      # ra for second test
    Execute Command                  sysbus WriteDoubleWord 0x701C 0x11223344  # s0 value
    
    # For cm.popretz {ra, s0-s1}, +48: ra at 0x7024, s0 at 0x7028, s1 at 0x702C
    Execute Command                  sysbus WriteDoubleWord 0x7024 0x8000      # ra for third test
    Execute Command                  sysbus WriteDoubleWord 0x7028 0x11223344  # s0 value
    Execute Command                  sysbus WriteDoubleWord 0x702C 0x55667788  # s1 value
    
    # Clear registers before testing popretz
    Execute Command                  sysbus.cpu SetRegisterUnsafe 1 0x00000000    # Clear ra
    Execute Command                  sysbus.cpu SetRegisterUnsafe 8 0x00000000    # Clear s0
    Execute Command                  sysbus.cpu SetRegisterUnsafe 9 0x00000000    # Clear s1
    Execute Command                  sysbus.cpu SetRegisterUnsafe 10 0xFFFFFFFF   # Set a0 to non-zero value
    
    # Test cm.popretz {ra}, +16 (rlist=4, spimm=0)
    # Encoding: [15:13]=101, [12:8]=11100, [7:4]=0100, [3:2]=00, [1:0]=10  
    # Binary: 101 11100 0100 00 10 = 0xBC42
    Execute Command                  sysbus WriteWord 0x3000 0xBC42
    Execute Command                  sysbus.cpu PC 0x3000
    Execute Command                  sysbus.cpu Step
    
    # Verify stack pointer increased by 16
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7010    # 0x7000 + 16
    
    # Verify ra was loaded  
    ${ra}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers      ${ra}                       0x8000
    
    # Verify a0 was set to 0
    ${a0}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 10
    Should Be Equal As Numbers      ${a0}                       0x0    # Should be 0
    
    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command             sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}                       0x8000    # Should have jumped to ra
    
    # Test cm.popretz {ra, s0}, +32 (rlist=5, spimm=1)
    # Reset for next test
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x7000    # Reset sp
    Execute Command                  sysbus.cpu SetRegisterUnsafe 1 0x00000000    # Clear ra
    Execute Command                  sysbus.cpu SetRegisterUnsafe 8 0x00000000    # Clear s0
    Execute Command                  sysbus.cpu SetRegisterUnsafe 10 0x12345678   # Set a0 to non-zero value
    
    # Encoding: [15:13]=101, [12:8]=11100, [7:4]=0101, [3:2]=01, [1:0]=10  
    # Binary: 101 11100 0101 01 10 = 0xBC56
    Execute Command                  sysbus WriteWord 0x3004 0xBC56
    Execute Command                  sysbus.cpu PC 0x3004
    Execute Command                  sysbus.cpu Step
    
    # Verify stack pointer increased by 32 (16 base + 16 extra)
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7020    # 0x7000 + 32
    
    # Verify ra was loaded
    ${ra}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers      ${ra}                       0x8000
    
    # Verify s0 was loaded
    ${s0}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 8  
    Should Be Equal As Numbers      ${s0}                       0x11223344
    
    # Verify a0 was set to 0 (not the original non-zero value)
    ${a0}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 10
    Should Be Equal As Numbers      ${a0}                       0x0    # Should be 0, not 0x12345678
    
    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command             sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}                       0x8000    # Should have jumped to ra
    
    # Test cm.popretz {ra, s0-s1}, +48 (rlist=6, spimm=2)
    # Reset for final test
    Execute Command                  sysbus.cpu SetRegisterUnsafe 2 0x7000    # Reset sp
    Execute Command                  sysbus.cpu SetRegisterUnsafe 1 0x00000000    # Clear ra
    Execute Command                  sysbus.cpu SetRegisterUnsafe 8 0x00000000    # Clear s0
    Execute Command                  sysbus.cpu SetRegisterUnsafe 9 0x00000000    # Clear s1
    Execute Command                  sysbus.cpu SetRegisterUnsafe 10 0xAABBCCDD   # Set a0 to non-zero value
    
    # Encoding: [15:13]=101, [12:8]=11100, [7:4]=0110, [3:2]=10, [1:0]=10
    # Binary: 101 11100 0110 10 10 = 0xBC6A
    Execute Command                  sysbus WriteWord 0x3008 0xBC6A
    Execute Command                  sysbus.cpu PC 0x3008
    Execute Command                  sysbus.cpu Step
    
    # Verify stack pointer increased by 48 (16 base + 32 extra)
    ${sp}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 2
    Should Be Equal As Numbers      ${sp}                       0x7030    # 0x7000 + 48
    
    # Verify all registers were loaded correctly
    ${ra}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers      ${ra}                       0x8000
    ${s0}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 8
    Should Be Equal As Numbers      ${s0}                       0x11223344
    ${s1}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 9
    Should Be Equal As Numbers      ${s1}                       0x55667788
    
    # Verify a0 was set to 0 (critical test - this is what differentiates POPRETZ from POPRET)
    ${a0}=                          Execute Command             sysbus.cpu GetRegisterUnsafe 10
    Should Be Equal As Numbers      ${a0}                       0x0    # Should be 0, not 0xAABBCCDD
    
    # Verify PC jumped to return address (ra)
    ${pc}=                          Execute Command             sysbus.cpu PC
    Should Be Equal As Numbers      ${pc}                       0x8000    # Should have jumped to ra

Zcmp MVSA01 Instruction Test
    Create Machine With Extensions
    
    # Test C.MVSA01 instruction (cm.mvsa01) - move a0→r1s', a1→r2s'
    Execute Command              cpu PC 0x2000
    
    # Setup: Set a0 and a1 to known values
    Execute Command              cpu SetRegisterUnsafe 10 0x12345678    # a0 = test value 1
    Execute Command              cpu SetRegisterUnsafe 11 0x9ABCDEF0    # a1 = test value 2
    Execute Command              cpu SetRegisterUnsafe 8 0x00000000     # s0 = 0 (clear destination)
    Execute Command              cpu SetRegisterUnsafe 9 0x00000000     # s1 = 0 (clear destination)
    
    # Test 1: C.MVSA01 s0, s1 (move a0→s0, a1→s1)
    # Binary: 101 011 000 01 001 10 = 0xAC26 (funct6=101011, r1s'=000(s0), funct2=01, r2s'=001(s1))
    Execute Command              sysbus WriteWord 0x2000 0xAC26
    Execute Command              cpu Step
    
    # Verify: s0 should contain a0 value, s1 should contain a1 value
    ${s0_value}=                 Execute Command  cpu GetRegisterUnsafe 8
    Should Be Equal As Numbers   ${s0_value}  0x12345678     # s0 should equal original a0
    ${s1_value}=                 Execute Command  cpu GetRegisterUnsafe 9
    Should Be Equal As Numbers   ${s1_value}  0x9ABCDEF0     # s1 should equal original a1
    
    # Test 2: C.MVSA01 s2, s3 (move a0→s2, a1→s3)
    Execute Command              cpu PC 0x2004
    Execute Command              cpu SetRegisterUnsafe 10 0xDEADBEEF    # a0 = new test value
    Execute Command              cpu SetRegisterUnsafe 11 0xCAFEBABE    # a1 = new test value
    Execute Command              cpu SetRegisterUnsafe 18 0x00000000    # s2 = 0 (clear destination)
    Execute Command              cpu SetRegisterUnsafe 19 0x00000000    # s3 = 0 (clear destination)
    
    # Binary: 101 011 010 01 011 10 = 0xAD2E (funct6=101011, r1s'=010(s2), funct2=01, r2s'=011(s3))
    Execute Command              sysbus WriteWord 0x2004 0xAD2E
    Execute Command              cpu Step
    
    # Verify: s2 should contain a0 value, s3 should contain a1 value
    ${s2_value}=                 Execute Command  cpu GetRegisterUnsafe 18
    Should Be Equal As Numbers   ${s2_value}  0xDEADBEEF     # s2 should equal a0
    ${s3_value}=                 Execute Command  cpu GetRegisterUnsafe 19
    Should Be Equal As Numbers   ${s3_value}  0xCAFEBABE     # s3 should equal a1

Zcmp MVA01S Instruction Test
    Create Machine With Extensions
    
    # Test C.MVA01S instruction (cm.mva01s) - move r1s'→a0, r2s'→a1
    Execute Command              cpu PC 0x2000
    
    # Setup: Set s-registers to known values and clear a0/a1
    Execute Command              cpu SetRegisterUnsafe 8 0x11111111     # s0 = test value 1
    Execute Command              cpu SetRegisterUnsafe 9 0x22222222     # s1 = test value 2
    Execute Command              cpu SetRegisterUnsafe 10 0x00000000    # a0 = 0 (clear destination)
    Execute Command              cpu SetRegisterUnsafe 11 0x00000000    # a1 = 0 (clear destination)
    
    # Test 1: C.MVA01S s0, s1 (move s0→a0, s1→a1)
    # Binary: 101 011 000 11 001 10 = 0xAC66 (funct6=101011, r1s'=000(s0), funct2=11, r2s'=001(s1))
    Execute Command              sysbus WriteWord 0x2000 0xAC66
    Execute Command              cpu Step
    
    # Verify: a0 should contain s0 value, a1 should contain s1 value
    ${a0_value}=                 Execute Command  cpu GetRegisterUnsafe 10
    Should Be Equal As Numbers   ${a0_value}  0x11111111     # a0 should equal original s0
    ${a1_value}=                 Execute Command  cpu GetRegisterUnsafe 11
    Should Be Equal As Numbers   ${a1_value}  0x22222222     # a1 should equal original s1
    
    # Test 2: C.MVA01S s4, s5 (move s4→a0, s5→a1)
    Execute Command              cpu PC 0x2004
    Execute Command              cpu SetRegisterUnsafe 20 0x33333333    # s4 = new test value
    Execute Command              cpu SetRegisterUnsafe 21 0x44444444    # s5 = new test value
    Execute Command              cpu SetRegisterUnsafe 10 0x00000000    # a0 = 0 (clear destination)
    Execute Command              cpu SetRegisterUnsafe 11 0x00000000    # a1 = 0 (clear destination)
    
    # Binary: 101 011 100 11 101 10 = 0xAE76 (funct6=101011, r1s'=100(s4), funct2=11, r2s'=101(s5))
    Execute Command              sysbus WriteWord 0x2004 0xAE76
    Execute Command              cpu Step
    
    # Verify: a0 should contain s4 value, a1 should contain s5 value
    ${a0_value}=                 Execute Command  cpu GetRegisterUnsafe 10
    Should Be Equal As Numbers   ${a0_value}  0x33333333     # a0 should equal s4
    ${a1_value}=                 Execute Command  cpu GetRegisterUnsafe 11
    Should Be Equal As Numbers   ${a1_value}  0x44444444     # a1 should equal s5

Zcmp Extension Gating Test
    Create Machine Without Extensions
    
    # Setup trap handler - infinite loop at trap vector
    Execute Command              cpu MTVEC 0x3000
    Execute Command              sysbus WriteDoubleWord 0x3000 0x0000006f   # j . (infinite loop)
    
    # Test that Zcmp push instructions cause illegal instruction trap when extension is disabled
    Execute Command              cpu PC 0x2000
    Execute Command              sysbus WriteWord 0x2000 0xB842       # cm.push {ra}, -16 - should trap
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000               # Should jump to trap vector
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2                # Illegal instruction cause
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0xB842            # Should contain faulting opcode
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2000             # Should point to faulting instruction
    
    # Test that Zcmp pop instructions cause illegal instruction trap when extension is disabled
    Execute Command              cpu PC 0x2004
    Execute Command              sysbus WriteWord 0x2004 0xB942       # cm.pop {ra}, +16 - should trap
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000               # Should jump to trap vector
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2                # Illegal instruction cause
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0xB942            # Should contain faulting opcode
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2004             # Should point to faulting instruction
    
    # Test that Zcmp popret instructions cause illegal instruction trap when extension is disabled
    Execute Command              cpu PC 0x2008
    Execute Command              sysbus WriteWord 0x2008 0xBA42       # cm.popret {ra}, +16 - should trap
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000               # Should jump to trap vector
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2                # Illegal instruction cause
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0xBA42            # Should contain faulting opcode
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2008             # Should point to faulting instruction
    
    # Test that Zcmp popretz instructions cause illegal instruction trap when extension is disabled
    Execute Command              cpu PC 0x200C
    Execute Command              sysbus WriteWord 0x200C 0xBB42       # cm.popretz {ra}, +16 - should trap
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000               # Should jump to trap vector
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2                # Illegal instruction cause
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0xBB42            # Should contain faulting opcode
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x200C             # Should point to faulting instruction
    
    # Test that C.MVSA01 instructions cause illegal instruction trap when extension is disabled
    Execute Command              cpu PC 0x2010
    Execute Command              sysbus WriteWord 0x2010 0xAC26       # cm.mvsa01 s0, s1 - should trap
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000               # Should jump to trap vector
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2                # Illegal instruction cause
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0xAC26            # Should contain faulting opcode
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2010             # Should point to faulting instruction
    
    # Test that C.MVA01S instructions cause illegal instruction trap when extension is disabled
    Execute Command              cpu PC 0x2014
    Execute Command              sysbus WriteWord 0x2014 0xAC66       # cm.mva01s s0, s1 - should trap
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000               # Should jump to trap vector
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2                # Illegal instruction cause
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0xAC66            # Should contain faulting opcode
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2014             # Should point to faulting instruction

Zcmt JT Instruction Test
    Create Machine With Extensions
    
    # Test C.JT instruction (cm.jt) - table-based jump via JVT CSR
    # Set up Jump Vector Table (JVT) at known memory location
    Execute Command              cpu JVT 0x4000    # Set JVT CSR to table base address 0x4000
    
    # Initialize jump table entries (4-byte entries for RV32)
    Execute Command              sysbus WriteDoubleWord 0x4000 0x5000   # Table[0] -> 0x5000
    Execute Command              sysbus WriteDoubleWord 0x4004 0x5100   # Table[1] -> 0x5100  
    Execute Command              sysbus WriteDoubleWord 0x4008 0x5200   # Table[2] -> 0x5200
    Execute Command              sysbus WriteDoubleWord 0x407C 0x5300   # Table[31] -> 0x5300
        
    # Test 1: C.JT with index 0
    # CMJT format: [15:13]=101 [12:10]=000 [9:2]=00000000 (index < 32), [1:0]=10
    # Binary: 101 000 00000000 10 = 0xA002
    Execute Command              cpu PC 0x3000
    Execute Command              sysbus WriteWord 0x3000 0xA002
    Execute Command              cpu Step
    
    # Verify PC jumped to table[0] target (0x5000)
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x5000               # Should jump to table[0]
    
    # Test 2: C.JT with index 1 (bits [9:2] = 00000001)
    # Binary: 101 000 00000001 10 = 0xA006
    Execute Command              cpu PC 0x3004
    Execute Command              sysbus WriteWord 0x3004 0xA006  
    Execute Command              cpu Step
    
    # Verify PC jumped to table[1] target (0x5100)
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x5100               # Should jump to table[1]
    
    # Test 3: C.JT with index 2 (bits [9:2] = 00000010) 
    # Binary: 101 000 00000010 10 = 0xA00A
    Execute Command              cpu PC 0x3008
    Execute Command              sysbus WriteWord 0x3008 0xA00A
    Execute Command              cpu Step
    
    # Verify PC jumped to table[2] target (0x5200)
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x5200               # Should jump to table[2]
    
    # Test 4: C.JT with index 31 (bits [9:2] = 00011111)
    # Binary: 101 000 00011111 10 = 0xA07E
    Execute Command              cpu PC 0x300C
    Execute Command              sysbus WriteWord 0x300C 0xA07E
    Execute Command              cpu Step
    
    # Verify PC jumped to table[31] target (0x5300)
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x5300               # Should jump to table[31]

Zcmt JALT Instruction Test
    Create Machine With Extensions
    
    # Setup JVT CSR to point to jump table at 0x4000
    Execute Command              cpu JVT 0x4000
    
    # Setup jump table in memory
    # table[32] = 0x5000, table[33] = 0x5100, table[34] = 0x5200, table[63] = 0x5300
    Execute Command              sysbus WriteDoubleWord 0x4080 0x00005000    # table[32]
    Execute Command              sysbus WriteDoubleWord 0x4084 0x00005100    # table[33]
    Execute Command              sysbus WriteDoubleWord 0x4088 0x00005200    # table[34]
    Execute Command              sysbus WriteDoubleWord 0x40FC 0x00005300    # table[63]
        
    # Test 1: C.JALT with index 32 (bits [9:2] = 00100000)
    # Encoding: [15:13]=101, [12:10]=000, [9:2]=00100000, [1:0]=10
    # Binary: 101 000 00100000 10 = 0xA082
    Execute Command              cpu PC 0x3000
    Execute Command              cpu SetRegisterUnsafe 1 0x0             # Clear ra before test
    Execute Command              sysbus WriteWord 0x3000 0xA082  
    Execute Command              cpu Step
    
    # Verify PC jumped to table[32] target (0x5000)
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x5000               # Should jump to table[32]
    
    # Verify ra was set to return address (PC + 2)
    ${ra}=                       Execute Command  cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers   ${ra}  0x3002               # Should be 0x3000 + 2
    
    # Test 2: C.JALT with index 33 (bits [9:2] = 00100001)
    # Binary: 101 000 00100001 10 = 0xA086
    Execute Command              cpu PC 0x3004
    Execute Command              cpu SetRegisterUnsafe 1 0x0             # Clear ra before test
    Execute Command              sysbus WriteWord 0x3004 0xA086  
    Execute Command              cpu Step
    
    # Verify PC jumped to table[33] target (0x5100)
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x5100               # Should jump to table[33]
    
    # Verify ra was set to return address (PC + 2)
    ${ra}=                       Execute Command  cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers   ${ra}  0x3006               # Should be 0x3004 + 2
    
    # Test 3: C.JALT with index 34 (bits [9:2] = 00100010) 
    # Binary: 101 000 00100010 10 = 0xA08A
    Execute Command              cpu PC 0x3008
    Execute Command              cpu SetRegisterUnsafe 1 0x0             # Clear ra before test
    Execute Command              sysbus WriteWord 0x3008 0xA08A
    Execute Command              cpu Step
    
    # Verify PC jumped to table[34] target (0x5200)
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x5200               # Should jump to table[34]
    
    # Verify ra was set to return address (PC + 2)
    ${ra}=                       Execute Command  cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers   ${ra}  0x300A               # Should be 0x3008 + 2
    
    # Test 4: C.JALT with index 63 (bits [9:2] = 00111111)
    # Binary: 101 000 00111111 10 = 0xA0FE
    Execute Command              cpu PC 0x300C
    Execute Command              cpu SetRegisterUnsafe 1 0x0             # Clear ra before test
    Execute Command              sysbus WriteWord 0x300C 0xA0FE
    Execute Command              cpu Step
    
    # Verify PC jumped to table[63] target (0x5300)
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x5300               # Should jump to table[63]
    
    # Verify ra was set to return address (PC + 2)
    ${ra}=                       Execute Command  cpu GetRegisterUnsafe 1
    Should Be Equal As Numbers   ${ra}  0x300E               # Should be 0x300C + 2
    

Zcmt Extension Gating Test
    Create Machine Without Extensions
    
    # Setup trap handler - infinite loop at trap vector
    Execute Command              cpu MTVEC 0x3000
    Execute Command              sysbus WriteDoubleWord 0x3000 0x0000006f   # j . (infinite loop)
    
    # Test that C.JT instructions cause illegal instruction trap when extension is disabled
    Execute Command              cpu PC 0x2000
    Execute Command              sysbus WriteWord 0x2000 0xA002       # cm.jt 0 - should trap
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000               # Should jump to trap vector
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2                # Illegal instruction cause
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0xA002            # Should contain faulting opcode
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2000             # Should point to faulting instruction
    
    # Test that C.JALT instructions cause illegal instruction trap when extension is disabled
    Execute Command              cpu PC 0x2004
    Execute Command              sysbus WriteWord 0x2004 0xA082       # cm.jalt 32 - should trap
    Execute Command              cpu Step
    ${pc}=                       Execute Command  cpu PC
    Should Be Equal As Numbers   ${pc}  0x3000               # Should jump to trap vector
    ${mcause}=                   Execute Command  cpu MCAUSE
    Should Be Equal As Numbers   ${mcause}  2                # Illegal instruction cause
    ${mtval}=                    Execute Command  cpu MTVAL
    Should Be Equal As Numbers   ${mtval}  0xA082            # Should contain faulting opcode
    ${mepc}=                     Execute Command  cpu MEPC
    Should Be Equal As Numbers   ${mepc}  0x2004             # Should point to faulting instruction