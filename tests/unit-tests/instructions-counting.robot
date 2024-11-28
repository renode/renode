*** Variables ***
${a0}                               0xA
${w0}                               0x0
${x1}                               0x1
${ASSEMBLY_ADDRESS}                 0x0
${X_CHAR}                           120
${ARM_UART_DATA_ADDRESS}            0x2000
${WATCHPOINT_ADDRESS}               0x100
${BUTTON_ELF}                       @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-button.elf-s_402204-2343dc7268dedc253893a84300f3dbd02bc63a2a
${BLOCK_END_HOOK}                   "cpu.Log(LogLevel.Info, 'BlockEnd Hook: Executed {0} Instructions', cpu.ExecutedInstructions)"
${BUTTON_REPL}=                     SEPARATOR=\n
...  """
...  button: Miscellaneous.Button @ gpioPortB
...  ${SPACE*4}invert: true
...  ${SPACE*4}-> gpioPortB@2
...  """
${ARM_PLATFORM}=                    SEPARATOR=\n
...  """
...  cpu: CPU.ARMv8A @ sysbus
...  ${SPACE*4}cpuType: "cortex-a53"
...  ${SPACE*4}genericInterruptController: gic
...
...  mem: Memory.MappedMemory @ sysbus 0x0
...  ${SPACE*4}size: 0x1000
...
...  gic: IRQControllers.ARM_GenericInterruptController @ {
...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x8000000; size: 0x010000; region: "distributor" };
...  ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x8010000; size: 0x010000; region: "cpuInterface" }
...  ${SPACE*4}}
...  ${SPACE*4}\[0-1\] -> cpu@\[0-1\]
...  ${SPACE*4}architectureVersion: IRQControllers.ARM_GenericInterruptControllerVersion.GICv2
...  ${SPACE*4}supportsTwoSecurityStates: true
...
...  uart: UART.TrivialUart @ sysbus 0x2000
...  """
${RISCV_PLATFORM}=                  SEPARATOR=\n
...  """
...  cpu: CPU.RiscV32 @ sysbus
...  ${SPACE*4}timeProvider: clint
...  ${SPACE*4}cpuType: "rv32gc"
...
...  mem: Memory.MappedMemory @ sysbus 0x0
...  ${SPACE*4}size: 0x100000
...
...  clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000
...  ${SPACE*4}frequency: 66000000
...  """

*** Keywords ***
Create Platform
    [Arguments]                     ${platform}  ${assembly}
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${platform}
    Execute Command                 cpu AssembleBlock ${ASSEMBLY_ADDRESS} "${assembly}"
    Execute Command                 cpu PC ${ASSEMBLY_ADDRESS}

Expect Instructions Count
    [Arguments]                     ${expected_count}
    ${insn_count}=                  Execute Command  cpu ExecutedInstructions
    Should Be Equal As Numbers      ${insn_count}  ${expected_count}

Expect PC
    [Arguments]                     ${expected_pc}
    ${pc}=                          Execute Command  cpu PC
    Should Be Equal As Numbers      ${pc}  ${expected_pc}

Repeat String
    [Arguments]                     ${str}  ${count}
    ${rep_str}                      Set Variable  ${EMPTY}
    FOR  ${i}  IN RANGE  0  ${count}
        ${rep_str}=                 Catenate  SEPARATOR=${EMPTY}  ${rep_str}  ${str}
    END
    [return]                        ${rep_str}

Generate Single Opcode Assembly Block
    [Arguments]                     ${opcode}  ${preceeding_nops}  ${following_nops}
    ${start_nops}=                  Repeat String  nop;  ${preceeding_nops}
    ${end_nops}=                    Repeat String  nop;  ${following_nops}
    ${assembly}=                    Catenate  ${start_nops}  ${opcode}  ${end_nops}
    [return]                        ${assembly}
    
Execute Instructions
    [Arguments]                     ${instructions_count}
    Execute Command                 sysbus.cpu PerformanceInMips 1
    ${instructions_count_length}    Get Length  ${instructions_count}
    ${nr_of_preceeding_zeros}=      Evaluate  ${6} - ${instructions_count_length}
    ${preceeding_zeros}=            Repeat String  0  ${nr_of_preceeding_zeros}
    ${interval}=                    Catenate  SEPARATOR=${EMPTY}  0.  ${preceeding_zeros}  ${instructions_count}
    Execute Command                 emulation RunFor "${interval}"

*** Test Cases ***
Should Have Correct Instructions Count On Translation Block End
    ${assembly}=                    Generate Single Opcode Assembly Block  ${EMPTY}  10  0
    Create Platform                 ${ARM_PLATFORM}  ${assembly}
    Execute Command                 cpu MaximumBlockSize 7
    Execute Command                 sysbus.cpu SetHookAtBlockEnd ${BLOCK_END_HOOK}
    Create Log Tester               1
    Wait For Log Entry              BlockEnd Hook: Executed 7 Instructions  pauseEmulation=true

Should Have Correct Instructions Count After Multiple Translation Blocks
    ${assembly}=                    Generate Single Opcode Assembly Block  bl -0x24;  9  0
    Create Platform                 ${ARM_PLATFORM}  ${assembly}
    Execute Command                 sysbus.cpu SetHookAtBlockEnd "cpu.Log(LogLevel.Info, 'BlockEnd hook at PC: {} with {} executed instructions'.format(cpu.PC, cpu.ExecutedInstructions))"
    Create Log Tester               1
    Execute Instructions            100
    FOR  ${i}  IN RANGE  10
        Wait For Log Entry              BlockEnd hook at PC: 0x0 with ${i * 10} executed instructions   timeout=0
    END

Should Have Correct Instructions Count On Execute Instructions
    ${assembly}=                    Generate Single Opcode Assembly Block  ${EMPTY}  10  0
    Create Platform                 ${ARM_PLATFORM}  ${assembly}
    Execute Instructions            8
    Expect Instructions Count       8

Should Have Correct Instructions Count On WFI
    ${assembly}=                    Generate Single Opcode Assembly Block  wfi;  3  0
    Create Platform                 ${ARM_PLATFORM}  ${assembly}
    Execute Command                 cpu AddHookAtWfiStateChange 'self.Log(LogLevel.Info, "ENTER WFI - instructions count = {}".format(self.ExecutedInstructions))'
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              ENTER WFI - instructions count = 4  pauseEmulation=true

Should Have Correct Instructions Count On MMU External Fault
    ${assembly}=                    Generate Single Opcode Assembly Block  lw a1, 0(a0);  4  0
    Create Platform                 ${RISCV_PLATFORM}  ${assembly}
    Execute Command                 cpu EnableExternalWindowMmu true
    Execute Command                 cpu SetRegister ${a0} 0x100000
    Create Log Tester               1
    Wait For Log Entry              MMU fault - the address 0x100000 is not specified in any of the existing ranges
    Expect Instructions Count       5

Should Have Correct Instructions Count On Read Watchpoint
    ${assembly}=                    Generate Single Opcode Assembly Block  ldrb w0, [x1];  7  4
    Create Platform                 ${ARM_PLATFORM}  ${assembly}
    Execute Command                 sysbus.cpu SetRegister ${x1} ${WATCHPOINT_ADDRESS}

    Execute Command                 sysbus AddWatchpointHook ${WATCHPOINT_ADDRESS} 1 Read "cpu.Log(LogLevel.Info, 'Watchpoint hook at PC: {}'.format(cpu.PC))"
    Execute Command                 sysbus.cpu SetHookAtBlockBegin "cpu.Log(LogLevel.Info, 'BlockBegin hook at PC: {} with {} executed instructions'.format(cpu.PC, cpu.ExecutedInstructions))"

    Create Log Tester               0
    Expect Instructions Count       0

    Execute Instructions            12

    # This log's PC is set to 0x0 instead of 0x1c because of bug in updating PC in arm64 arch.
    # This should be changed after PC update fix.
    Wait For Log Entry              Watchpoint hook at PC: 0x0  timeout=0
    Wait For Log Entry              BlockBegin hook at PC: 0x1c with 7 executed instructions

    Should Not Be In Log            Watchpoint hook
    Should Not Be In Log            BlockBegin hook

    Expect PC                       0x30
    Expect Instructions Count       12

Should Have Correct Instructions Count On Uart Access
    ${assembly}=                    Generate Single Opcode Assembly Block  strb w0, [x1];  7  4
    Create Platform                 ${ARM_PLATFORM}  ${assembly}
    Create Terminal Tester          sysbus.uart

    Execute Command                 sysbus.cpu SetRegister ${w0} ${X_CHAR}
    Execute Command                 sysbus.cpu SetRegister ${x1} ${ARM_UART_DATA_ADDRESS}

    Wait For Prompt On Uart         x  pauseEmulation=true

    Expect PC                       0x20
    Expect Instructions Count       8
