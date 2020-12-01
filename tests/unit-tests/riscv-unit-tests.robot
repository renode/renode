*** Settings ***
Library                       Process
Suite Setup                   Setup
Suite Teardown                Teardown
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
# RISC-V registers
${a1}                         0xb
${starting_pc}                0x2000
${next_instruction}           0x2004
${mtvec}                      0x1010
${load_misaligned}            0x4
${store_misaligned}           0x6
${register_0}                 0x0


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

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Handle LH
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000001

    # lh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00559503

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LH
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # lh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00559503

    Execute Command                 cpu ExecutionMode SingleStep
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

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LW
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # lw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055a503

    Execute Command                 cpu ExecutionMode SingleStep
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

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail LD
    Create Machine 64

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # ld a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x0055b503

    Execute Command                 cpu ExecutionMode SingleStep
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

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Handle SH
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000001

    # sh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a592a3

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SH
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # sh a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a592a3

    Execute Command                 cpu ExecutionMode SingleStep
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

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SW
    Create Machine 32

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000000

    # sw a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5a2a3

    Execute Command                 cpu ExecutionMode SingleStep
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

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${next_instruction}

Should Fail SD
    Create Machine 64

    Execute Command                 cpu SetRegisterUnsafe ${a1} 0x00000001

    # sd a0, 0x00000005(a1)
    Execute Command                 sysbus WriteDoubleWord ${starting_pc} 0x00a5b2a3

    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 s
    Execute Command                 cpu Step

    ${pc}=                          Execute Command     cpu PC
    Should Be Equal As Numbers      ${pc}   ${mtvec}

    ${mcause}=                      Execute Command     cpu MCAUSE
    Should Be Equal As Numbers      ${mcause}   ${store_misaligned}
    
Should Fail On Setting X0 register
    Create Machine 32

    ${msg}=     		    Run Keyword And Expect Error        *   Execute Command       cpu SetRegisterUnsafe ${register_0} 0x00000001
    Should Contain      	    ${msg}      value is not writable

    ${val}=     		    Execute Command     cpu GetRegisterUnsafe 0
    Should Be Equal As Numbers	    ${val}   0x0
