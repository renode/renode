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
Create Machine
    [Arguments]    ${bitness}    ${init_pc}
    Execute Command           using sysbus
    Execute Command           mach create "risc-v"

    Execute Command           machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV${bitness} @ sysbus { timeProvider: clint; cpuType: \\"rv${bitness}gc\\" }"
    Execute Command           machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }"

    IF    ${init_pc}
       Execute Command           cpu PC ${starting_pc}
    END

Create Machine 32
    Create Machine    bitness=32  init_pc=True

Create Machine 64
    Create Machine    bitness=64  init_pc=True

Write Opcode To
    [Arguments]                         ${adress}   ${opcode}
    Execute Command                     sysbus WriteDoubleWord ${adress} ${opcode}

Load Program With Invalid Instruction
    [Arguments]                         ${address}
    ${addi_opcode}                      Set Variable  0x00050593  #addi        x11 x10 0
    ${vector_opcode}                    Set Variable  0x00000057  #vadd.vv     v0, v0, v0, v0.t
    ${fvf_vector_opcode}                Set Variable  0x00005057  #vfadd.vf    v0, v0, ft0, v0.t
    ${start_pc}=                        Convert To Integer  ${address}

    # Depending on the fact if vector extension is enabled or not, the program will cause
    # invalid instruction exception at ${vector_opcode} or ${fvf_vector_opcode}.
    Write Opcode To  ${start_pc}     ${addi_opcode}            #addi x11 x10 0
    Write Opcode To  ${start_pc+4}   ${addi_opcode}            #addi x11 x10 0
    Write Opcode To  ${start_pc+8}   ${vector_opcode}          #vadd.vv v0, v0, v0, v0.t
    Write Opcode To  ${start_pc+12}  ${addi_opcode}            #addi x11 x10 0
    Write Opcode To  ${start_pc+16}  ${addi_opcode}            #addi x11 x10 0
    Write Opcode To  ${start_pc+20}  ${addi_opcode}            #addi x11 x10 0
    Write Opcode To  ${start_pc+24}  ${fvf_vector_opcode}      #vfadd.vf v0, v0, ft0, v0.t
    Write Opcode To  ${start_pc+28}  ${addi_opcode}            #addi x11 x10 0
    Write Opcode To  ${start_pc+32}  ${vector_opcode}          #vadd.vv v0, v0, v0, v0.t
    Write Opcode To  ${start_pc+36}  ${addi_opcode}            #addi x11 x10 0

Set ResetVector And Verify PC
    [Arguments]    ${reset_vector}    ${should_set_pc}
    IF    ${should_set_pc}
        ${expected_pc}=  Set Variable     ${reset_vector}
    ELSE
        ${expected_pc}=  Execute Command  cpu PC
    END
    Execute Command                cpu ResetVector ${reset_vector}
    Verify PC                      ${expected_pc}

Should Properly Handle ResetVector
    # Setting ResetVector before setting PC directly, with LoadELF etc. should propagate to PC.
    Set ResetVector And Verify PC   0x1234    should_set_pc=True
    Set ResetVector And Verify PC   0x1238    should_set_pc=True

    # Setting PC other than as an effect of ResetVector should stop the propagation.
    ${new_reset_vector_value}=  Set Variable  0x123C
    Execute Command                 cpu PC 0x5678
    Set ResetVector And Verify PC   ${new_reset_vector_value}    should_set_pc=False

    # Reset should set PC to ResetVector and restore PC propagation on ResetVector.
    Execute Command                 cpu Reset
    Verify PC                       ${new_reset_vector_value}
    Set ResetVector And Verify PC   0x1240    should_set_pc=True

Should Properly Handle ResetVector At Init And After Reset
    Verify PC                       0x1000  # Default ResetVector
    Should Properly Handle ResetVector

    ${new_reset_vector_value}=  Set Variable    0x2468
    Execute Command                 cpu ResetVector ${new_reset_vector_value}
    Execute Command                 cpu Reset
    Verify PC                       ${new_reset_vector_value}
    Should Properly Handle ResetVector

Verify PC
    [Arguments]    ${expected_pc}
    ${pc}=  Execute Command        cpu PC
    Should Be Equal As Integers    ${pc}    ${expected_pc}

*** Test Cases ***
Should Handle LB
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000000

    # lb a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00558503

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Handle LH
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000001

    # lh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00559503

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LH
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000000

    # lh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00559503

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${load_misaligned}

Should Handle LW
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000003

    # lw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055a503

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LW
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000000

    # lw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055a503

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${load_misaligned}

Should Handle LD
    Create Machine 64

    Execute Command                 cpu SetRegister ${a1} 0x00000003

    # ld a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055b503

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LD
    Create Machine 64

    Execute Command                 cpu SetRegister ${a1} 0x00000000

    # ld a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055b503

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${load_misaligned}

Should Handle SB
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000000

    # sb a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a582a3

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Handle SH
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000001

    # sh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a592a3

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SH
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000000

    # sh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a592a3

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${store_misaligned}

Should Handle SW
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000003

    # sw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5a2a3

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SW
    Create Machine 32

    Execute Command                 cpu SetRegister ${a1} 0x00000000

    # sw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5a2a3

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${store_misaligned}

Should Handle SD
    Create Machine 64

    Execute Command                 cpu SetRegister ${a1} 0x00000003

    # sd a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5b2a3

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SD
    Create Machine 64

    Execute Command                 cpu SetRegister ${a1} 0x00000001

    # sd a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5b2a3

    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${store_misaligned}
    
Should Fail On Setting X0 register
    Create Machine 32

    ${msg}=     		    Run Keyword And Expect Error        *   Execute Command       cpu SetRegister ${register_0} 0x00000001
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

    Execute Command                 cpu Step 3

    PC Should Be Equal              0x1010

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}  ${illegal_instruction}
    ${mtval}=                       Execute Command     cpu MTVAL
    Should Be Equal As Numbers      ${mtval}   ${nonexisting_csr}
    ${mepc}=                        Execute Command     cpu MEPC
    Should Be Equal As Numbers      ${mepc}    0x4004

Should Allow SRET In Machine Mode
    Create Machine 32

    Execute Command                 cpu SEPC 0x1234

    # j 0x4000
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0000206f
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x4000 0x00000013
    # sret
    Execute Command                 sysbus WriteDoubleWord 0x4004 0x10200073

    Execute Command                 cpu Step 3

    PC Should Be Equal              0x1234

Should Exit Translation Block After Invalid Instruction And Report Single Error
    Create Machine 32
    Load Program With Invalid Instruction               ${starting_pc}
    Create Log Tester               3

    ${start_pc}=                    Convert To Integer  ${starting_pc}
    ${illegal_opcode_1_pc}          Set Variable        ${start_pc+8}
    ${illegal_opcode_1_pc_hex}=     Convert To Hex      ${illegal_opcode_1_pc}

    ${illegal_opcode_2_pc}          Set Variable        ${start_pc+24}
    ${illegal_opcode_2_pc_hex}=     Convert To Hex      ${illegal_opcode_2_pc}

    ${illegal_opcode_3_pc}          Set Variable        ${start_pc+32}
    ${illegal_opcode_3_pc_hex}=     Convert To Hex      ${illegal_opcode_3_pc}

    # It doesn't use single stepping on purpose, as it would cause translation blocks of size 1.
    Execute Command                 cpu PerformanceInMips 1
    Execute Command                 emulation SetGlobalQuantum "0.000020"
    Execute Command                 emulation RunFor "0.000010"
    Wait For Log Entry              PC: 0x${illegal_opcode_1_pc_hex}.* instruction set is not enabled for this CPU!  treatAsRegex=True 
    Should Not Be In Log            PC: 0x${illegal_opcode_2_pc_hex}.* instruction set is not enabled for this CPU!  0  treatAsRegex=True
    Should Not Be In Log            PC: 0x${illegal_opcode_3_pc_hex}.* instruction set is not enabled for this CPU!  0  treatAsRegex=True

Should Properly Handle ResetVector After Creation And After Reset 32
    Create Machine                  bitness=32  init_pc=False
    Should Properly Handle ResetVector At Init And After Reset

Should Properly Handle ResetVector After Creation And After Reset 64
    Create Machine                  bitness=64  init_pc=False
    Should Properly Handle ResetVector At Init And After Reset
