*** Variables ***
${emulation_time}                   "0.00000005"
${illegal_address_64}               0x8000000000000000
${illegal_address_32}               0x100000000
${starting_pc}                      0x1000
${trap_vector_addr}                 0x2000

# Exception ID
${RISCV_MCAUSE_LOAD_BUS_FAULT}      0x5

# Platform definition
${PLAT_RISCV64}                     'cpu: CPU.RiscV64 @ sysbus { cpuType: "rv64g"; privilegedArchitecture: PrivilegedArchitecture.Priv1_10}'
${PLAT_RISCV32}                     'cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32i"; privilegedArchitecture: PrivilegedArchitecture.Priv1_10}'

# Test programs
# RISCV tests only written for RV64 as it's not possible to address >32bit memory on RV32 due to addres arithmetic
${PROG_RISCV_INSN_FETCH}            SEPARATOR=\n
...                                 li x1, 0x8000000000000000
...                                 jr x1
${PROG_RISCV_LOAD}                  SEPARATOR=\n
...                                 li x1, 0x8000000000000000
...                                 lw x2, 0(x1)

*** Keywords ***
Create Machine
    [Arguments]                     ${PLAT}
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLAT}
    Execute Command                 machine LoadPlatformDescriptionFromString 'mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x3000 }'

Configure Machine
    [Arguments]                     ${PROG}
    Execute Command                 cpu LogTranslationBlockFetch True
    Execute Command                 cpu AssembleBlock ${starting_pc} "${PROG}"

    Execute Command                 cpu AddHook ${trap_vector_addr} "self.DebugLog('TRAP: '+ str(self.MCAUSE))"

    Execute Command                 cpu PC ${starting_pc}
    Execute Command                 cpu MTVEC ${trap_vector_addr}

    Create Log Tester               0.01  defaultPauseEmulation=true
    Execute Command                 logLevel -1 cpu

Monitor Exception Template
    [Arguments]                     ${PLAT}  ${ADDR}
    Create Machine                  ${PLAT}

    Run Keyword And Expect Error
    ...                             *Failed to translate address*
    ...                             Execute Command  cpu TranslateAddress ${ADDR} 0

*** Test Cases ***
Should Report Illegal Address For Instruction Fetch
    Create Machine                  ${PLAT_RISCV64}
    Configure Machine               ${PROG_RISCV_INSN_FETCH}
    Execute Command                 emulation RunFor ${emulation_time}

    Wait For Log Entry              Trying to execute code from an illegal address outside of the physical memory address space: ${illegal_address_64}  timeout=0
    # Trap value not checked as instruction fetch from illegal address triggers an abort

Should Report Illegal Address For Store
    Create Machine                  ${PLAT_RISCV64}
    Configure Machine               ${PROG_RISCV_LOAD}
    Execute Command                 emulation RunFor ${emulation_time}

    Wait For Log Entry              Trying to access memory from an illegal address outside of the physical memory address space: ${illegal_address_64}  timeout=0
    Wait For Log Entry              TRAP: ${RISCV_MCAUSE_LOAD_BUS_FAULT}  timeout=0

Should Throw Monitor Exception
    [Template]                      Monitor Exception Template
    ${PLAT_RISCV32}                 ${illegal_address_32}
    ${PLAT_RISCV64}                 ${illegal_address_64}
