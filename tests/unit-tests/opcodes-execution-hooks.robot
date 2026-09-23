*** Variables ***
${PLATFORM}                         SEPARATOR=\n
...                                 """
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x1000
...
...                                 nvic: IRQControllers.NVIC @ sysbus 0xE000E000
...                                 ${SPACE*4}-> cpu@0
...
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m33"
...                                 ${SPACE*4}nvic: nvic
...                                 """

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 using sysbus
    Execute Command                 cpu PC 0
    Create Log Tester               timeout=0

Create Opcode Execution Hooks
    [Arguments]  ${opcode}

    # For a 32-bit opcode, both hooks must see the whole instruction word,
    # not just its first halfword.
    Execute Python                  hook = lambda name: lambda pc, op: self.Machine.InfoLog("%s: PC %#010x op %#010x" % (name, pc, op))
    Execute Python                  self.Machine["sysbus.cpu"].AddPreOpcodeExecutionHook(0xFFFFFFFF, ${opcode}, hook("pre"))
    Execute Python                  self.Machine["sysbus.cpu"].AddPostOpcodeExecutionHook(0xFFFFFFFF, ${opcode}, hook("post"))
    # A hook matching a different opcode (in the case of a 16-bit opcode, one with
    # something in the high word) must not fire.
    Execute Python                  self.Machine["sysbus.cpu"].AddPostOpcodeExecutionHook(0xFFFFFFFF, ${opcode} + (1 << 16), hook("unexpected"))

*** Test Cases ***
Should Pass 32-Bit Thumb Opcode To Pre And Post Execution Hooks
    Create Machine
    # `movw` is a 32-bit Thumb instruction, encoded as its first halfword (at 0x0) in the
    # upper 16 bits of the instruction word and its second halfword (at 0x2) in the lower
    # lower 16 bits.
    Execute Command                 cpu AssembleBlock 0x0 "movw r0, #0x1234"
    ${opcode}=                      Set Variable  0xf2412034

    Create Opcode Execution Hooks   ${opcode}

    Execute Command                 cpu Step
    PC Should Be Equal              0x4

    Wait For Log Entry              pre: PC 0x00000000 op ${opcode}
    Wait For Log Entry              post: PC 0x00000000 op ${opcode}
    Should Not Be In Log            unexpected: PC 0x00000000

Should Pass 16-Bit Thumb Opcode To Pre And Post Execution Hooks
    Create Machine
    # A 16-bit Thumb instruction is reported as its zero-extended encoding.
    Execute Command                 cpu AssembleBlock 0x0 "nop"
    ${opcode}=                      Set Variable  0x0000bf00

    Create Opcode Execution Hooks   ${opcode}

    Execute Command                 cpu Step
    PC Should Be Equal              0x2

    Wait For Log Entry              pre: PC 0x00000000 op ${opcode}
    Wait For Log Entry              post: PC 0x00000000 op ${opcode}
    Should Not Be In Log            unexpected: PC 0x00000000
