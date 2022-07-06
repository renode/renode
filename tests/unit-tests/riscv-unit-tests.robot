*** Variables ***
# RISC-V registers
${a1}                         0xb
${starting_pc}                0x2000
${next_instruction}           0x2004
${mtvec}                      0x1010
${illegal_instruction}        0x2
${load_misaligned}            0x4
${store_misaligned}           0x6
${register_0}                 0x0
${illegal_opcode}             0x00008000
${illegal_csr}                0xf120d073
${nonexisting_csr}            0xfff0d073


*** Keywords ***
Create Machine 32
    Execute Command           using sysbus
    Execute Command           mach create "risc-v"

    Execute Command           machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { timeProvider: clint; cpuType: \\"rv32gc\\" }"
    Execute Command           machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }"

    Execute Command           cpu PC ${starting_pc}

Create Machine 64
    Execute Command           using sysbus
    Execute Command           mach create "risc-v"

    Execute Command           machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { timeProvider: clint; cpuType: \\"rv64gc\\" }"
    Execute Command           machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }"

    Execute Command           cpu PC ${starting_pc}


*** Test Cases ***
Should Handle LB
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # lb a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00558503

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Handle LH
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000001

    # lh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00559503

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LH
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # lh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00559503

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${load_misaligned}

Should Handle LW
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000003

    # lw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055a503

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LW
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # lw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055a503

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${load_misaligned}

Should Handle LD
    Create Machine 64

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000003

    # ld a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055b503

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LD
    Create Machine 64

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # ld a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055b503

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${load_misaligned}

Should Handle SB
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # sb a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a582a3

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Handle SH
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000001

    # sh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a592a3

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SH
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # sh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a592a3

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${store_misaligned}

Should Handle SW
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000003

    # sw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5a2a3

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SW
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # sw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5a2a3

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${store_misaligned}

Should Handle SD
    Create Machine 64

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000003

    # sd a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5b2a3

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SD
    Create Machine 64

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000001

    # sd a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5b2a3

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${store_misaligned}
    
Should Fail On Setting X0 register
    Create Machine 32

    ${msg}=     		    Run Keyword And Expect Error        *   Execute Command       cpu SetRegisterUnsafe ${register_0} 0x00000001
    Should Contain      	    ${msg}      register is read-only

    Register Should Be Equal        0  0x0

Should Set MEPC on Illegal Instruction
    Create Machine 32

    # j .
    Execute Command                 sysbus WriteDoubleWord 0x1010 0x0000006f

    # j 0x4000
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0000206f
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x4000 0x00000013
    # ILLEGAL INSTRUCTION
    Execute Command                 sysbus WriteDoubleWord 0x4004 ${illegal_opcode}

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step 3

    PC Should Be Equal              0x1010

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}  ${illegal_instruction}
    ${mtval}=                       Execute Command     cpu MTVAL
    Should Be Equal As Numbers      ${mtval}   ${illegal_opcode}
    ${mepc}=                        Execute Command     cpu MEPC
    Should Be Equal As Numbers      ${mepc}    0x4004

Should Set MEPC on Illegal CSR access
    Create Machine 32
    Execute Command   cpu CSRValidation Full

    # j .
    Execute Command                 sysbus WriteDoubleWord 0x1010 0x0000006f

    # j 0x4000
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0000206f
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x4000 0x00000013
    # csrwi marchid, 1 - this is an illegal CSR operation as `marchid` is read-only
    Execute Command                 sysbus WriteDoubleWord 0x4004 ${illegal_csr}

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step 3

    PC Should Be Equal              0x1010

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}  ${illegal_instruction}
    ${mtval}=                       Execute Command     cpu MTVAL
    Should Be Equal As Numbers      ${mtval}   ${illegal_csr}
    ${mepc}=                        Execute Command     cpu MEPC
    Should Be Equal As Numbers      ${mepc}    0x4004

Should Set MEPC on Non-Existing CSR access
    Create Machine 32

    # j .
    Execute Command                 sysbus WriteDoubleWord 0x1010 0x0000006f

    # j 0x4000
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0000206f
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x4000 0x00000013
    # csrwi marchid, 1 - this is an illegal CSR operation as `marchid` is read-only
    Execute Command                 sysbus WriteDoubleWord 0x4004 ${nonexisting_csr}

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step 3

    PC Should Be Equal              0x1010

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}  ${illegal_instruction}
    ${mtval}=                       Execute Command     cpu MTVAL
    Should Be Equal As Numbers      ${mtval}   ${nonexisting_csr}
    ${mepc}=                        Execute Command     cpu MEPC
    Should Be Equal As Numbers      ${mepc}    0x4004

Should Set MEPC on Wrong SRET
    Create Machine 32

    # j .
    Execute Command                 sysbus WriteDoubleWord 0x1010 0x0000006f

    # j 0x4000
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0000206f
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x4000 0x00000013
    # csrwi marchid, 1 - this is an illegal CSR operation as `marchid` is read-only
    Execute Command                 sysbus WriteDoubleWord 0x4004 0x10200073

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 s
    Execute Command                 cpu Step 3

    PC Should Be Equal              0x1010

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}  ${illegal_instruction}
    ${mtval}=                       Execute Command     cpu MTVAL
    Should Be Equal As Numbers      ${mtval}   0x10200073
    ${mepc}=                        Execute Command     cpu MEPC
    Should Be Equal As Numbers      ${mepc}    0x4004

