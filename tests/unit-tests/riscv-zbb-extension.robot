*** Variables ***
${64bit_cpu}=                                  cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imac_zicsr_zba_zbb\\"; timeProvider: empty }
${32bit_cpu}=                                  cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imac_zicsr_zba_zbb\\"; timeProvider: empty }

*** Keywords ***
Create Machine
    [Arguments]    ${repl}
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "${repl}"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"

    Execute Command                             sysbus.cpu PC 0x0

Load RORI Test To Memory
    # li a0, 0x1
    Execute Command                             sysbus WriteWord 0x0 0x4505 

    # addi a0, a0, 1
    Execute Command                             sysbus WriteWord 0x2 0x0505

    # rori a0, a0, 1
    Execute Command                             sysbus WriteDoubleWord 0x4 0x60155513

    # rori a0, a0, 1
    Execute Command                             sysbus WriteDoubleWord 0x8 0x60155513

Load RORIW Test To Memory
    # li a0, 0x1
    Execute Command                             sysbus WriteWord 0x0 0x4505 

    # addi a0, a0, 1
    Execute Command                             sysbus WriteWord 0x2 0x0505

    # roriw a0, a0, 1
    Execute Command                             sysbus WriteDoubleWord 0x4 0x6015551B

    # roriw a0, a0, 1
    Execute Command                             sysbus WriteDoubleWord 0x8 0x6015551B

Load SLLI.UW Test To Memory
    # li a0, 0x1
    Execute Command                             sysbus WriteWord 0x0 0x4505 

    # addi a0, a0, 1
    Execute Command                             sysbus WriteWord 0x2 0x0505

    # slli.uw a0, a0, 1
    Execute Command                             sysbus WriteDoubleWord 0x4 0x0815151B

    # li a0, 0x0000000040000000
    Execute Command                             sysbus WriteDoubleWord 0x8 0x40000537

    # slli.uw a0, a0, 1
    Execute Command                             sysbus WriteDoubleWord 0xC 0x0815151B

*** Test Cases ***
Should Handle RORI Properly on 64 Bit CPU
    Create Machine  ${64bit_cpu}
    Load RORI Test To Memory

    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x1
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x2
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x1
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x8000000000000000

Should Handle RORI Properly on 32 Bit CPU
    Create Machine  ${32bit_cpu}
    Load RORI Test To Memory

    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x1
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x2
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x1
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x80000000

Should Handle RORIW Properly
    # This instruction is supported only on 64 bit CPUs
    Create Machine  ${64bit_cpu}
    Load RORIW Test To Memory

    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x1
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x2
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x1
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0xFFFFFFFF80000000

Should Handle SLLI.UW Properly
    Create Machine  ${64bit_cpu}
    Load SLLI.UW Test To Memory

    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x1
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x2
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x4
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x0000000040000000
    Execute Command                             sysbus.cpu Step
    Register Should Be Equal                    10  0x0000000080000000