*** Variables ***
${PROG0_PC}                 0x80000000
${PROG1_PC}                 0x80002000
${REG_POINT0}               0x2000
${REG_POINT1}               0x3000

${PLATFORM}                 SEPARATOR=\n
...                         dram: Memory.MappedMemory @ sysbus ${PROG0_PC} {
...                         ${SPACE*4}size: 0x80000000
...                         }
...                         cpu0: CPU.RiscV32 @ sysbus
...                         ${SPACE*4}cpuType: "rv32g"
...                         cpu1: CPU.RiscV32 @ sysbus
...                         ${SPACE*4}cpuType: "rv32g"
...                         cpu2: CPU.RiscV32 @ sysbus
...                         ${SPACE*4}cpuType: "rv32g"
...                         cpu3: CPU.RiscV32 @ sysbus
...                         ${SPACE*4}cpuType: "rv32g"
...                         test: DataRaceTestPeripheral @ { sysbus ${REG_POINT0}; sysbus ${REG_POINT1} }

*** Keywords ***
Create Machine
    Execute Command         include "${CURDIR}/DataRaceTestPeripheral.cs"
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescriptionFromString """${PLATFORM}"""
    Execute Command         cpu0 PC ${PROG0_PC}
    Execute Command         cpu1 PC ${PROG0_PC}
    Execute Command         cpu2 PC ${PROG1_PC}
    Execute Command         cpu3 PC ${PROG1_PC}

Assemble Test Program
    [Arguments]             ${reg_point}  ${address}
    ${PROG}=  Catenate      SEPARATOR=\n
    ...                     li a0, ${reg_point}
    ...                     loop:
    ...                     lw t0, 0(a0)
    ...                     addi t0, t0, 1
    ...                     sw t0, 0(a0)
    ...                     j loop

    Execute Command         cpu0 AssembleBlock ${address} """${PROG}"""

*** Test Cases ***
Test Peripheral Should Not Error
    Create Machine
    Create Log Tester       0
    
    Assemble Test Program   ${REG_POINT0}  ${PROG0_PC}
    Assemble Test Program   ${REG_POINT1}  ${PROG1_PC}

    Execute Command         emulation RunFor "0.000001"
    Should Not Be In Log    Should not happen
    Provides                first_test_ran

Should Deserialize
    Requires                first_test_ran
    Execute Command         emulation RunFor "0.000001"
    Should Not Be In Log    Should not happen
