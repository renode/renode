*** Variables ***
${starting_pc}                       0x1000
${faulting_address}                  0x4

${PLAT_RISCV}                       'cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32i"}'

${PROG_RISCV}                       SEPARATOR=\n
...                                 loop:
...                                 nop
...                                 nop
...                                 lw x0, ${faulting_address}(x0)
...                                 jal loop

*** Keywords ***
Create Machine
    [Arguments]                     ${PLAT}  ${PROG}
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 sysbus UnhandledAccessBehaviour ThrowException
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLAT}

    Execute Command                 machine LoadPlatformDescriptionFromString 'mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x1000000 }'

    Execute Command                 cpu PerformanceInMips 1
    Create Log Tester               0.01  defaultPauseEmulation=true
    Execute Command                 logLevel 0

    Execute Command                 cpu PC ${starting_pc}
    Execute Command                 cpu MaximumBlockSize 1
    Execute Command                 sysbus.cpu AssembleBlock ${starting_pc} "${PROG}"

*** Test Cases ***
Should Cause Bus Fault On RISCV
    Create Machine                  ${PLAT_RISCV}  ${PROG_RISCV}

    Execute Command                 cpu AddHook 0x2000 "self.DebugLog('MTVAL: '+ str(self.MTVAL))"
    Execute Command                 cpu MTVEC 0x2000

    Wait For Log Entry              MTVAL: ${faulting_address}
