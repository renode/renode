*** Comments ***

ARM IT test.
  The IT (If-Then) instruction makes up to four following instructions (the IT block) conditional.
  The conditions can be all the same, or some of them can be the logical inverse of the others.
  Syntax
    IT{x{y{z}}} {cond}
  where:
    x - specifies the condition switch for the second instruction in the IT block.
    y - specifies the condition switch for the third instruction in the IT block.
    z - specifies the condition switch for the fourth instruction in the IT block.
    cond - specifies the condition for the first instruction in the IT block.
  The condition switch for the second, third and fourth instruction in the IT block can be either:
    T - Then. Applies the condition cond to the instruction.
    E - Else. Applies the inverse condition of cond to the instruction.
Test ELF EvaluateConditionCode:
    .text
    .global _start
    _start:
        .thumb

        MOV r6, #0b01111111
        CMP r6, #0b10000001  /* Should set: Z=0, C=0, N=1, V=0 */
        CMP r6, #0b01111111  /* Should set: Z=1, C=1, N=0, V=0 */
        CMP r6, #0b01111110  /* Should set: Z=0, C=1, N=0, V=0 */
        MOV r1, #1
        LSL r2, r1, #31
        ADD r2, r2, r2       /* Should set: Z=1, C=1, N=0, V=1 */

Test ELF ITStatus:
    .irq:
        .arm
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        .word 0x80000D3     /* IRQ 16 jump address */
    .text
    .global _start
    _start:
        .thumb

        CPSIE I
        MOV r6, #6          /* Sets value to r6 */
        CMP r6, #6          /* Compares register value to imm */

        /* Use of '.inst' is caused by gcc bug : https://bugs.launchpad.net/gcc-arm-embedded/+bug/1620025 */
        ITTET EQ
        .inst 0x2101        /* MOV r1, #1 ; executes */
        .inst 0x2202        /* MOV r2, #2 ; executes */
        .inst 0x2303        /* MOV r3, #3 ; does not execute */
        .inst 0x2404        /* MOV r4, #4 ; executes */

        LDR r5,  =0x20000000 /* Sets address to store register values */
        STR r1, [r5]         /* Store register r1 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r2, [r5]         /* Store register r2 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r3, [r5]         /* Store register r3 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r4, [r5]         /* Store register r4 value */

        MOV r1, #0           /* Clear registers */
        MOV r2, #0
        MOV r3, #0
        MOV r4, #0

        CMP r6, #7

        ITEET GE
        .inst 0x2101        /* MOV r1, #1 ; does not execute */
        .inst 0x2202        /* MOV r2, #2 ; executes */
        .inst 0x2303        /* MOV r3, #3 ; executes */
        .inst 0x2404        /* MOV r4, #4 ; does not execute*/

        ADD r5, r5, #4
        STR r1, [r5]
        ADD r5, r5, #4
        STR r2, [r5]
        ADD r5, r5, #4
        STR r3, [r5]
        ADD r5, r5, #4
        STR r4, [r5]

    /* Same tests but conditions unmet */

        MOV r1, #0           /* Clear registers */
        MOV r2, #0
        MOV r3, #0
        MOV r4, #0

        CMP r6, #7          /* Compares register value to imm */

        /* Use of '.inst' is caused by gcc bug : https://bugs.launchpad.net/gcc-arm-embedded/+bug/1620025 */
        ITTET EQ
        .inst 0x2101        /* MOV r1, #1 ; executes */
        .inst 0x2202        /* MOV r2, #2 ; executes */
        .inst 0x2303        /* MOV r3, #3 ; does not execute */
        .inst 0x2404        /* MOV r4, #4 ; executes */

        ADD r5, r5, #4       /* Add 4 to address */
        STR r1, [r5]         /* Store register r1 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r2, [r5]         /* Store register r2 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r3, [r5]         /* Store register r3 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r4, [r5]         /* Store register r4 value */

        MOV r1, #0           /* Clear registers */
        MOV r2, #0
        MOV r3, #0
        MOV r4, #0

        CMP r6, #4

        ITEET GE
        .inst 0x2101        /* MOV r1, #1 ; does not execute */
        .inst 0x2202        /* MOV r2, #2 ; executes */
        .inst 0x2303        /* MOV r3, #3 ; executes */
        .inst 0x2404        /* MOV r4, #4 ; does not execute*/

        ADD r5, r5, #4
        STR r1, [r5]
        ADD r5, r5, #4
        STR r2, [r5]
        ADD r5, r5, #4
        STR r3, [r5]
        ADD r5, r5, #4
        STR r4, [r5]

        NOP
        ADD r1, r1, #1      /* IRQ 16 */
        ADD r1, r1, #2
        ADD r1, r1, #4
        MOVS PC, R14

    /* Check if using cmp inside IT block changes flow */

        MOV r1, #0  /* Clear registers */
        MOV r2, #0
        MOV r3, #0
        MOV r4, #0

        MOV r6, #6
        CMP r6, #6
        ITTET EQ
        .inst 0x2e07        /* CMP 6,7    ; executes, changes flags */
        .inst 0x2202        /* MOV r2, #2 ; does not execute */
        .inst 0x2e06        /* CMP 6,6    ; executes, changes flags */
        .inst 0x2404        /* MOV r4, #4 ; executes */

        LDR r5,  =0x20000000 /* Sets address to store register values */
        STR r1, [r5]         /* Store register r1 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r2, [r5]         /* Store register r2 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r3, [r5]         /* Store register r3 value */
        ADD r5, r5, #4       /* Add 4 to address */
        STR r4, [r5]         /* Store register r4 value */



IT_state Bits:
    Name  | IT_cond | a | b | c | d | e |
    Bits  |   7-5   | 4 | 3 | 2 | 1 | 0 |
  The a, b, c, d, and e bits encode the number of instructions that are to be conditionally executed, and whether the condition for each is the base condition code or the inverse of the base condition code. They must contain b00000 when no IT block is active. Value of one means instruction should be skipped.

  When an IT instruction is executed, these bits are set according to the condition in the instruction, and the Then and Else (T and E) parameters in the instruction.
  During execution of an IT block, the a, b, c, d, and e bits are shifted left after every instruction:
   - to reduce the number of instructions to be conditionally executed by one
   - to move the next bit into position `a` basing on whichi the cpu decides if instruction should be executed.
IT_cond:
  To encode condition on 3 bits we omit last bit which always means reversing the condition, and negate abcde bits if neccessary.
  For example: ITTET GT is encoded as IT_COND = 0b110 and abcde= 0b00101
               ITTET LE is encoded as IT_COND = 0b110 and abcde= 0b11011
  Bit denoting end of sequence always equals 1.


*** Settings ***
Library                ${CURDIR}/../gdb/gdb_library.py

*** Variables ***
${URI}                 @https://dl.antmicro.com/projects/renode
${ITSTATE_BIN}         arm-itte-block-test-s_66284-3482e7f2e0d8849841c6ca6cafbf03104d2c4a31
${CONDITION_BIN}       arm-itte-condition-codes-test-s_65976-6ec62f42daaf672789f066bceaf75dc1e7865e6e
${GDB_REMOTE_PORT}     3333
*** Keywords ***
Create Machine
            [Arguments]     ${elf}

            Execute Command     using sysbus
            Execute Command     mach create "STM32f4"
            Execute Command     machine LoadPlatformDescriptionFromString "cpu: CPU.CortexM @ sysbus { cpuType: \\"cortex-m4\\"; nvic: nvic }; nvic: IRQControllers.NVIC @ sysbus 0xE000E000 { systickFrequency: 72000000; IRQ -> cpu@0 }"
            Execute Command     machine LoadPlatformDescriptionFromString "flashuu: Memory.MappedMemory @ sysbus 0x08000000 { size: 0x200000 }"
            Execute Command     machine LoadPlatformDescriptionFromString "sram: Memory.MappedMemory @ sysbus 0x20000000 { size: 0x00040000 }"
            Execute Command     cpu MaximumBlockSize 1
            Execute Command     cpu PerformanceInMips 125

            Execute Command     sysbus LoadELF ${URI}/${elf}
            Execute Command     cpu PC 0x08000044
            Execute Command     cpu SP 0x08200000
            Execute Command     cpu ExecutionMode SingleStepBlocking

*** Test Cases ***
Should Return Corrrect IT_STATUS Value

            Create Machine      ${ITSTATE_BIN}

            Start Emulation
            Execute Command     cpu Step 4
    ${it}=  Execute Command     cpu GetItState
            Should Contain      ${it}   0x00000005      # IT_cond = 0b000; abcde bits = 0b00101

Should Have Correct Condition Code

            Create Machine      ${ITSTATE_BIN}

            Start Emulation
            Execute Command     cpu Step 22
    ${it}=  Execute Command     cpu GetItState
            Should Contain      ${it}   0x000000AD      # IT_cond = 0b101; abcde bits = 0b00101

Should Evaluate Condition Codes Properly

            Create Machine      ${CONDITION_BIN}

            Execute Command     cpu PC 0x8000000
            Start Emulation

  #Flags: Z=0, N=1, C=0, V=0
            Execute Command     cpu Step 2                      # After CMP 125, 127
  ${eq1}=   Execute Command     cpu EvaluateConditionCode 0  # EQ
            Should Contain      ${eq1}    False
  ${cs1}=   Execute Command     cpu EvaluateConditionCode 2  # CS
            Should Contain      ${cs1}    False
  ${mi1}=   Execute Command     cpu EvaluateConditionCode 4  # MI
            Should Contain      ${mi1}    True
  ${vs1}=   Execute Command     cpu EvaluateConditionCode 6  # VS
            Should Contain      ${vs1}    False
  ${hi1}=   Execute Command     cpu EvaluateConditionCode 8  # HI
            Should Contain      ${hi1}    False
  ${ge1}=   Execute Command     cpu EvaluateConditionCode 10  # GE
            Should Contain      ${ge1}    False
  ${gt1}=   Execute Command     cpu EvaluateConditionCode 12  # GT
            Should Contain      ${gt1}    False
  ${al1}=   Execute Command     cpu EvaluateConditionCode 14  # AL
            Should Contain      ${al1}    True

  #NZCV, T=1
            Register Should Be Equal  25  0x81000000

  #Flags: Z=1, N=0, C=1, V=0
            Execute Command     cpu Step 1                      # After CMP 125,125
  ${eq2}=   Execute Command     cpu EvaluateConditionCode 0  # EQ
            Should Contain      ${eq2}    True
  ${cs2}=   Execute Command     cpu EvaluateConditionCode 2  # CS
            Should Contain      ${cs2}    True
  ${mi2}=   Execute Command     cpu EvaluateConditionCode 4  # MI
            Should Contain      ${mi2}    False
  ${vs2}=   Execute Command     cpu EvaluateConditionCode 6  # VS
            Should Contain      ${vs2}    False
  ${hi2}=   Execute Command     cpu EvaluateConditionCode 8  # HI
            Should Contain      ${hi2}    False
  ${ge2}=   Execute Command     cpu EvaluateConditionCode 10  # GE
            Should Contain      ${ge2}    True
  ${gt2}=   Execute Command     cpu EvaluateConditionCode 12  # GT
            Should Contain      ${gt2}    False
  ${al2}=   Execute Command     cpu EvaluateConditionCode 14  # AL
            Should Contain      ${al2}    True

  #NZCV, T=1
            Register Should Be Equal  25  0x61000000

  #Flags: Z=0, N=0, C=1, V=0
            Execute Command     cpu Step 1                      # After CMP 125,124
  ${eq3}=   Execute Command     cpu EvaluateConditionCode 0  # EQ
            Should Contain      ${eq3}    False
  ${cs3}=   Execute Command     cpu EvaluateConditionCode 2  # CS
            Should Contain      ${cs3}    True
  ${mi3}=   Execute Command     cpu EvaluateConditionCode 4  # MI
            Should Contain      ${mi3}    False
  ${vs3}=   Execute Command     cpu EvaluateConditionCode 6  # VS
            Should Contain      ${vs3}    False
  ${hi3}=   Execute Command     cpu EvaluateConditionCode 8  # HI
            Should Contain      ${hi3}    True
  ${ge3}=   Execute Command     cpu EvaluateConditionCode 10  # GE
            Should Contain      ${ge3}    True
  ${gt3}=   Execute Command     cpu EvaluateConditionCode 12  # GT
            Should Contain      ${gt3}    True
  ${al3}=   Execute Command     cpu EvaluateConditionCode 14  # AL
            Should Contain      ${al3}    True

  #NZCV, T=1
            Register Should Be Equal  25  0x21000000

  #Flags: Z=1, N=0, C=1, V=1
            Execute Command     cpu Step 3                      # After ADD 2^31, 2^31
  ${eq4}=   Execute Command     cpu EvaluateConditionCode 0  # EQ
            Should Contain      ${eq4}    True
  ${cs4}=   Execute Command     cpu EvaluateConditionCode 2  # CS
            Should Contain      ${cs4}    True
  ${mi4}=   Execute Command     cpu EvaluateConditionCode 4  # MI
            Should Contain      ${mi4}    False
  ${vs4}=   Execute Command     cpu EvaluateConditionCode 6  # VS
            Should Contain      ${vs4}    True
  ${hi4}=   Execute Command     cpu EvaluateConditionCode 8  # HI
            Should Contain      ${hi4}    False
  ${ge4}=   Execute Command     cpu EvaluateConditionCode 10  # GE
            Should Contain      ${ge4}    False
  ${gt4}=   Execute Command     cpu EvaluateConditionCode 12  # GT
            Should Contain      ${gt4}    False
  ${al4}=   Execute Command     cpu EvaluateConditionCode 14  # AL
            Should Contain      ${al4}    True

  #NZCV, T=1
            Register Should Be Equal  25  0x71000000

Should Shift State Bits After Every IT Block Instruction

            Create Machine      ${ITSTATE_BIN}

            Start Emulation
            Execute Command     cpu Step 4
    ${it}=  Execute Command     cpu GetItState
  ${next}=  Execute Command     cpu WillNextItInstructionExecute ${it}
            Should Contain      ${it}   0x00000005      # IT_cond = 0b000; abcde bits = 0b00101
            Should Contain      ${next}     True

            Execute Command     cpu Step
    ${it}=  Execute Command     cpu GetItState
  ${next}=  Execute Command     cpu WillNextItInstructionExecute ${it}
            Should Contain      ${it}   0x0000000A      # IT_cond = 0b000; abcde bits = 0b01010
            Should Contain      ${next}     True

            Execute Command     cpu Step
    ${it}=  Execute Command     cpu GetItState
  ${next}=  Execute Command     cpu WillNextItInstructionExecute ${it}
            Should Contain      ${it}   0x00000014      # IT_cond = 0b000; abcde bits = 0b10100
            Should Contain      ${next}     False

            Execute Command     cpu Step
    ${it}=  Execute Command     cpu GetItState
  ${next}=  Execute Command     cpu WillNextItInstructionExecute ${it}
            Should Contain      ${it}   0x00000008      # IT_cond = 0b000; abcde bits = 0b01000
            Should Contain      ${next}     True

            Execute Command     cpu Step
    ${it}=  Execute Command     cpu GetItState
            Should Contain      ${it}   0x00000000      # IT_cond = 0b000; abcde bits = 0b00000

Should Execute Only 'Then' Instructions

            Create Machine      ${ITSTATE_BIN}

            Start Emulation
            Execute Command     cpu Step 16                 # After CMP 6, 6 ; ITTET EQ
    ${r1}=  Execute Command     sysbus ReadByte 0x20000000
    ${r2}=  Execute Command     sysbus ReadByte 0x20000004
    ${r3}=  Execute Command     sysbus ReadByte 0x20000008
    ${r4}=  Execute Command     sysbus ReadByte 0x2000000C
            Should Contain      ${r1}    0x01
            Should Contain      ${r2}    0x02
            Should Contain      ${r3}    0x00
            Should Contain      ${r4}    0x04
            Execute Command     cpu Step 18                 # After CMP 6, 7 ; ITEET GE
    ${r1}=  Execute Command     sysbus ReadByte 0x20000010
    ${r2}=  Execute Command     sysbus ReadByte 0x20000014
    ${r3}=  Execute Command     sysbus ReadByte 0x20000018
    ${r4}=  Execute Command     sysbus ReadByte 0x2000001C
            Should Contain      ${r1}    0x00
            Should Contain      ${r2}    0x02
            Should Contain      ${r3}    0x03
            Should Contain      ${r4}    0x00
            Execute Command     cpu Step 18                 # After CMP 6,7 ; ITTET EQ
    ${r1}=  Execute Command     sysbus ReadByte 0x20000020
    ${r2}=  Execute Command     sysbus ReadByte 0x20000024
    ${r3}=  Execute Command     sysbus ReadByte 0x20000028
    ${r4}=  Execute Command     sysbus ReadByte 0x2000002C
            Should Contain      ${r1}    0x00
            Should Contain      ${r2}    0x00
            Should Contain      ${r3}    0x03
            Should Contain      ${r4}    0x00
            Execute Command     cpu Step 18                 # After CMP 6,4 ; ITEET GE
    ${r1}=  Execute Command     sysbus ReadByte 0x20000030
    ${r2}=  Execute Command     sysbus ReadByte 0x20000034
    ${r3}=  Execute Command     sysbus ReadByte 0x20000038
    ${r4}=  Execute Command     sysbus ReadByte 0x2000003C
            Should Contain      ${r1}    0x01
            Should Contain      ${r2}    0x00
            Should Contain      ${r3}    0x00
            Should Contain      ${r4}    0x04

Should Save and Restore State of IT Block Correctly

           Create Machine      ${ITSTATE_BIN}

           Start Emulation
           Execute Command     cpu Step 5
  ${old}=  Execute Command     cpu GetItState

           ${tmp_file}=        Allocate Temporary File
           Execute Command     Save @${tmp_file}
           Execute Command     Load @${tmp_file}
           Execute Command     mach set 0

           Execute Command     cpu ExecutionMode SingleStepBlocking
           Start Emulation
  ${new}=  Execute Command     cpu GetItState
           Should Be Equal     ${old}  ${new}

           Execute Command     cpu Step
   ${it}=  Execute Command     cpu GetItState
           Should Contain      ${it}   0x00000014

           Execute Command     cpu Step
   ${it}=  Execute Command     cpu GetItState
           Should Contain      ${it}   0x00000008

           Execute Command     cpu Step 10
   ${r1}=  Execute Command     sysbus ReadByte 0x20000000
   ${r2}=  Execute Command     sysbus ReadByte 0x20000004
   ${r3}=  Execute Command     sysbus ReadByte 0x20000008
   ${r4}=  Execute Command     sysbus ReadByte 0x2000000C
           Should Contain      ${r1}    0x01
           Should Contain      ${r2}    0x02
           Should Contain      ${r3}    0x00
           Should Contain      ${r4}    0x04

Should Survive Interrupt

            Create Machine      ${ITSTATE_BIN}

            Execute Command     nvic WriteDoubleWord 0x100 0x01
            Start Emulation
            Execute Command     cpu Step 5

            Execute Command     nvic OnGPIO 0 true
            Execute Command     nvic OnGPIO 0 false
            Execute Command     cpu Step
   ${pc}=   Execute Command     cpu PC
            Should Contain      ${pc}   0x80000d4    # Check if in interrupt
   ${it}=   Execute Command     cpu GetItState
            Should Contain      ${it}    0x00
            Execute Command     cpu Step 4           # exit interrupt
   ${it}=   Execute Command     cpu GetItState
            Should Contain      ${it}   0x0000000A
            Execute Command     cpu Step 11


   ${r1}=   Execute Command     sysbus ReadByte 0x20000000
   ${r2}=   Execute Command     sysbus ReadByte 0x20000004
   ${r3}=   Execute Command     sysbus ReadByte 0x20000008
   ${r4}=   Execute Command     sysbus ReadByte 0x2000000C
            Should Contain      ${r1}    0x01
            Should Contain      ${r2}    0x02
            Should Contain      ${r3}    0x00
            Should Contain      ${r4}    0x04

Should Allow Condition Flag Change From Inside IT Block

            Create Machine      ${ITSTATE_BIN}
            Execute Command     cpu PC 0x080000dc
            Start Emulation

            Execute Command     cpu Step 7     # Inside It block; Before executing CMPEQ  r6,#7
  ${ev}=    Execute Command     cpu EvaluateConditionCode 0x00  # EQ
            Should Contain      ${ev}  True
            Execute Command     cpu Step 1                      # Before executing MOVEQ  r2,#2
  ${ev}=    Execute Command     cpu EvaluateConditionCode 0x00  # EQ
            Should Contain      ${ev}  False
            Execute Command     cpu Step 1                      # Before executing CMPNE  r6,#6
  ${ev}=    Execute Command     cpu EvaluateConditionCode 0x00  # EQ
            Should Contain      ${ev}  False
            Execute Command     cpu Step 1                      # Before executing MOVEQ  r4,#4
  ${ev}=    Execute Command     cpu EvaluateConditionCode 0x00  # EQ
            Should Contain      ${ev}  True
            ExecuteCommand      cpu Step 10
    ${r1}=  Execute Command     sysbus ReadByte 0x20000000
    ${r2}=  Execute Command     sysbus ReadByte 0x20000004
    ${r3}=  Execute Command     sysbus ReadByte 0x20000008
    ${r4}=  Execute Command     sysbus ReadByte 0x2000000C
            Should Contain      ${r1}    0x00
            Should Contain      ${r2}    0x00
            Should Contain      ${r3}    0x00
            Should Contain      ${r4}    0x04


Should Work in BlockBeginHooks
            # Value returned in block begin concerns first instruction in current block

            Create Machine      ${ITSTATE_BIN}
            Create Log Tester   5000

            Start Emulation
            Execute Command     cpu Step 3
            Execute Command     cpu SetHookAtBlockBegin "self.DebugLog('PC '+ str(self.PC) + ';IT_state ' + hex(self.GetItState()).rstrip('L'))"
            Execute Command     logLevel 0
            Execute Command     cpu Step
            Wait For Log Entry  Checking IT_STATE, while not in IT block
            Wait For Log Entry  PC 0x800004a;IT_state 0x0
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x800004c;IT_state 0x5
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x800004e;IT_state 0xa
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x8000050;IT_state 0x14
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x8000052;IT_state 0x8
            Execute Command     cpu Step
            Wait For Log Entry  Checking IT_STATE, while not in IT block
            Wait For Log Entry  PC 0x8000054;IT_state 0x0

Should Work in BlockEndHooks
            # In BlockEnd both PC and It_status concerns first instruction of next block

            Create Machine      ${ITSTATE_BIN}
            Create Log Tester   5000

            Start Emulation                     #PC = 0x8000044
            Execute Command     cpu Step 3      #PC = 0x8000048
            Execute Command     cpu SetHookAtBlockEnd "self.DebugLog('PC '+ str(self.PC) + ';IT_state ' + hex(self.GetItState()).rstrip('L'))"
            Execute Command     logLevel 0
            Execute Command     cpu Step        #PC = 0x800004a
            Wait For Log Entry  PC 0x800004c;IT_state 0x5
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x800004e;IT_state 0xa
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x8000050;IT_state 0x14
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x8000052;IT_state 0x8
            Execute Command     cpu Step
            Wait For Log Entry  Checking IT_STATE, while not in IT block
            Wait For Log Entry  PC 0x8000054;IT_state 0x0

