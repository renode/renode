*** Variables ***
${ADDRESS_REG}                      0
${VALUE_REG}                        1
${STATUS_REG}                       2

*** Keywords ***
Write Opcode
    [Arguments]                     ${address}  ${opcode}
    Execute Command                 sysbus WriteDoubleWord ${address} ${opcode}

Compare Store Status
    [Arguments]                     ${expected}  ${cpu}=0
    ${value}=                       Execute Command  cpu${cpu} GetRegister ${STATUS_REG}
    Should Be Equal As Integers     ${value}  ${expected}  Unexpected store status on cpu${cpu}

Compare Memory Content
    [Arguments]                     ${expected}  ${cpu}=0
    ${addr}=                        Execute Command  cpu${cpu} GetRegister ${ADDRESS_REG}
    ${value}=                       Execute Command  sysbus ReadDoubleWord ${addr}
    Should Be Equal As Integers     ${value}  ${expected}  Unexpected memory value on cpu${cpu}

Step
    [Arguments]                     ${steps}=1  ${cpu}=0
    Execute Command                 cpu${cpu} Step ${steps}

Set Value
    [Arguments]                     ${value}  ${cpu}=0
    Execute Command                 cpu${cpu} SetRegister ${VALUE_REG} ${value}

Set Address
    [Arguments]                     ${value}  ${cpu}=0
    Execute Command                 cpu${cpu} SetRegister ${ADDRESS_REG} ${value}

Create Machine
    [Arguments]                     ${cpu_count}=1
    Execute Command                 using sysbus
    Execute Command                 mach create
    FOR  ${i}  IN RANGE  ${cpu_count}
        Execute Command                 machine LoadPlatformDescriptionFromString "cpu${i}: CPU.ARMv7R @ sysbus { cpuType: \\"cortex-r8\\"; cpuId: ${i} }"
        Execute Command                 cpu${i} ExecutionMode SingleStep
        Execute Command                 cpu${i} SetRegister ${ADDRESS_REG} 0x1000
        Execute Command                 cpu${i} PC 0x0
        Execute Command                 cpu${i} SetRegister ${STATUS_REG} 0x100
    END
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x8000000 }"

*** Test Cases ***
Should Store Exclusive Correctly
    Create Machine

    Write Opcode                    0x0  0xE1901F9F  # ldrex r1, [r0]
    Write Opcode                    0x4  0xE3A0100A  # mov r1, #0xA
    Write Opcode                    0x8  0xE1802F91  # strex r2, r1, [r0]

    Step                            steps=3
    Compare Store Status            0
    Compare Memory Content          0xA

Should Not Store Before Load Exclusive
    Create Machine

    Write Opcode                    0x0  0xE3A0100A  # mov r1, #0xA
    Write Opcode                    0x4  0xE1802F91  # strex r2, r1, [r0]

    Step                            steps=2
    Compare Store Status            1
    Compare Memory Content          0x0

Should Not Store If Value Changed
    Create Machine

    Write Opcode                    0x0  0xE1901F9F  # ldrex r1, [r0]
    Write Opcode                    0x4  0xE3A0100A  # mov r1, #0xA
    Write Opcode                    0x8  0xE5801000  # str r1, [r0]
    Write Opcode                    0xC  0xE3A0100B  # mov r1, #0xB
    Write Opcode                    0x10  0xE1802F91  # strex r2, r1, [r0]

    Step                            steps=5
    Compare Store Status            1
    # Storing 0xA with normal store and 0xB with the exclusive store. Check if the value was not overriden
    Compare Memory Content          0xA

Both CPUs Should Store
    Create Machine                  cpu_count=2

    Write Opcode                    0x0  0xE1901F9F  # ldrex r1, [r0]
    Write Opcode                    0x4  0xE1802F91  # strex r2, r1, [r0]

    Set Address                     0xAA  cpu=0
    Set Address                     0xBB  cpu=1

    Step                            cpu=0
    Step                            cpu=1

    Set Value                       0xA  cpu=0
    Set Value                       0xB  cpu=1

    Step                            cpu=0
    Step                            cpu=1

    Compare Store Status            0  cpu=0
    Compare Memory Content          0xA  cpu=0

    Compare Store Status            0  cpu=1
    Compare Memory Content          0xB  cpu=1

Second CPU Should Not Store
    Create Machine                  cpu_count=2

    Write Opcode                    0x0  0xE1901F9F  # ldrex r1, [r0]
    Write Opcode                    0x4  0xE1802F91  # strex r2, r1, [r0]

    Step                            cpu=0
    Step                            cpu=1

    Set Value                       0xA  cpu=0
    Set Value                       0xB  cpu=1

    Step                            cpu=0
    Step                            cpu=1

    Compare Store Status            0  cpu=0
    Compare Memory Content          0xA  cpu=0

    Compare Store Status            1  cpu=1
    Compare Memory Content          0xA  cpu=1

First CPU Should Not Store
    Create Machine                  cpu_count=2

    Write Opcode                    0x0  0xE1901F9F  # ldrex r1, [r0]
    Write Opcode                    0x4  0xE1802F91  # strex r2, r1, [r0]

    Step                            cpu=0
    Step                            cpu=1

    Set Value                       0xA  cpu=0
    Set Value                       0xB  cpu=1

    Step                            cpu=1
    Step                            cpu=0

    Compare Store Status            1  cpu=0
    Compare Memory Content          0xB  cpu=0

    Compare Store Status            0  cpu=1
    Compare Memory Content          0xB  cpu=1

Should Serialize Atomic State
    Create Machine                  cpu_count=2

    Write Opcode                    0x0  0xE1901F9F  # ldrex r1, [r0]
    Write Opcode                    0x4  0xE1802F91  # strex r2, r1, [r0]

    Set Address                     0xAA  cpu=0
    Set Address                     0xBB  cpu=1

    Step                            cpu=0
    Step                            cpu=1

    Provides                        registration-pass

Should Use Serialized Atomic State And Store Succesfully
    Requires                        registration-pass
    Execute Command                 cpu0 ExecutionMode SingleStep
    Execute Command                 cpu1 ExecutionMode SingleStep

    Set Value                       0xA  cpu=0
    Set Value                       0xB  cpu=1

    Step                            cpu=0
    Step                            cpu=1

    Compare Store Status            0  cpu=0
    Compare Memory Content          0xA  cpu=0

    Compare Store Status            0  cpu=1
    Compare Memory Content          0xB  cpu=1
