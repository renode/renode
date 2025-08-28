*** Settings ***
Test Tags                           atomics

*** Variables ***
${MEMORY_START}                     0x80000000
${PLATFORM}                         SEPARATOR=\n
...                                 dram: Memory.MappedMemory @ sysbus ${MEMORY_START} {
...                                 ${SPACE*4}size: 0x80000000
...                                 }
...                                 mmio: Memory.ArrayMemory @ sysbus 0x100000000 {
...                                 ${SPACE*4}size: 0x10000
...                                 }
...
...                                 cpu: CPU.RiscV64 @ sysbus {
...                                 ${SPACE*4}cpuType: "rv64gc_zicsr_zifencei";
...                                 ${SPACE*4}hartId: 1;
...                                 ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.Priv1_10;
...                                 ${SPACE*4}timeProvider: empty;
...                                 ${SPACE*4}CyclesPerInstruction: 8;
...                                 ${SPACE*4}allowUnalignedAccesses: true
...                                 }
${PAGE_SPANNING_ADDRESS}            0x0000000080000fff  # Assuming page size is 4 KiB
${MMIO_ADDRESS}                     0x0000000100001000
${MEMORY_VALUE}                     0xffffffff80000000
${INCREMENT_BY_X}                   0xfffffffffffff800
${INCREMENT_BY_Y}                   0xffffffff80000000
${EXPECTED_SUM_X_W}                 0x000000007ffff800
${EXPECTED_SUM_Y_W}                 0x00000000fffff800
${EXPECTED_SUM_X_D}                 0xffffffff7ffff800
${EXPECTED_SUM_Y_D}                 0xffffffff7ffff000

# Registers used
${a0}                               10
${a1}                               11
${a2}                               12

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM}"""
    Execute Command                 cpu ExecutionMode SingleStep
    Execute Command                 cpu PC 0x80000000

Amoadd.w Should Increment Memory Location ${variable_address}
    Create Machine

    # Place value in memory.
    Execute Command                 sysbus WriteDoubleWord ${variable_address} ${MEMORY_VALUE}

    # The assembly instructions to execute in this test.
    ${ASSEMBLY_AMOADD_W}=           catenate  SEPARATOR=
    ...                             amoadd.w a2, a1, (a0);
    ...                             amoadd.w a2, a1, (a0);

    # Place machine code at PC.
    Execute Command                 cpu AssembleBlock 0x80000000 "${ASSEMBLY_AMOADD_W}"

    Execute Command                 cpu SetRegister ${a0} ${variable_address}
    Execute Command                 cpu SetRegister ${a1} ${INCREMENT_BY_X}

    # Perform amoadd to atomically increment memory location
    Execute Command                 cpu Step

    # After amoadd, rd register should have the original memory value (before the add)...
    Register Should Be Equal        ${a2}  ${MEMORY_VALUE}  cpuName=cpu
    # and a1 should remain unchanged
    Register Should Be Equal        ${a1}  ${INCREMENT_BY_X}  cpuName=cpu

    # Now value in memory should have been incremented.
    ${res}=                         Execute Command  sysbus ReadDoubleWord ${variable_address}
    Should Be Equal As Integers     ${res}  ${EXPECTED_SUM_X_W}  "first amoadd: Memory location should now contain ${EXPECTED_SUM_X_W}"

    # Now, instead, increment by y.
    Execute Command                 cpu SetRegister ${a1} ${INCREMENT_BY_Y}

    # Perform amoadd again
    Execute Command                 cpu Step

    # After second amoadd, rd register should have the sum from the previous amoadd
    Register Should Be Equal        ${a2}  ${EXPECTED_SUM_X_W}  cpuName=cpu

    # Now value in memory should have been incremented.
    ${res}=                         Execute Command  sysbus ReadDoubleWord ${variable_address}
    Should Be Equal As Integers     ${res}  ${EXPECTED_SUM_Y_W}  "second amoadd: Memory location should now contain ${EXPECTED_SUM_Y_W}"

Amoadd.d Should Increment Memory Location ${variable_address}
    Create Machine

    # Place value in memory.
    Execute Command                 sysbus WriteQuadWord ${variable_address} ${MEMORY_VALUE}

    # The assembly instructions to execute in this test.
    ${ASSEMBLY_AMOADD_D}=           catenate  SEPARATOR=
    ...                             amoadd.d a2, a1, (a0);
    ...                             amoadd.d a2, a1, (a0);

    # Place machine code at PC.
    Execute Command                 cpu AssembleBlock 0x80000000 "${ASSEMBLY_AMOADD_D}"

    Execute Command                 cpu SetRegister ${a0} ${variable_address}
    Execute Command                 cpu SetRegister ${a1} ${INCREMENT_BY_X}

    # Perform amoadd to atomically increment memory location
    Execute Command                 cpu Step

    # After amoadd, rd register should have the original memory value (before the add)...
    Register Should Be Equal        ${a2}  ${MEMORY_VALUE}  cpuName=cpu
    # and a1 should remain unchanged
    Register Should Be Equal        ${a1}  ${INCREMENT_BY_X}  cpuName=cpu

    # Now value in memory should have been incremented.
    ${res}=                         Execute Command  sysbus ReadQuadWord ${variable_address}
    Should Be Equal As Integers     ${res}  ${EXPECTED_SUM_X_D}  "first amoadd: Memory location should now contain ${EXPECTED_SUM_X_D}"

    # Load INCREMENT_BY_X into a1 again
    Execute Command                 cpu SetRegister ${a1} ${INCREMENT_BY_X}

    # Perform amoadd again
    Execute Command                 cpu Step

    # After second amoadd, rd register should have the sum from the previous amoadd
    Register Should Be Equal        ${a2}  ${EXPECTED_SUM_X_D}  cpuName=cpu

    # Now value in memory should have been incremented.
    ${res}=                         Execute Command  sysbus ReadQuadWord ${variable_address}
    Should Be Equal As Integers     ${res}  ${EXPECTED_SUM_Y_D}  "second amoadd: Memory location should now contain ${EXPECTED_SUM_Y_D}"

*** Test Cases ***
Amoadd.w Should Increment Single-Page Memory Location
    Amoadd.w Should Increment Memory Location 0x80000100

Amoadd.d Should Increment Single-Page Memory Location
    Amoadd.d Should Increment Memory Location 0x80000100

Amoadd.w Should Increment Page-Spanning Memory Location
    Amoadd.w Should Increment Memory Location ${PAGE_SPANNING_ADDRESS}

Amoadd.d Should Increment Page-Spanning Memory Location
    Amoadd.d Should Increment Memory Location ${PAGE_SPANNING_ADDRESS}

Amoadd.d Should Increment MMIO Memory Location
    Amoadd.d Should Increment Memory Location ${MMIO_ADDRESS}

Amoadd.w Should Increment MMIO Memory Location
    Amoadd.w Should Increment Memory Location ${MMIO_ADDRESS}
