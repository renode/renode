*** Variables ***
${starting_pc}                      0x1000
${pc_in_loop}                       0x1004
${emulation_time}                   "0.00002"

# Platform definitions
${PLAT_ARM64}                       SEPARATOR=\n  """
...                                 cpu: CPU.ARMv8A @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-a53"
...                                 ${SPACE*4}genericInterruptController: gic
...
...                                 gic: IRQControllers.ARM_GenericInterruptController
...                                 ${SPACE*4}architectureVersion: .GICv2
...                                 """
${PLAT_ARMv8R}                      SEPARATOR=\n  """
...                                 cpu: CPU.ARMv8R @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-r52"
...                                 ${SPACE*4}genericInterruptController: gic
...
...                                 gic: IRQControllers.ARM_GenericInterruptController
...                                 """
${PLAT_ARM-M}                       SEPARATOR=\n  """
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m7"
...                                 ${SPACE*4}nvic: nvic
...
...                                 nvic: IRQControllers.NVIC
...                                 """
${PLAT_X86}                         SEPARATOR=\n  """
...                                 cpu: CPU.X86 @ sysbus
...                                 ${SPACE*4}cpuType: "x86"
...                                 ${SPACE*4}lapic: lapic
...
...                                 lapic: IRQControllers.LAPIC @ sysbus 0xFEE00000
...                                 """
${PLAT_SPARC}                       "cpu: CPU.Sparc @ sysbus { cpuType: \\"leon3\\" }"
${PLAT_POWERPC}                     "cpu: CPU.PowerPc @ sysbus { cpuType: \\"e200z6\\" }"
${PLAT_ARM}                         'cpu: CPU.ARMv7R @ sysbus { cpuType: "cortex-r8"}'
${PLAT_RISCV}                       'cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32i"}'
${PLAT_XTENSA}                      'cpu: CPU.Xtensa @ sysbus { cpuType: "sample_controller"}'

# Test programs for each architecture
${PROG_RISCV}                       SEPARATOR=\n
...                                 loop:
...                                 nop
...                                 nop
...                                 nop
...                                 jal loop
${PROG_ARM}                         SEPARATOR=\n
...                                 loop:
...                                 nop
...                                 nop
...                                 nop
...                                 b loop
${PROG_X86}                         SEPARATOR=\n
...                                 loop:
...                                 nop
...                                 nop
...                                 nop
...                                 nop
...                                 jmp loop
${PROG_SPARC}                       SEPARATOR=\n
...                                 loop:
...                                 nop
...                                 nop
...                                 nop
...                                 nop
...                                 bg loop
...                                 nop
${PROG_POWERPC}                     SEPARATOR=\n
...                                 loop:
...                                 nop
...                                 nop
...                                 nop
...                                 nop
...                                 b loop

*** Keywords ***
Create Machine
    [Arguments]                     ${PLAT}  ${PROG}
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLAT}
    Configure Machine
    Execute Command                 sysbus.cpu AssembleBlock ${starting_pc} "${PROG}"

Create Machine Xtensa
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLAT_XTENSA}
    Configure Machine

    # renode-llvm-disas doesnt support Xtensa yet so the program has to be written directly to memory

    #  nops
    Execute Command                 sysbus WriteWord 0x1000 0xF03D
    Execute Command                 sysbus WriteWord 0x1002 0xF03D
    Execute Command                 sysbus WriteWord 0x1004 0xF03D
    Execute Command                 sysbus WriteWord 0x1006 0xF03D
    Execute Command                 sysbus WriteWord 0x1008 0xF03D
    Execute Command                 sysbus WriteWord 0x100a 0xF03D
    #  jmp back to 0x1000
    Execute Command                 sysbus WriteDoubleWord 0x100c 0x00FFFC06

Configure Machine
    Execute Command                 machine LoadPlatformDescriptionFromString 'mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x1000000 }'

    Execute Command                 cpu PerformanceInMips 1

    # Needed to check PC between the blocks on a hook
    Execute Command                 cpu MaximumBlockSize 1
    Execute Command                 cpu SetHookAtBlockBegin "self.DebugLog('block started: ' + 'PC '+ str(self.PC))"
    Execute Command		            cpu ChainingEnabled True

    Create Log Tester               0.01  defaultPauseEmulation=true
    Execute Command                 logLevel -1

Syncing Enabled Template
    [Arguments]                     ${PLAT}  ${PROG}
    Create Machine                  ${PLAT}  ${PROG}
    Test SyncPCEveryInstructionDisabled False

Syncing Disabled Template
    [Arguments]                     ${PLAT}  ${PROG}
    Create Machine                  ${PLAT}  ${PROG}
    Test SyncPCEveryInstructionDisabled True

# Tests run a loop of nops, after first loop translation blocks should be chained, then a hook can verify that the PC is updated between the blocks

Test SyncPCEveryInstructionDisabled True
    Execute Command                 cpu PC ${starting_pc}
    Execute Command                 cpu SyncPCEveryInstructionDisabled true
    Execute Command                 emulation RunFor ${emulation_time}

    # wait for first loop
    Wait For Log Entry              block started: PC ${pc_in_loop}  timeout=0

    # after chaining we should expect wrong PC
    Run Keyword And Expect Error
    ...                             *KeywordException: Expected pattern "block started: PC ${pc_in_loop}" did not appear in the log*
    ...                             Wait For Log Entry  block started: PC ${pc_in_loop}  timeout=0

# This test checks for an unwanted behavior

Test SyncPCEveryInstructionDisabled False
    Execute Command                 cpu PC ${starting_pc}
    Execute Command                 cpu SyncPCEveryInstructionDisabled false
    Execute Command                 emulation RunFor ${emulation_time}

    # wait for first loop
    Wait For Log Entry              block started: PC ${pc_in_loop}  timeout=0

    # after chaining we still expect PC from inside loop
    Wait For Log Entry              block started: PC ${pc_in_loop}  timeout=0

*** Test Cases ***
Should Report Wrong PC Between Chained Blocks
    [Template]                      Syncing Disabled Template
    ${PLAT_ARM}                     ${PROG_ARM}
    ${PLAT_ARM64}                   ${PROG_ARM}
    ${PLAT_ARMv8R}                  ${PROG_ARM}
    ${PLAT_ARM-M}                   ${PROG_ARM}
    ${PLAT_POWERPC}                 ${PROG_POWERPC}
    ${PLAT_SPARC}                   ${PROG_SPARC}
    # PC is already updated between instructions for RISC-V, Xtensa and X86

Should Report Correct PC Between Chained Blocks
    [Template]                      Syncing Enabled Template
    ${PLAT_RISCV}                   ${PROG_RISCV}
    ${PLAT_ARM}                     ${PROG_ARM}
    ${PLAT_ARM64}                   ${PROG_ARM}
    ${PLAT_ARMv8R}                  ${PROG_ARM}
    ${PLAT_ARM-M}                   ${PROG_ARM}
    ${PLAT_POWERPC}                 ${PROG_POWERPC}
    ${PLAT_X86}                     ${PROG_X86}
    ${PLAT_SPARC}                   ${PROG_SPARC}

# Separate path for Xtensa as it's currently not supported by Renode's LLVM assembly
Should Report Correct PC Between Chained Blocks Xtensa
    Create Machine Xtensa
    Test SyncPCEveryInstructionDisabled False
