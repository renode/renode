*** Settings ***
Test Setup                          Create Machine
Test Tags                           atomics

*** Variables ***
${MEMORY_START}                     0x80000000
${PLATFORM_STRING}                  SEPARATOR=\n
...                                 dram: Memory.MappedMemory @ sysbus ${MEMORY_START} {
...                                 ${SPACE*4}size: 0x80000000
...                                 }
...                                 mmio: Memory.ArrayMemory @ sysbus 0x100000000 {
...                                 ${SPACE*4}size: 0x10000
...                                 }
...                                 mtvec: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }
...
...                                 cpu: CPU.RiscV64 @ sysbus {
...                                 ${SPACE*4}cpuType: "rv64gc_zicsr_zifencei_zacas";
...                                 ${SPACE*4}hartId: 1;
...                                 ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.Priv1_10;
...                                 ${SPACE*4}timeProvider: empty;
...                                 ${SPACE*4}CyclesPerInstruction: 8;
...                                 ${SPACE*4}allowUnalignedAccesses: true
...                                 }
...
...                                 cpu32: CPU.RiscV32 @ sysbus {
...                                 ${SPACE*4}cpuType: "rv32gc_zicsr_zifencei_zacas";
...                                 ${SPACE*4}hartId: 2;
...                                 ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.Priv1_10;
...                                 ${SPACE*4}timeProvider: empty;
...                                 ${SPACE*4}CyclesPerInstruction: 8;
...                                 ${SPACE*4}allowUnalignedAccesses: true
...                                 }
${PROGRAM_COUNTER}                  0x80000000
${PROGRAM_COUNTER_32}               0x80000100
${ORDINARY_ADDRESS}                 0x80001000
${MAX_PAGE_SIZE}                    0x40000000  # 1 GiB
${PAGE_SPANNING_ADDRESS}            ${{str(${MEMORY_START} + ${MAX_PAGE_SIZE} - 1)}}  # str necessary since robot's XML-RPC library doesn't support >32-bit integers
${MMIO_ADDRESS}                     0x0000000100001000

${mtvec}                            0x1010
${illegal_instruction}              0x2

# Registers used
${x0}                               0
${a0}                               10
${a1}                               11
${a2}                               12
${a3}                               13
${a4}                               14
${s2}                               18

# 32-, 64- and 128-bit constants
${wrong_expected_128}               0x12345678910111213141516171819202
${wrong_expected_64}                0x1234567891011
${wrong_expected_32}                0x1234
${expected_128}                     0x2badc00010ffb0ba1afedeadbeefd00d
${expected_64}                      0x1afedeadbeefd00d
${expected_32}                      0xbeefd00d
${new_128}                          0x216b00b5d0d0caca1eeff00dbabedead
${new_64}                           0xbeeff00dbabedead
${new_32}                           0xbeefbabe

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM_STRING}"""
    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 cpu PC ${PROGRAM_COUNTER}
    Execute Command                 cpu32 ExecutionMode SingleStep
    Execute Command                 cpu32 PC ${PROGRAM_COUNTER}

Get Cpu On ${platform:(RV32|RV64)}
    IF  "${platform}" == "RV32"
        ${cpu}=                         Set Variable  cpu32
    ELSE IF  "${platform}" == "RV64"
        ${cpu}=                         Set Variable  cpu
    END
    [return]                        ${cpu}

Amocas.${size:(w|d|q)} ${rd} ${rs2} ${rs1} On ${platform:(RV32|RV64)} Should Throw Illegal Instruction
    ${cpu}=                         Get Cpu On ${platform}

    # Should have jumped to mtvec
    PC Should Be Equal              ${mtvec}  cpuName=${cpu}

    # The cause should be illegal instruction.
    ${mcause}=                      Execute Command  ${cpu} MCAUSE
    Should Be Equal As Numbers      ${mcause}  ${illegal_instruction}

    # MTVAL should be the opcode that caused the fault.
    ${mtval}=                       Execute Command  ${cpu} MTVAL
    ${illegal_amocas_opcode}=       Assemble Amocas.${size} ${rd} ${rs2} ${rs1}
    Should Be Equal As Numbers      ${mtval}  ${illegal_amocas_opcode}

    # MEPC should point to the illegal instruction.
    ${mepc}=                        Execute Command  ${cpu} MEPC
    Should Be Equal As Numbers      ${mepc}  ${PROGRAM_COUNTER}

Amocas.${size:(w|d|q)} Memory Location ${address} Should Now Be Set To ${value}
    IF  "${size}" == "w"
        ${current_value}=               Execute Command  sysbus ReadDoubleWord ${address}
    ELSE IF  "${size}" == "d"
        ${current_value}=               Execute Command  sysbus ReadQuadWord ${address}
    ELSE IF  "${size}" == "q"
        ${current_value_lower}=         Execute Command  sysbus ReadQuadWord ${address}
        ${current_value_upper}=         Execute Command  sysbus ReadQuadWord ${${address} + 8}
    END

    IF  "${size}" == "q"
        ${new_value_lower}=             Set Variable  ${{str(int(${value}) & 0xFFFFFFFFFFFFFFFF)}}
        ${new_value_upper}=             Set Variable  ${{str((int(${value}) >> 64) & 0xFFFFFFFFFFFFFFFF)}}
        Should Be Equal As Integers     ${current_value_lower}  ${new_value_lower}  "Memory location lower should now be set to ${new_value_lower}"
        Should Be Equal As Integers     ${current_value_upper}  ${new_value_upper}  "Memory location upper should now be set to ${new_value_upper}"
    ELSE
        Should Be Equal As Integers     ${current_value}  ${value}  "Memory location ${address} should now be set to ${value} but it's ${current_value}"
    END

Amocas.${size:(w|d|q)} Register ${register} On ${platform:(RV32|RV64)} Should Contain ${expected_value}
    ${cpu}=                         Get Cpu On ${platform}

    IF  "${platform}" == "RV32" and "${size}" == "d"
        # str necessary since robot's XML-RPC library doesn't support >32-bit integers
        ${expected_value_lower}=        Set Variable  ${{str(int(${expected_value}) & 0xFFFFFFFF)}}
        ${expected_value_upper}=        Set Variable  ${{str((int(${expected_value}) >> 32) & 0xFFFFFFFF)}}
        Register Should Be Equal        ${register}  ${expected_value_lower}  cpuName=${cpu}
        Register Should Be Equal        ${${register} + 1}  ${expected_value_upper}  cpuName=${cpu}
    ELSE IF  "${platform}" == "RV64" and "${size}" == "q"
        # str necessary since robot's XML-RPC library doesn't support >32-bit integers
        ${expected_value_lower}=        Set Variable  ${{str(int(${expected_value}) & 0xFFFFFFFFFFFFFFFF)}}
        ${expected_value_upper}=        Set Variable  ${{str((int(${expected_value}) >> 64) & 0xFFFFFFFFFFFFFFFF)}}
        Register Should Be Equal        ${register}  ${expected_value_lower}  cpuName=${cpu}
        Register Should Be Equal        ${${register} + 1}  ${expected_value_upper}  cpuName=${cpu}
    ELSE
        Register Should Be Equal        ${register}  ${expected_value}  cpuName=${cpu}
    END

Amocas.${size:(w|d|q)} Set Register ${register} On ${platform:(RV32|RV64)} To ${value}
    ${cpu}=                         Get Cpu On ${platform}

    IF  "${register}" == "0"
        Return From Keyword
    END

    IF  "${platform}" == "RV32" and "${size}" == "d"
        ${value_lower}=                 Set Variable  ${{${value} & 0xFFFFFFFF}}
        ${value_upper}=                 Set Variable  ${{(${value} >> 32) & 0xFFFFFFFF}}
        Execute Command                 ${cpu} SetRegister ${register} ${value_lower}
        Execute Command                 ${cpu} SetRegister ${${register} + 1} ${value_upper}
    ELSE IF  "${platform}" == "RV64" and "${size}" == "q"
        # str necessary since robot's XML-RPC library doesn't support >32-bit integers
        ${value_lower}=                 Set Variable  ${{str(int(${value}) & 0xFFFFFFFFFFFFFFFF)}}
        ${value_upper}=                 Set Variable  ${{str((int(${value}) >> 64) & 0xFFFFFFFFFFFFFFFF)}}
        Execute Command                 ${cpu} SetRegister ${register} ${value_lower}
        Execute Command                 ${cpu} SetRegister ${${register} + 1} ${value_upper}
    ELSE
        Execute Command                 ${cpu} SetRegister ${register} ${value}
    END

Assemble Amocas.${size:(w|d|q)} ${rd} ${rs2} ${rs1}
    # Hand-assembled instructions necessary due to
    # our version of the LLVM assembler not supporting the Zacas extension. (issue #74345)

    # The machine code for an amocas instruction with its operands and size zeroed out.
    ${amocas_base}=                 Set Variable  0b00101_0_0_00000_00000_000_00000_0101111

    # Translate size mnemonic to corresponding bit pattern.
    IF  "${size}" == "w"
        ${size_bits}=                   Set Variable  0b010
    ELSE IF  "${size}" == "d"
        ${size_bits}=                   Set Variable  0b011
    ELSE IF  "${size}" == "q"
        ${size_bits}=                   Set Variable  0b100
    END

    # Insert size into instruction
    ${amocas_sized}=                Set Variable  ${{${amocas_base} | (${size_bits} << 12)}}

    # Insert rd operand
    ${amocas_sized_rd}=             Set Variable  ${{${amocas_sized} | (${rd} << 7)}}

    # Insert rs1 operand
    ${amocas_sized_rd_rs1}=         Set Variable  ${{${amocas_sized_rd} | (${rs1} << 15)}}

    # Insert rs2 operand
    ${amocas_complete}=             Set Variable  ${{${amocas_sized_rd_rs1} | (${rs2} << 20)}}

    [return]                        ${amocas_complete}

Amocas.${size:(w|d|q)} On ${platform:(RV32|RV64)} ${should:(Should|Shouldn't)} Set Value At ${variable_address} To ${new_value} If Expecting ${expected_value}
    [Arguments]
    ...                             ${rd}=${a0}
    ...                             ${rs1}=${a3}
    ...                             ${rs2}=${s2}
    ...                             ${original_value_upper}=0x2badc00010ffb0ba
    ...                             ${original_value_lower}=${expected_64}

    # Place value in memory.
    Execute Command                 sysbus WriteQuadWord ${variable_address} ${original_value_lower}
    Execute Command                 sysbus WriteQuadWord ${${variable_address} + 8} ${original_value_upper}

    ${cpu}=                         Get Cpu On ${platform}

    # Construct amocas instruction.
    ${MACHINE_CODE_AMOCAS}=         Assemble Amocas.${size} ${rd} ${rs2} ${rs1}

    IF  "${size}" == "w"
        # str necessary since robot's XML-RPC library doesn't support >32-bit integers
        ${ORIGINAL_VALUE_MASKED}=       Set Variable  ${{str(${original_value_lower} & 0xFFFFFFFF)}}
    ELSE IF  "${size}" == "d"
        ${ORIGINAL_VALUE_MASKED}=       Set Variable  ${original_value_lower}
    ELSE IF  "${size}" == "q"
        # str necessary since robot's XML-RPC library doesn't support >32-bit integers
        ${ORIGINAL_VALUE_MASKED}=       Set Variable  "${{str((${original_value_upper} << 64) | ${original_value_lower})}}"
    END

    # Place machine code at PC.
    Execute Command                 sysbus WriteDoubleWord ${PROGRAM_COUNTER} ${MACHINE_CODE_AMOCAS}

    # Set operand values.
    Amocas.${size} Set Register ${rd} On ${platform} To ${expected_value}
    Amocas.${size} Set Register ${rs1} On ${platform} To ${variable_address}
    Amocas.${size} Set Register ${rs2} On ${platform} To ${new_value}

    # Remember previous value.
    ${result_upper_original_value}=  Execute Command  ${cpu} GetRegister ${${rd} + 1}
    ${rs2_upper_original_value}=    Execute Command  ${cpu} GetRegister ${${rs2} + 1}

    # Perform amocas.
    Execute Command                 ${cpu} Step

    IF  "${rd}" != "0"
        # After amocas, rd register should have the original memory value (before the cas)...
        Amocas.${size} Register ${rd} On ${platform} Should Contain ${ORIGINAL_VALUE_MASKED}
    ELSE IF  ("${platform}" == "RV32" and "${size}" == "d") or ("${platform}" == "RV64" and "${size}" == "q")
        # Unless rd is x0, in which case the original memory value is discarded and neither result register is written.
        # Ensure rd+1 isn't written to.
        Register Should Be Equal        ${${rd} + 1}  ${result_upper_original_value}  cpuName=${cpu}
    END
    # and the others should remain unchanged
    IF  "${rs2}" != "0"
        Amocas.${size} Register ${rs2} On ${platform} Should Contain ${new_value}
    ELSE IF  ("${platform}" == "RV32" and "${size}" == "d") or ("${platform}" == "RV64" and "${size}" == "q")
        # Unless rs2 is x0, in which case rs2+1 is interpreted as 0 no matter its contents.
        # Ensure rs2+1 remains unchanged.
        Register Should Be Equal        ${${rs2} + 1}  ${rs2_upper_original_value}  cpuName=${cpu}
    END
    Register Should Be Equal        ${rs1}  ${variable_address}  cpuName=${cpu}

    IF  "${should}" == "Should"
        # Now value in memory should have been set.
        Amocas.${size} Memory Location ${variable_address} Should Now Be Set To ${new_value}
    ELSE
        # Value in memory should remain unchanged.
        Amocas.${size} Memory Location ${variable_address} Should Now Be Set To ${ORIGINAL_VALUE_MASKED}
    END

*** Test Cases ***
# w should tests
Amocas.w On RV64 Should Set Value At Single-Page Memory Location
    Amocas.w On RV64 Should Set Value At ${ORDINARY_ADDRESS} To ${new_32} If Expecting ${expected_32}

Amocas.w On RV64 Should Set Value At Page-Spanning Memory Location
    Amocas.w On RV64 Should Set Value At ${PAGE_SPANNING_ADDRESS} To ${new_32} If Expecting ${expected_32}

Amocas.w On RV64 Should Set Value At MMIO Memory Location
    Amocas.w On RV64 Should Set Value At ${MMIO_ADDRESS} To ${new_32} If Expecting ${expected_32}

Amocas.w On RV32 Should Set Value At Single-Page Memory Location
    Amocas.w On RV32 Should Set Value At ${ORDINARY_ADDRESS} To ${new_32} If Expecting ${expected_32}

# w shouldn't tests

Amocas.w On RV64 Shouldn't Set Value At Single-Page Memory Location
    Amocas.w On RV64 Shouldn't Set Value At ${ORDINARY_ADDRESS} To ${new_32} If Expecting ${wrong_expected_32}

Amocas.w On RV64 Shouldn't Set Value At Page-Spanning Memory Location
    Amocas.w On RV64 Shouldn't Set Value At ${PAGE_SPANNING_ADDRESS} To ${new_32} If Expecting ${wrong_expected_32}

Amocas.w On RV64 Shouldn't Set Value At MMIO Memory Location
    Amocas.w On RV64 Shouldn't Set Value At ${MMIO_ADDRESS} To ${new_32} If Expecting ${wrong_expected_32}

Amocas.w On RV32 Shouldn't Set Value At Single-Page Memory Location
    Amocas.w On RV32 Shouldn't Set Value At ${ORDINARY_ADDRESS} To ${new_32} If Expecting ${wrong_expected_32}

# d should tests

Amocas.d On RV64 Should Set Value At Single-Page Memory Location
    Amocas.d On RV64 Should Set Value At ${ORDINARY_ADDRESS} To ${new_64} If Expecting ${expected_64}

Amocas.d On RV32 Should Set Value At Single-Page Memory Location
    Amocas.d On RV32 Should Set Value At ${ORDINARY_ADDRESS} To ${new_64} If Expecting ${expected_64}

Amocas.d On RV32 Should Handle Zero Source Register
    # Place value in rs2+1 which should be ignored.
    Execute Command                 cpu32 SetRegister ${${x0} + 1} ${wrong_expected_32}

    Amocas.d On RV32 Should Set Value At ${ORDINARY_ADDRESS} To 0 If Expecting ${expected_64}
    ...                             rs2=${x0}

Amocas.d On RV32 Should Handle Zero Destination Register
    # Place value in rd+1 which shouldn't be overwritten.
    Execute Command                 cpu32 SetRegister ${${x0} + 1} ${wrong_expected_32}

    Amocas.d On RV32 Should Set Value At ${ORDINARY_ADDRESS} To ${new_64} If Expecting 0
    ...                             rd=${x0}
    ...                             original_value_lower=0

Amocas.d On RV64 Should Set Value At Page-Spanning Memory Location
    Amocas.d On RV64 Should Set Value At ${PAGE_SPANNING_ADDRESS} To ${new_64} If Expecting ${expected_64}

Amocas.d On RV64 Should Set Value At MMIO Memory Location
    Amocas.d On RV64 Should Set Value At ${MMIO_ADDRESS} To ${new_64} If Expecting ${expected_64}

# d shouldn't tests

Amocas.d On RV64 Shouldn't Set Value At Single-Page Memory Location
    Amocas.d On RV64 Shouldn't Set Value At ${ORDINARY_ADDRESS} To ${new_64} If Expecting ${wrong_expected_64}

Amocas.d On RV32 Shouldn't Set Value At Single-Page Memory Location
    Amocas.d On RV32 Shouldn't Set Value At ${ORDINARY_ADDRESS} To ${new_64} If Expecting ${wrong_expected_64}

Amocas.d On RV64 Shouldn't Set Value At Single-Page Memory Location
    Amocas.d On RV64 Shouldn't Set Value At ${PAGE_SPANNING_ADDRESS} To ${new_64} If Expecting ${wrong_expected_64}

Amocas.d On RV64 Shouldn't Set Value At Single-Page Memory Location
    Amocas.d On RV64 Shouldn't Set Value At ${MMIO_ADDRESS} To ${new_64} If Expecting ${wrong_expected_64}

# q should tests

Amocas.q On RV64 Should Set Value At Single-Page Memory Location
    Amocas.q On RV64 Should Set Value At ${ORDINARY_ADDRESS} To ${new_128} If Expecting ${expected_128}

Amocas.q On RV64 Should Set Value At Page-Spanning Memory Location
    Amocas.q On RV64 Should Set Value At ${PAGE_SPANNING_ADDRESS} To ${new_128} If Expecting ${expected_128}

Amocas.q On RV64 Should Set Value At MMIO Memory Location
    Amocas.q On RV64 Should Set Value At ${MMIO_ADDRESS} To ${new_128} If Expecting ${expected_128}

Amocas.q On RV64 Should Handle Zero Source Register
    # Place value in rs2+1 which should be ignored.
    Execute Command                 cpu SetRegister ${${x0} + 1} ${wrong_expected_32}

    Amocas.q On RV64 Should Set Value At ${ORDINARY_ADDRESS} To 0 If Expecting ${expected_128}
    ...                             rs2=${x0}

Amocas.q On RV64 Should Handle Zero Destination Register
    # Place value in rd+1 which shouldn't be overwritten.
    Execute Command                 cpu SetRegister ${${x0} + 1} ${wrong_expected_32}

    Amocas.q On RV64 Should Set Value At ${ORDINARY_ADDRESS} To ${new_128} If Expecting 0
    ...                             rd=${x0}
    ...                             original_value_lower=0
    ...                             original_value_upper=0

# q shouldn't tests

Amocas.q On RV64 Shouldn't Set Value At Single-Page Memory Location
    Amocas.q On RV64 Shouldn't Set Value At ${ORDINARY_ADDRESS} To ${new_128} If Expecting ${wrong_expected_128}

Amocas.q On RV64 Shouldn't Set Value At Page-Spanning Memory Location
    Amocas.q On RV64 Shouldn't Set Value At ${PAGE_SPANNING_ADDRESS} To ${new_128} If Expecting ${wrong_expected_128}

Amocas.q On RV64 Shouldn't Set Value At MMIO Memory Location
    Amocas.q On RV64 Shouldn't Set Value At ${MMIO_ADDRESS} To ${new_128} If Expecting ${wrong_expected_128}

# illegal instructions

Amocas.d On RV32 Using Odd Registers Should Throw Illegal Instruction
    ${odd_rd}=                      Set Variable  ${${a0} + 1}
    ${odd_rs2}=                     Set Variable  ${${s2} + 1}

    Amocas.d On RV32 Shouldn't Set Value At ${ORDINARY_ADDRESS} To ${new_64} If Expecting ${expected_64}
    ...                             rd=${odd_rd}
    ...                             rs2=${odd_rs2}

    Amocas.d ${odd_rd} ${odd_rs2} ${a3} On RV32 Should Throw Illegal Instruction

Amocas.q On RV64 Using Odd Registers Should Throw Illegal Instruction
    ${odd_rd}=                      Set Variable  ${${a0} + 1}
    ${odd_rs2}=                     Set Variable  ${${s2} + 1}

    Amocas.q On RV64 Shouldn't Set Value At ${ORDINARY_ADDRESS} To ${new_128} If Expecting ${expected_128}
    ...                             rd=${odd_rd}
    ...                             rs2=${odd_rs2}

    Amocas.q ${odd_rd} ${odd_rs2} ${a3} On RV64 Should Throw Illegal Instruction
