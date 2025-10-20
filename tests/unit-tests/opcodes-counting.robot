*** Keywords ***
Create Machine
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imacbv_zicsr\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"

    Execute Command                             sysbus.cpu PC 0x0

*** Test Cases ***
Should Count Custom 16-bit Instruction
    Create Machine

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001110" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus.cpu EnableCustomOpcodesCounting

    Execute Command                             sysbus WriteWord 0x0 0xb38e

    Execute Command                             sysbus.cpu Step

    PC Should Be Equal                          0x2
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "1011001110001110"
    Should Be Equal As Numbers                  ${c}  1

Should Count Custom 32-bit Instruction
    Create Machine

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "10110011100011110000111110000011" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus.cpu EnableCustomOpcodesCounting

    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0f83

    Execute Command                             sysbus.cpu Step

    PC Should Be Equal                          0x4
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "10110011100011110000111110000011"
    Should Be Equal As Numbers                  ${c}  1

Should Count Custom 64-bit Instruction
    Create Machine

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111000011111000001010110011100011110000111110111111" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus.cpu EnableCustomOpcodesCounting

    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0fbf
    Execute Command                             sysbus WriteDoubleWord 0x4 0xb38f0f82

    Execute Command                             sysbus.cpu Step

    PC Should Be Equal                          0x8
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "1011001110001111000011111000001010110011100011110000111110111111"
    Should Be Equal As Numbers                  ${c}  1

Should Count Standard Opcode
    Create Machine

    Execute Command                             sysbus.cpu InstallOpcodeCounterPattern "nop" "0000000000010011" 
    Execute Command                             sysbus.cpu EnableOpcodesCounting true

    Execute Command                             sysbus WriteDoubleWord 0x0 0x13
    Execute Command                             sysbus WriteDoubleWord 0x4 0x13
    Execute Command                             sysbus WriteDoubleWord 0x8 0x13

    Execute Command                             sysbus.cpu Step 3

    PC Should Be Equal                          0xC
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "nop"
    Should Be Equal As Numbers                  ${c}  3

    Create Machine
    Create Log Tester                           1

Should Count RVV Opcode
    Create Machine

    Execute Command                             sysbus.cpu EnableVectorOpcodesCounting

    # vlm.v
    Execute Command                             sysbus WriteDoubleWord 0x0 0x02b00007

    Execute Command                             sysbus.cpu Step

    PC Should Be Equal                          0x4
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "vlm.v"
    Should Be Equal As Numbers                  ${c}  1

Should Parse All Embedded RISC-V Opcodes
    Create Machine

    ${names}=  Execute Command                  sysbus.cpu GetRiscvOpcodesEmbeddedResourceNames
    ${names}=  Remove String                    ${names}  [  ]  \n  ${SPACE}
    # remove the dangling `,` produced by the Monitor
    ${names}=  Evaluate                         '${names}'.rstrip(',')
    @{names}=  Split String                     ${names}  ,

    FOR  ${name}  IN  @{names}
        Execute Command                         sysbus.cpu EnableRiscvOpcodesCountingFromEmbeddedResource "${name}"
    END

    ${r}=  Execute Command                      sysbus.cpu GetAllOpcodesCounters
    Should Contain                              ${r}  \@custom0
    Should Contain                              ${r}  wfi

Should Count RISC-V Opcodes
    Create Machine

    # this should enable all opcodes supported by the simulated core
    Execute Command                             sysbus.cpu EnableRiscvOpcodesCounting

    # auipc
    Execute Command                             sysbus WriteDoubleWord 0x0 0x00000297            
    # addi
    Execute Command                             sysbus WriteDoubleWord 0x4 0x01028293            
    # csrw
    Execute Command                             sysbus WriteDoubleWord 0x8 0x30529073            
    # j
    Execute Command                             sysbus WriteDoubleWord 0xC 0x0000006f            

    Execute Command                             sysbus.cpu Step 4

    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "jal"
    Should Be Equal As Numbers                  ${c}  1
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "auipc"
    Should Be Equal As Numbers                  ${c}  1
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "addi"
    Should Be Equal As Numbers                  ${c}  1
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "csrrw"
    Should Be Equal As Numbers                  ${c}  1

Should Count RISC-V Opcodes By B Extension
    Create Machine

    # this should only enable opcodes supported by the B extension
    Execute Command                             sysbus.cpu EnableRiscvOpcodesCountingByExtension B

    # sh2add (from Zba extension)
    Execute Command                             sysbus WriteDoubleWord 0x0 0x20004033
    # andn (from Zbb extension)
    Execute Command                             sysbus WriteDoubleWord 0x4 0x40007033
    # bclr (from Zbs extension)
    Execute Command                             sysbus WriteDoubleWord 0x8 0x48001033
    # addi (not part of the B extension)
    Execute Command                             sysbus WriteDoubleWord 0xC 0x01028293

    Execute Command                             sysbus.cpu Step 4

    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "sh2add"
    Should Be Equal As Numbers                  ${c}  1
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "andn"
    Should Be Equal As Numbers                  ${c}  1
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "bclr"
    Should Be Equal As Numbers                  ${c}  1

    Run Keyword And Expect Error
    ...                                         *KeywordException: Could not execute command 'sysbus.cpu GetOpcodeCounter "addi"'*
    ...                                         Execute Command  sysbus.cpu GetOpcodeCounter "addi"
