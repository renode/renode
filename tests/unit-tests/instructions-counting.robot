*** Variables ***
${a0}                               0xA
${r0}                               0x0
${r1}                               0x1
${ASSEMBLY_ADDRESS}                 0x0
${X_CHAR}                           120
${ARM_UART_DATA_ADDRESS}            0x2000
${WATCHPOINT_ADDRESS}               0x100
${ARM_PLATFORM}                     SEPARATOR=\n
...                                 """
...                                 cpu: CPU.ARMv7A @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-a9"
...
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x1000
...
...                                 uart: UART.TrivialUart @ sysbus 0x2000
...                                 """
${ARM64_PLATFORM}                   SEPARATOR=\n
...                                 """
...                                 cpu: CPU.ARMv8A @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-a53"
...                                 ${SPACE*4}genericInterruptController: gic
...
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x1000
...
...                                 gic: IRQControllers.ARM_GenericInterruptController @ {
...                                 ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x8000000; size: 0x010000; region: "distributor" };
...                                 ${SPACE*8}sysbus new Bus.BusMultiRegistration { address: 0x8010000; size: 0x010000; region: "cpuInterface" }
...                                 ${SPACE*4}}
...                                 ${SPACE*4}\[0-1\] -> cpu@\[0-1\]
...                                 ${SPACE*4}architectureVersion: .GICv2
...                                 ${SPACE*4}supportsTwoSecurityStates: true
...                                 """
${RISCV_PLATFORM}                   SEPARATOR=\n
...                                 """
...                                 cpu: CPU.RiscV32 @ sysbus
...                                 ${SPACE*4}timeProvider: clint
...                                 ${SPACE*4}cpuType: "rv32gc"
...
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x100000
...
...                                 clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000
...                                 ${SPACE*4}frequency: 66000000
...                                 """

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
    ${rep_str}=                     Set Variable  ${EMPTY}
    FOR  ${i}  IN RANGE  0  ${count}
        ${rep_str}=                     Catenate  SEPARATOR=${EMPTY}  ${rep_str}  ${str}
    END
    [return]                        ${rep_str}

Surround Assembly Block With Nops
    [Arguments]                     ${inner_assembly}  ${preceeding_nops}  ${following_nops}
    ${start_nops}=                  Repeat String  nop;  ${preceeding_nops}
    ${end_nops}=                    Repeat String  nop;  ${following_nops}
    ${assembly}=                    Catenate  SEPARATOR=${EMPTY}  ${start_nops}  ${inner_assembly}  ${end_nops}
    [return]                        ${assembly}

Execute Instructions
    [Arguments]                     ${instructions_count}
    ${time_interval}=               evaluate  ${instructions_count} / 1000000
    ${time_interval}=               Format String  {0:.6f}  ${time_interval}
    Execute Command                 sysbus.cpu PerformanceInMips 1
    Execute Command                 emulation RunFor "${time_interval}"

*** Test Cases ***
Should Have Correct Instructions Count On Translation Block End
    [Tags]                          instructions_counting
    ${assembly}=                    Surround Assembly Block With Nops  ${EMPTY}  10  0
    Create Platform                 ${ARM64_PLATFORM}  ${assembly}
    Execute Command                 cpu MaximumBlockSize 7
    Execute Command                 sysbus.cpu SetHookAtBlockEnd "cpu.Log(LogLevel.Info, 'BlockEnd Hook: Executed {0} Instructions', cpu.ExecutedInstructions)"
    Create Log Tester               1
    Wait For Log Entry              BlockEnd Hook: Executed 7 Instructions  pauseEmulation=true

Should Have Correct Instructions Count After Multiple Translation Blocks
    [Tags]                          instructions_counting
    ${assembly}=                    Surround Assembly Block With Nops  bl -0x24;  9  0
    Create Platform                 ${ARM64_PLATFORM}  ${assembly}
    Execute Command                 sysbus.cpu SetHookAtBlockEnd "cpu.Log(LogLevel.Info, 'BlockEnd hook at PC: {} with {} executed instructions'.format(cpu.PC, cpu.ExecutedInstructions))"
    Create Log Tester               1
    Execute Instructions            100
    FOR  ${i}  IN RANGE  1  10
        Wait For Log Entry              BlockEnd hook at PC: 0x0 with ${i * 10} executed instructions  timeout=0
    END

Should Have Correct Instructions Count On Execute Instructions
    [Tags]                          instructions_counting
    ${assembly}=                    Surround Assembly Block With Nops  ${EMPTY}  10  0
    Create Platform                 ${ARM64_PLATFORM}  ${assembly}
    Execute Instructions            8
    Expect Instructions Count       8

Should Have Correct Instructions Count On WFI
    [Tags]                          instructions_counting
    ${assembly}=                    Surround Assembly Block With Nops  wfi;  3  0
    Create Platform                 ${ARM64_PLATFORM}  ${assembly}
    Execute Command                 cpu AddHookAtWfiStateChange 'self.Log(LogLevel.Info, "ENTER WFI - instructions count = {}".format(self.ExecutedInstructions))'
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              ENTER WFI - instructions count = 4  pauseEmulation=true

Should Have Correct Instructions Count On MMU External Fault
    [Tags]                          instructions_counting
    ${assembly}=                    Surround Assembly Block With Nops  lw a1, 0(a0);  4  4
    Create Platform                 ${RISCV_PLATFORM}  ${assembly}
    Execute Command                 cpu EnableExternalWindowMmu true
    Execute Command                 cpu SetRegister ${a0} 0x100000
    Create Log Tester               1
    Wait For Log Entry              MMU fault - the address 0x100000 is not specified in any of the existing ranges
    Expect Instructions Count       5

Should Have Correct Instructions Count On Read Watchpoint
    [Tags]                          instructions_counting
    ${assembly}=                    Surround Assembly Block With Nops  ldrb r0, [r1];  7  4
    Create Platform                 ${ARM_PLATFORM}  ${assembly}
    Execute Command                 sysbus.cpu SetRegister ${r1} ${WATCHPOINT_ADDRESS}

    Execute Command                 sysbus AddWatchpointHook ${WATCHPOINT_ADDRESS} 1 Read "cpu.Log(LogLevel.Info, 'Watchpoint hook at PC: {}'.format(cpu.PC))"
    Execute Command                 sysbus.cpu SetHookAtBlockBegin "cpu.Log(LogLevel.Info, 'BlockBegin hook at PC: {} with {} executed instructions'.format(cpu.PC, cpu.ExecutedInstructions))"

    Create Log Tester               0
    Expect Instructions Count       0

    Execute Instructions            12

    Wait For Log Entry              Watchpoint hook at PC: 0x1c  timeout=0
    Wait For Log Entry              BlockBegin hook at PC: 0x1c with 7 executed instructions  timeout=0

    Should Not Be In Log            Watchpoint hook
    Should Not Be In Log            BlockBegin hook

    Expect PC                       0x30
    Expect Instructions Count       12

Should Have Correct Instructions Count On Uart Access
    [Tags]                          instructions_counting
    ${assembly}=                    Surround Assembly Block With Nops  strb r0, [r1];  7  4
    Create Platform                 ${ARM_PLATFORM}  ${assembly}
    Create Terminal Tester          sysbus.uart

    Execute Command                 sysbus.cpu SetRegister ${r0} ${X_CHAR}
    Execute Command                 sysbus.cpu SetRegister ${r1} ${ARM_UART_DATA_ADDRESS}

    Wait For Prompt On Uart         x  pauseEmulation=true

    Expect PC                       0x20
    Expect Instructions Count       8
