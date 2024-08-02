*** Variables ***
${start_pc}                     0x2000
${trap_address}                 0x4000

${unimp_op}                     0xC0001073 # CSRRW 0x, cycle, x0. Since cycle is read only, triggers illegal instruction exception
${mret}                         0x30200073 # mret

${user_level}                   0b0
${machine_level}                0b11

*** Keywords ***
Create Machine
    [Arguments]                 ${bitness}      ${privilege}
    Execute Command             using sysbus
    Execute Command             mach create "risc-v"

    Execute Command             machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV${bitness} @ sysbus { timeProvider: clint; cpuType: \\"rv${bitness}gc\\"; privilegeLevels: ${privilege}; interruptMode: 1 }"
    Execute Command             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }"

    Execute Command             cpu PC ${start_pc}

    Execute Command             cpu MTVEC ${trap_address}

    Execute Command             sysbus WriteDoubleWord ${start_pc} ${unimp_op}
    Execute Command             sysbus WriteDoubleWord ${trap_address} ${mret}

MPP Should Equal
    [Arguments]                 ${expected}
    ${mstatus}=                 Execute Command             cpu MSTATUS
    ${mpp}=                     Evaluate                    (${mstatus.strip()} & (0b11 << 11)) >> 11
    Should Be Equal As numbers  ${mpp}      ${expected}

Test Mret
    [Arguments]                 ${lowest_priv_level} 
    Execute Command             cpu Step

    MPP Should Equal            0b11    # Machine Level
    
    ${pc}=                      Execute Command         cpu PC
    Should Be Equal As Numbers  ${pc}    0x4000

    Execute Command             cpu Step

    ${pc}=                      Execute Command         cpu PC
    Should Be Equal As Numbers  ${pc}    0x2000

    MPP Should Equal            ${lowest_priv_level}

*** Test Cases ***
User Level Exists 64Bits
    Create Machine              bitness=64      privilege=PrivilegeLevels.MachineUser
    Test Mret                   ${user_level}

User Level Exists 32Bits
    Create Machine              bitness=32      privilege=PrivilegeLevels.MachineUser
    Test Mret                   ${user_level}

User Level Does Not Exists 64Bits
    Create Machine              bitness=64      privilege=PrivilegeLevels.Machine
    Test Mret                   ${machine_level}

User Level Does Not Exists 32Bits
    Create Machine              bitness=32      privilege=PrivilegeLevels.Machine
    Test Mret                   ${machine_level}
