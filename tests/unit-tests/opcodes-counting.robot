*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Keywords ***
Create Machine
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imacv\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"

    Execute Command                             sysbus.cpu ExecutionMode SingleStepBlocking
    Execute Command                             sysbus.cpu PC 0x0

*** Test Cases ***
Should Count Custom 16-bit Instruction
    Create Machine

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus.cpu EnableCustomOpcodesCounting

    Execute Command                             sysbus WriteWord 0x0 0xb38f

    Start Emulation
    Execute Command                             sysbus.cpu Step

    PC Should Be Equal                          0x2
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "1011001110001111"
    Should Be Equal As Numbers                  ${c}  1

Should Count Custom 32-bit Instruction
    Create Machine

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "10110011100011110000111110000010" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus.cpu EnableCustomOpcodesCounting

    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0f82

    Start Emulation
    Execute Command                             sysbus.cpu Step

    PC Should Be Equal                          0x4
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "10110011100011110000111110000010"
    Should Be Equal As Numbers                  ${c}  1

Should Count Custom 64-bit Instruction
    Create Machine

    Execute Command                             sysbus.cpu InstallCustomInstructionHandlerFromString "1011001110001111000011111000001010110011100011110000111110000010" "cpu.DebugLog('custom instruction executed!')"
    Execute Command                             sysbus.cpu EnableCustomOpcodesCounting

    Execute Command                             sysbus WriteDoubleWord 0x0 0xb38f0f82
    Execute Command                             sysbus WriteDoubleWord 0x4 0xb38f0f82

    Start Emulation
    Execute Command                             sysbus.cpu Step

    PC Should Be Equal                          0x8
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "1011001110001111000011111000001010110011100011110000111110000010"
    Should Be Equal As Numbers                  ${c}  1

Should Count Standard Opcode
    Create Machine

    Execute Command                             sysbus.cpu InstallOpcodeCounterPattern "nop" "0000000000010011" 
    Execute Command                             sysbus.cpu EnableOpcodesCounting true

    Execute Command                             sysbus WriteDoubleWord 0x0 0x13
    Execute Command                             sysbus WriteDoubleWord 0x4 0x13
    Execute Command                             sysbus WriteDoubleWord 0x8 0x13

    Start Emulation
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

    Start Emulation
    Execute Command                             sysbus.cpu Step

    PC Should Be Equal                          0x4
    ${c}=  Execute Command                      sysbus.cpu GetOpcodeCounter "vlm.v"
    Should Be Equal As Numbers                  ${c}  1

