*** Variables ***
${RESET}                                0x100
${NMI}                                  0x200

${CONDITION_ASM}                        SEPARATOR=\n
...  """
...    mov r6, #0b01111111
...    cmp r6, #0b10000001  // Should set: Z=0, N=1, C=0, V=0
...    cmp r6, #0b01111111  // Should set: Z=1, N=0, C=1, V=0
...    cmp r6, #0b01111110  // Should set: Z=0, N=0, C=1, V=0
...    mov r1, #1
...    lsl r2, r1, #31
...    adds r2, r2, r2       // Should set: Z=1, N=0, C=1, V=1
...  """

${ITSTATE_ASM}                          SEPARATOR=\n
...  """
...    mov r0, #6
...    bl comps
...
...    mov r0, #7
...    bl comps
...
...  comps:
...    cmp r0, #6           // Comments are for the first call, second call is inverted
...    ittet eq
...    moveq r1, #1         // Executes
...    moveq r2, #2         // Executes
...    movne r3, #3         // Doesn't execute
...    moveq r4, #4         // Executes
...
...    iteet gt
...    movgt r1, #5         // Executes
...    movle r2, #6         // Doesn't execute
...    movle r3, #7         // Doesn't execute
...    movgt r4, #8         // Executes
...
...    mov r1, #0
...    mov r2, #0
...    mov r3, #0
...    mov r4, #0
...    bx lr
...  """

${ITSTATE_IRQ_ASM}                      SEPARATOR=\n
...  """
...    nop
...    bx lr
...  """

${ITSTATE_INSIDE_ASM}                   SEPARATOR=\n
...  """
...    mov r0, #42
...    cmp r0, r0
...    ittet eq
...    cmpeq r0, #67         // Executes, changes flag to 0
...    moveq r2, #2          // Doesn't execute
...    cmpne r0, #42         // Executes, changes flag to 1
...    moveq r4, #4          // Executes
...  """

# IT_state Bits:
#     Name  | IT_cond | a | b | c | d | e |
#     Bits  |   7-5   | 4 | 3 | 2 | 1 | 0 |
#   The a, b, c, d, and e bits encode the number of instructions that are to be conditionally executed, and whether the condition for each is the base condition code or the inverse of the base condition code. They must contain b00000 when no IT block is active. Value of one means instruction should be skipped.

#   When an IT instruction is executed, these bits are set according to the condition in the instruction, and the Then and Else (T and E) parameters in the instruction.
#   During execution of an IT block, the a, b, c, d, and e bits are shifted left after every instruction:
#    - to reduce the number of instructions to be conditionally executed by one
#    - to move the next bit into position `a` basing on whichi the cpu decides if instruction should be executed.
# IT_cond:
#   To encode condition on 3 bits we omit last bit which always means reversing the condition, and negate abcde bits if neccessary.
#   For example: ITTET GT is encoded as IT_COND = 0b110 and abcde= 0b00101
#                ITTET LE is encoded as IT_COND = 0b110 and abcde= 0b11011
#   Bit denoting end of sequence always equals 1.

*** Keywords ***
Create Machine
    [Arguments]                         ${reset_asm}  ${nmi_asm}="b ."

    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescriptionFromString "cpu: CPU.CortexM @ sysbus { cpuType: \\"cortex-m4\\"; nvic: nvic }; nvic: IRQControllers.NVIC @ sysbus 0xE000E000 { systickFrequency: 72000000; IRQ -> cpu@0 }"
    Execute Command                     machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0 { size: 0x1000 }"
    Execute Command                     cpu MaximumBlockSize 1
    Execute Command                     cpu PerformanceInMips 125

    Execute Command                     sysbus WriteDoubleWord 0x0 0x800  # SP
    Execute Command                     sysbus WriteDoubleWord 0x4 ${{${RESET} | 1}}
    Execute Command                     cpu AssembleBlock ${RESET} ${reset_asm}
    Execute Command                     sysbus WriteDoubleWord 0x8 ${{${NMI} | 1}}
    Execute Command                     cpu AssembleBlock ${NMI} ${nmi_asm}

It State Should Be Equal
    [Arguments]                         ${state}
    ${it}=  Execute Command             cpu GetItState
    Should Be Equal As Integers         ${it}  ${state}

Condition Code Should Be Equal
    [Arguments]                         ${code}  ${state}

    ${eq}=  Execute Command             cpu EvaluateConditionCode ${code}
    # Checking for boolean equality
    Should Be Equal                     ${{${eq}}}  ${{${state}}}

Next It Instruction Should Execute
    [Arguments]                         ${state}
    ${it}=  Execute Command             cpu GetItState
    ${next}=  Execute Command           cpu WillNextItInstructionExecute ${it}
    Should Be Equal                     ${{${next}}}  ${{${state}}}

*** Test Cases ***
Should Evaluate Condition Codes Properly
    Create Machine                      ${CONDITION_ASM}

    Execute Command                     cpu Step 2  # After CMP 125, 127
    Condition Code Should Be Equal      0  False   # EQ
    Condition Code Should Be Equal      2  False   # CS
    Condition Code Should Be Equal      4  True    # MI
    Condition Code Should Be Equal      6  False   # VS
    Condition Code Should Be Equal      8  False   # HI
    Condition Code Should Be Equal      10  False  # GE
    Condition Code Should Be Equal      12  False  # GT
    Condition Code Should Be Equal      14  True   # AL

    # Flags: Z=0, N=1, C=0, V=0, T=1
    Register Should Be Equal            cpsr  0x81000000

    Execute Command                     cpu Step 1  # After CMP 125,125
    Condition Code Should Be Equal      0   True   # EQ
    Condition Code Should Be Equal      2   True   # CS
    Condition Code Should Be Equal      4   False  # MI
    Condition Code Should Be Equal      6   False  # VS
    Condition Code Should Be Equal      8   False  # HI
    Condition Code Should Be Equal      10  True   # GE
    Condition Code Should Be Equal      12  False  # GT
    Condition Code Should Be Equal      14  True   # AL

    # Flags: Z=1, N=0, C=1, V=0, T=1
    Register Should Be Equal            cpsr  0x61000000

    Execute Command                     cpu Step 1  # After CMP 125,124
    Condition Code Should Be Equal      0   False  # EQ
    Condition Code Should Be Equal      2   True   # CS
    Condition Code Should Be Equal      4   False  # MI
    Condition Code Should Be Equal      6   False  # VS
    Condition Code Should Be Equal      8   True   # HI
    Condition Code Should Be Equal      10  True   # GE
    Condition Code Should Be Equal      12  True   # GT
    Condition Code Should Be Equal      14  True   # AL

    # Flags: Z=0, N=0, C=1, V=0, T=1
    Register Should Be Equal            cpsr  0x21000000

    Execute Command                     cpu Step 3  # After ADD 2^31, 2^31
    Condition Code Should Be Equal      0   True   # EQ
    Condition Code Should Be Equal      2   True   # CS
    Condition Code Should Be Equal      4   False  # MI
    Condition Code Should Be Equal      6   True   # VS
    Condition Code Should Be Equal      8   False  # HI
    Condition Code Should Be Equal      10  False  # GE
    Condition Code Should Be Equal      12  False  # GT
    Condition Code Should Be Equal      14  True   # AL

    # Flags: Z=1, N=0, C=1, V=1, T=1
    Register Should Be Equal            cpsr  0x71000000

Should Have Correct Condition Code
    Create Machine                      ${ITSTATE_ASM}

    Execute Command                     cpu Step 9
    It State Should Be Equal            0xCD  # IT_cond = 0b101; abcde bits = 0b0101

Should Shift State Bits After Every IT Block Instruction
    Create Machine      ${ITSTATE_ASM}

    Execute Command                     cpu Step 4
    It State Should Be Equal            0x05  # IT_cond = 0b000; abcde bits = 0b00101
    Next It Instruction Should Execute  True

    Execute Command                     cpu Step
    It State Should Be Equal            0x0A  # IT_cond = 0b000; abcde bits = 0b01010
    Next It Instruction Should Execute  True

    Execute Command                     cpu Step
    It State Should Be Equal            0x14  # IT_cond = 0b000; abcde bits = 0b10100
    Next It Instruction Should Execute  False

    Execute Command                     cpu Step
    It State Should Be Equal            0x08  # IT_cond = 0b000; abcde bits = 0b01000
    Next It Instruction Should Execute  True

    Execute Command                     cpu Step
    It State Should Be Equal            0x00  # IT_cond = 0b000; abcde bits = 0b00000

Should Execute Only 'Then' Instructions
    Create Machine                      ${ITSTATE_ASM}

    Execute Command                     cpu Step 8   # After cmp 6, 6; ittet eq
    Register Should Be Equal            r1  0x1
    Register Should Be Equal            r2  0x2
    Register Should Be Equal            r3  0x0
    Register Should Be Equal            r4  0x4
    Execute Command                     cpu Step 5   # After cmp 6, 6; iteet gt
    Register Should Be Equal            r1  0x1
    Register Should Be Equal            r2  0x6
    Register Should Be Equal            r3  0x7
    Register Should Be Equal            r4  0x4
    Execute Command                     cpu Step 13  # After cmp 7, 6; ittet eq
    Register Should Be Equal            r1  0x0
    Register Should Be Equal            r2  0x0
    Register Should Be Equal            r3  0x3
    Register Should Be Equal            r4  0x0
    Execute Command                     cpu Step 5   # After cmp 7, 6; iteet gt
    Register Should Be Equal            r1  0x5
    Register Should Be Equal            r2  0x0
    Register Should Be Equal            r3  0x3
    Register Should Be Equal            r4  0x8

Should Save and Restore State of IT Block Correctly
    Create Machine            ${ITSTATE_ASM}

    Execute Command                     cpu Step 4
    ${old}=  Execute Command            cpu GetItState

    ${tmp_file}=  Allocate Temporary File
    Execute Command                     Save @${tmp_file}
    Execute Command                     Load @${tmp_file}
    Execute Command                     mach set 0

    It State Should Be Equal            ${old}

    Execute Command                     cpu Step 4
    Register Should Be Equal            r1  0x1
    Register Should Be Equal            r2  0x2
    Register Should Be Equal            r3  0x0
    Register Should Be Equal            r4  0x4

Should Survive Interrupt
    Create Machine                      ${ITSTATE_ASM}  ${ITSTATE_IRQ_ASM}

    Execute Command                     cpu Step 4

    Execute Command                     nvic SetPendingIRQ 2
    Execute Command                     cpu Step
    PC Should Be Equal                  ${{${NMI} + 2}}
    It State Should Be Equal            0x00

    Execute Command                     cpu Step 1  # exit interrupt
    It State Should Be Equal            0x05
    Execute Command                     cpu Step 4

    Register Should Be Equal            r1  0x1
    Register Should Be Equal            r2  0x2
    Register Should Be Equal            r3  0x0
    Register Should Be Equal            r4  0x4

Should Allow Condition Flag Change From Inside IT Block
    Create Machine                      ${ITSTATE_INSIDE_ASM}

    Execute Command                     cpu Step 3  # Inside It block; Before executing cmpeq  r6, #7
    Condition Code Should Be Equal      0  True
    Execute Command                     cpu Step 1  # Before executing moveq r2, #2
    Condition Code Should Be Equal      0  False
    Execute Command                     cpu Step 1  # Before executing cmpne r6, #6
    Condition Code Should Be Equal      0  False
    Execute Command                     cpu Step 1  # Before executing moveq r4, #4
    Condition Code Should Be Equal      0  True
    Execute Command                     cpu Step 1

    Register Should Be Equal            r0  42
    Register Should Be Equal            r1  0
    Register Should Be Equal            r2  0
    Register Should Be Equal            r3  0
    Register Should Be Equal            r4  4


Should Work in BlockBeginHooks
    Create Machine                      ${ITSTATE_ASM}
    Create Log Tester                   3

    # Value returned in block begin concerns first instruction in current block

    Execute Command                     cpu Step 3
    Execute Command                     cpu SetHookAtBlockBegin "self.DebugLog('PC '+ str(self.PC) + ';IT_state ' + hex(self.GetItState()).rstrip('L'))"
    Execute Command                     logLevel 0
    Execute Command                     cpu Step
    Wait For Log Entry                  Checking IT_STATE, while not in IT block
    Wait For Log Entry                  PC 0x112;IT_state 0x0
    Execute Command                     cpu Step
    Wait For Log Entry                  PC 0x114;IT_state 0x5
    Execute Command                     cpu Step
    Wait For Log Entry                  PC 0x116;IT_state 0xa
    Execute Command                     cpu Step
    Wait For Log Entry                  PC 0x118;IT_state 0x14
    Execute Command                     cpu Step
    Wait For Log Entry                  PC 0x11a;IT_state 0x8
    Execute Command                     cpu Step
    Wait For Log Entry                  Checking IT_STATE, while not in IT block
    Wait For Log Entry                  PC 0x11c;IT_state 0x0

Should Work in BlockEndHooks
    Create Machine                      ${ITSTATE_ASM}  # PC = 0x100
    Create Log Tester                   3

    # In BlockEnd both PC and It_status concerns first instruction of next block

    Execute Command                     cpu Step 3      # PC = 0x108
    Execute Command                     cpu SetHookAtBlockEnd "self.DebugLog('PC '+ str(self.PC) + ';IT_state ' + hex(self.GetItState()).rstrip('L'))"
    Execute Command                     logLevel 0
    Execute Command                     cpu Step        # PC = 0x112
    Wait For Log Entry                  PC 0x114;IT_state 0x5
    Execute Command                     cpu Step
    Wait For Log Entry                  PC 0x116;IT_state 0xa
    Execute Command                     cpu Step
    Wait For Log Entry                  PC 0x118;IT_state 0x14
    Execute Command                     cpu Step
    Wait For Log Entry                  PC 0x11a;IT_state 0x8
    Execute Command                     cpu Step
    Wait For Log Entry                  Checking IT_STATE, while not in IT block
    Wait For Log Entry                  PC 0x11c;IT_state 0x0
