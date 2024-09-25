*** Variables ***
${riscv_start_pc}                   0x2000
${armv8_start_pc}                   0x40000000

*** Keywords ***
Create RiscV Machine
    [Arguments]                     ${bitness}
    Execute Command                 using sysbus
    Execute Command                 mach create "risc-v"

    Execute Command                 machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV${bitness} @ sysbus { timeProvider: clint; cpuType: \\"rv${bitness}g\\"; interruptMode: 1 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }"

    Execute Command                 cpu PC ${riscv_start_pc}

Write One Plus One Program RiscV32
    Execute Command                 sysbus WriteDoubleWord ${riscv_start_pc} 0x00150513  # addi a0, a0, #1
    Execute Command                 sysbus WriteDoubleWord ${ ${riscv_start_pc} + 4 } 0x00150513

Write Store Load Program RiscV32
    # Does not work yet, missing op_qemu_st32
    # Program: li a0, 0xdead; auipc a1 0x40; sw a0, 0(a1); lw a2, 0(a1)
    Execute Command                 sysbus WriteDoubleWord ${riscv_start_pc} 0x0000e537
    Execute Command                 sysbus WriteDoubleWord ${ ${riscv_start_pc} + 4 } 0xead50513
    Execute Command                 sysbus WriteDoubleWord ${ ${riscv_start_pc} + 8 } 0x00040597
    Execute Command                 sysbus WriteDoubleWord ${ ${riscv_start_pc} + 12 } 0x00a5a023
    Execute Command                 sysbus WriteDoubleWord ${ ${riscv_start_pc} + 16 } 0x0005a603

Create ARMv8A Machine
    Execute Command                 using sysbus
    Execute Command                 mach create "armv8"
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/cortex-a53-gicv2.repl
    Execute Command                 cpu PC ${armv8_start_pc}

Write One Plus One Program ARMv8
    Execute Command                 sysbus WriteDoubleWord ${armv8_start_pc} 0x91000400  # add x0, x0, #0x1
    Execute Command                 sysbus WriteDoubleWord ${ ${armv8_start_pc} + 4 } 0x91000400

*** Test Cases ***
Should Calculate One Plus One RiscV32
    Create RiscV Machine            bitness=32
    Write One Plus One Program RiscV32
    Execute Command                 cpu Step
    Register Should Be Equal        10       0x1
    Execute Command                 cpu Step
    Register Should Be Equal        10       0x2

Should Calculate One Plus One ARMv8
    Create ARMv8A Machine
    Write One Plus One Program ARMv8
    Execute Command                 cpu Step
    Register Should Be Equal        0       0x1
    Execute Command                 cpu Step
    Register Should Be Equal        0       0x2
