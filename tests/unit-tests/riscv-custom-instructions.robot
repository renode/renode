*** Variables ***
${csr_script}=  SEPARATOR=
...  if request.IsRead:                                                  ${\n}${SPACE}
...      cpu.DebugLog('CSR read!')                                       ${\n}
...  elif request.IsWrite:                                               ${\n}${SPACE}
...      cpu.DebugLog('CSR written: {}!'.format(hex(request.Value)))

${xadd}=  SEPARATOR=
...  src_reg_a = (instruction >> 3) & 0xF                                                            ${\n}
...  src_reg_b = (instruction >> 12) & 0xF                                                           ${\n}
...  res = cpu.GetRegister(src_reg_a).RawValue + cpu.GetRegister(src_reg_b).RawValue                 ${\n}
...  state['res'] = res

${xmv}=  SEPARATOR=
...  dst_reg = (instruction >> 3) & 0xF                                  ${\n}
...  cpu.SetRegister(dst_reg, state['res'])                        

*** Keywords ***
Create Machine
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imac_zicsr\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"

    Execute Command                             sysbus.cpu PC 0x0

Load Code To Memory
    # li x1, 0x147
    Execute Command                             sysbus WriteDoubleWord 0x0 0x14700093 

    # csrw 0xf0d, x1
    Execute Command                             sysbus WriteDoubleWord 0x4 0xf0d09073

    # csrr x2, 0xf0d
    Execute Command                             sysbus WriteDoubleWord 0x8 0xf0d02173

*** Test Cases ***
Should Install Custom 16-bit Instruction
    Create Machine
    Create Log Tester                           1

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001110" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             logLevel 0
    Execute Command                             sysbus WriteWord 0x0 0xb38e

    Execute Command                             log "--- start ---"
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Wait For Log Entry                          --- start ---
    Wait For Log Entry                          custom instruction executed! 
    Wait For Log Entry                          --- stop ---

Should Not Install Custom Instructions With Invalid Length Encoding
    Create Machine

    # 16 bit
    Run Keyword And Expect Error                *Pattern 0xB38F is invalid for 16 bits long instruction. Expected instruction in format: xxxxxxxxxxxxxxAA, AA != 11*
    ...    Execute Command                      sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111" "cpu.DebugLog('custom instruction executed!')"

    # 32 bit
    Run Keyword And Expect Error                *Pattern 0xB38F0F82 is invalid for 32 bits long instruction. Expected instruction in format: xxxxxxxxxxxxxxxxxxxxxxxxxxxBBB11, BBB != 111*
    ...    Execute Command                      sysbus.cpu InstallCustomInstructionHandlerFromString "10110011100011110000111110000010" "cpu.DebugLog('custom instruction executed!')"

    Run Keyword And Expect Error                *Pattern 0xB38F0F9F is invalid for 32 bits long instruction. Expected instruction in format: xxxxxxxxxxxxxxxxxxxxxxxxxxxBBB11, BBB != 111*
    ...    Execute Command                      sysbus.cpu InstallCustomInstructionHandlerFromString "10110011100011110000111110011111" "cpu.DebugLog('custom instruction executed!')"

    Run Keyword And Expect Error                *Pattern 0xB38F0F9E is invalid for 32 bits long instruction. Expected instruction in format: xxxxxxxxxxxxxxxxxxxxxxxxxxxBBB11, BBB != 111*
    ...    Execute Command                      sysbus.cpu InstallCustomInstructionHandlerFromString "10110011100011110000111110011110" "cpu.DebugLog('custom instruction executed!')"

    # 64 bit
    Run Keyword And Expect Error                *Pattern 0xB38F0F82B38F0FBB is invalid for 64 bits long instruction. Expected instruction in format: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx0111111*
    ...    Execute Command                      sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111000011111000001010110011100011110000111110111011" "cpu.DebugLog('custom instruction executed!')"

    Run Keyword And Expect Error                *Pattern 0xB38F0F82B38F0FFF is invalid for 64 bits long instruction. Expected instruction in format: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx0111111*
    ...    Execute Command                      sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111000011111000001010110011100011110000111111111111" "cpu.DebugLog('custom instruction executed!')"

Should Install Custom 32-bit Instruction
    Create Machine
    Create Log Tester                           1

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "10110011100011110000111110000011" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             logLevel 0
    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0f83

    Execute Command                             log "--- start ---"
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Wait For Log Entry                          --- start ---
    Wait For Log Entry                          custom instruction executed! 
    Wait For Log Entry                          --- stop ---

Should Install Custom 64-bit Instruction
    Create Machine
    Create Log Tester                           1

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111000011111000001010110011100011110000111110111111" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             logLevel 0
    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0fbf
    Execute Command                             sysbus WriteDoubleWord 0x4 0xb38f0f82

    Execute Command                             log "--- start ---"
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Wait For Log Entry                          --- start ---
    Wait For Log Entry                          custom instruction executed! 
    Wait For Log Entry                          --- stop ---

Should Override An Existing 32-bit Instruction
    Create Machine
    Create Log Tester                           1

    # normally this instruction means "li x1, 0x147"
    # but we override it with a custom implementation
    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "00010100011100000000000010010011" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             logLevel 0
    Execute Command                             sysbus WriteDoubleWord 0x0 0x14700093

    Register Should Be Equal                    1  0x0

    Execute Command                             log "--- start ---"
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Register Should Be Equal                    1  0x0

    Wait For Log Entry                          --- start ---
    Wait For Log Entry                          custom instruction executed! 
    Wait For Log Entry                          --- stop ---

Should Install Custom 32-bit Instructions Sharing State
    Create Machine
    Create Log Tester                           1

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111bbbb11111aaaa011" "${xadd}"
    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "0011001110001111000011111aaaa011" "${xmv}"

    # li x1, 0x147
    Execute Command                             sysbus WriteDoubleWord 0x0 0x14700093 
    # li x2, 0x19
    Execute Command                             sysbus WriteDoubleWord 0x4 0x01900113

    # add values of x1 and x2 and store in the local register
    Execute Command                             sysbus WriteDoubleWord 0x8 0xB38F2F8B
    # move the local register to x3
    Execute Command                             sysbus WriteDoubleWord 0xC 0x338F0F9B

    Register Should Be Equal                    1  0x0
    Register Should Be Equal                    2  0x0
    Register Should Be Equal                    3  0x0

    Execute Command                             sysbus.cpu Step 2

    Register Should Be Equal                    1  0x147
    Register Should Be Equal                    2  0x19
    Register Should Be Equal                    3  0x0

    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    1  0x147
    Register Should Be Equal                    2  0x19
    Register Should Be Equal                    3  0x0

    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    1  0x147
    Register Should Be Equal                    2  0x19
    Register Should Be Equal                    3  0x160

Should Register Simple Custom CSR
    Create Machine

    Execute Command                             sysbus.cpu CSRValidation 0
    Execute Command                             sysbus.cpu RegisterCustomCSR "test csr" 0xf0d 3

    Load Code To Memory

    Register Should Be Equal                    1  0x0
    Register Should Be Equal                    2  0x0

    Execute Command                             sysbus.cpu Step 3
    
    PC Should Be Equal                          0xc

    Register Should Be Equal                    1  0x147
    Register Should Be Equal                    2  0x147

Should Register Custom CSR
    Create Machine
    Create Log Tester                           1

    Execute Command                             sysbus.cpu CSRValidation 0
    Execute Command                             sysbus.cpu RegisterCSRHandlerFromString 0xf0d "${csr_script}"
    Execute Command                             logLevel 0

    Load Code To Memory

    Execute Command                             sysbus.cpu Step 3
    
    ${pc}=  Execute Command                     sysbus.cpu PC
    Should Be Equal                             0xc  ${pc.replace('\n', '')}

    Register Should Be Equal                    1  0x147
    Register Should Be Equal                    2  0x147

    Wait For Log Entry                          CSR written: 0x147L! 
    Wait For Log Entry                          CSR read! 
