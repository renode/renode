*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${csr_script}=  SEPARATOR=
...  if request.isRead:                                                  ${\n}${SPACE}
...      cpu.DebugLog('CSR read!')                                       ${\n}
...  elif request.isWrite:                                               ${\n}${SPACE}
...      cpu.DebugLog('CSR written: {}!'.format(hex(request.value)))

${xadd}=  SEPARATOR=
...  src_reg_a = instruction & 0xF                                                                   ${\n}
...  src_reg_b = (instruction >> 12) & 0xF                                                           ${\n}
...  res = cpu.GetRegisterUnsafe(src_reg_a).RawValue + cpu.GetRegisterUnsafe(src_reg_b).RawValue     ${\n}
...  state['res'] = res

${xmv}=  SEPARATOR=
...  dst_reg = instruction & 0xF                                         ${\n}
...  cpu.SetRegisterUnsafe(dst_reg, state['res'])                        

*** Keywords ***
Create Machine
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imac\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"

    Execute Command                             sysbus.cpu ExecutionMode SingleStepBlocking
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

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             logLevel 0
    Execute Command                             sysbus WriteWord 0x0 0xb38f

    Execute Command                             log "--- start ---"
    Start Emulation
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Wait For Log Entry                          --- start ---
    Wait For Log Entry                          custom instruction executed! 
    Wait For Log Entry                          --- stop ---

Should Install Custom 32-bit Instruction
    Create Machine
    Create Log Tester                           1

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "10110011100011110000111110000010" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             logLevel 0
    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0f82

    Execute Command                             log "--- start ---"
    Start Emulation
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Wait For Log Entry                          --- start ---
    Wait For Log Entry                          custom instruction executed! 
    Wait For Log Entry                          --- stop ---

Should Install Custom 64-bit Instruction
    Create Machine
    Create Log Tester                           1

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111000011111000001010110011100011110000111110000010" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             logLevel 0
    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0f82
    Execute Command                             sysbus WriteDoubleWord 0x4 0xb38f0f82

    Execute Command                             log "--- start ---"
    Start Emulation
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
    Start Emulation
    Execute Command                             sysbus.cpu Step
    Execute Command                             log "--- stop ---"

    Register Should Be Equal                    1  0x0

    Wait For Log Entry                          --- start ---
    Wait For Log Entry                          custom instruction executed! 
    Wait For Log Entry                          --- stop ---

Should Install Custom 32-bit Instructions Sharing State
    Create Machine
    Create Log Tester                           1

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111bbbb11111000aaaa" "${xadd}"
    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111000011111011aaaa" "${xmv}"

    # li x1, 0x147
    Execute Command                             sysbus WriteDoubleWord 0x0 0x14700093 
    # li x2, 0x19
    Execute Command                             sysbus WriteDoubleWord 0x4 0x01900113

    # add values of x1 and x2 and store in the local register
    Execute Command                             sysbus WriteDoubleWord 0x8 0xB38F2F81
    # move the local register to x3
    Execute Command                             sysbus WriteDoubleWord 0xC 0xB38F0FB3

    Register Should Be Equal                    1  0x0
    Register Should Be Equal                    2  0x0
    Register Should Be Equal                    3  0x0

    Start Emulation
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

    Start Emulation
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

    Start Emulation
    Execute Command                             sysbus.cpu Step 3
    
    ${pc}=  Execute Command                     sysbus.cpu PC
    Should Be Equal                             0xc  ${pc.replace('\n', '')}

    Register Should Be Equal                    1  0x147
    Register Should Be Equal                    2  0x147

    Wait For Log Entry                          CSR written: 0x147L! 
    Wait For Log Entry                          CSR read! 
