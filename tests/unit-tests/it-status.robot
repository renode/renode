/* ARM IT test.
 *   The IT (If-Then) instruction makes up to four following instructions (the IT block) conditional.
 *   The conditions can be all the same, or some of them can be the logical inverse of the others.
 *   Syntax
 *     IT{x{y{z}}} {cond}
 *   where:
 *     x - specifies the condition switch for the second instruction in the IT block.
 *     y - specifies the condition switch for the third instruction in the IT block.
 *     z - specifies the condition switch for the fourth instruction in the IT block.
 *     cond - specifies the condition for the first instruction in the IT block.
 *   The condition switch for the second, third and fourth instruction in the IT block can be either:
 *     T - Then. Applies the condition cond to the instruction.
 *     E - Else. Applies the inverse condition of cond to the instruction.
 *
 * Test ELF:
 *  08000000 <.irq>:
 *    .arm
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    NOP
 *    .inst 0xfffffff9        /* IRQ 16 jump address : set to 0xfffffff9 to make immediate interrupt_exit */
 *  08000044 <_start>:
 *    .thumb

 *    CPSIE I
 *    MOV r6, #6          /* Sets value to r6 */
 *    CMP r6, #6          /* Compares register value to imm */

 *    /* Use of '.inst' is cause by gcc bug : https://bugs.launchpad.net/gcc-arm-embedded/+bug/1620025 */
 *    ITTET EQ
 *    .inst 0x2101        /* MOV r1, #1 ; executes */
 *    .inst 0x2202        /* MOV r2, #2 ; executes */
 *    .inst 0x2303        /* MOV r3, #3 ; does not execute */
 *    .inst 0x2404        /* MOV r4, #4 ; executes */

 *    LDR r5,  =0x20000000 /* Sets address to store register values */
 *    STR r1, [r5]         /* Store register r1 value */
 *    ADD r5, r5, #4       /* Add 4 to address */
 *    STR r2, [r5]         /* Store register r2 value
 *    ADD r5, r5, #4       /* Add 4 to address */
 *    STR r3, [r5]         /* Store register r3 value */
 *    ADD r5, r5, #4       /* Add 4 to address */
 *    STR r4, [r5]         /* Store register r4 value */

 *    MOV r1, #0           /* Clear registers */
 *    MOV r2, #0
 *    MOV r3, #0
 *    MOV r4, #0

 *    CMP r6, #7

 *    ITEET GE
 *    .inst 0x2101        /* MOV r1, #1 ; does not execute */
 *    .inst 0x2202        /* MOV r2, #2 ; executes */
 *    .inst 0x2303        /* MOV r3, #3 ; executes */
 *    .inst 0x2404        /* MOV r4, #4 ; does not execute */

 *    ADD r5, r5, #4
 *    STR r1, [r5]
 *    ADD r5, r5, #4
 *    STR r2, [r5]
 *    ADD r5, r5, #4
 *    STR r3, [r5]
 *    ADD r5, r5, #4
 *    STR r4, [r5]
 *
 * IT_state Bits:
 *     Name  | IT_cond | a | b | c | d | e |
 *     Bits  |   7-5   | 4 | 3 | 2 | 1 | 0 |
 *   The a, b, c, d, and e bits encode the number of instructions that are to be conditionally executed, and whether the condition for each is the base condition code or the inverse of the base condition code. They must contain b00000 when no IT block is active. Value of one means instruction should be skipped
.
 *   When an IT instruction is executed, these bits are set according to the condition in the instruction, and the Then and Else (T and E) parameters in the instruction.
 *   During execution of an IT block, the a, b, c, d, and e bits are shifted left after every instruction:
 *    - to reduce the number of instructions to be conditionally executed by one
 *    - to move the next bit into position `a` basing on whichi the cpu decides if instruction should be executed.
 * IT_cond:
 *   To encode condition on 3 bits we omit last bit which always means reversing the condition, and negate abcde bits if neccessary.
 *   For example: ITTET GT is encoded as IT_COND = 0b110 and abcde= 0b00101
 *                ITTET LE is encoded as IT_COND = 0b110 and abcde= 0b11011
 *   Bit denoting end of sequence always equals 1.
 */

*** Settings ***
Suite Setup            Setup
Suite Teardown         Teardown
Test Teardown          Reset Emulation
Resource               ${RENODEKEYWORDS}
Library                ${CURDIR}/../gdb/gdb_library.py

*** Variables ***
${URI}                 @http://antmicro.com/projects/renode
${SIMPLE_BIN}          arm-itte-block-test-s_66144-8753989bf68af93314e5e774afcf60567cac0408
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

            Execute Command     sysbus LoadELF ${URI}/${SIMPLE_BIN}
            Execute Command     cpu PC 0x08000044
            Execute Command     cpu ExecutionMode SingleStep

*** Test Cases ***
Should Return Corrrect IT_STATUS Value

            Create Machine      ${SIMPLE_BIN}

            Start Emulation
            Execute Command     cpu Step 4
    ${it}=  Execute Command     cpu GetItState
            Should Contain      ${it}   0x00000005      # IT_cond = 0b000; abcde bits = 0b00101

Should Have Correct Condition Code

            Create Machine      ${SIMPLE_BIN}

            Start Emulation
            Execute Command     cpu Step 22
    ${it}=  Execute Command     cpu GetItState
            Should Contain      ${it}   0x000000AD      # IT_cond = 0b101; abcde bits = 0b00101

Should Shift State Bits After Every IT Block Instruction

            Create Machine      ${SIMPLE_BIN}

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
  ${next}=  Execute Command     cpu WillNextItInstructionExecute ${it}
            Should Contain      ${it}   0x00000000      # IT_cond = 0b000; abcde bits = 0b00000
            Should Contain      ${next}     False

Should Execute Only 'Then' Instructions

            Create Machine      ${SIMPLE_BIN}

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
            Execute Command     cpu Step 20                 # After CMP 6, 7 ; ITTET GE
    ${r1}=  Execute Command     sysbus ReadByte 0x20000010
    ${r2}=  Execute Command     sysbus ReadByte 0x20000014
    ${r3}=  Execute Command     sysbus ReadByte 0x20000018
    ${r4}=  Execute Command     sysbus ReadByte 0x2000001C
            Should Contain      ${r1}    0x00
            Should Contain      ${r2}    0x02
            Should Contain      ${r3}    0x03
            Should Contain      ${r4}    0x00


Should Save and Restore State of IT Block Correctly

           Create Machine      ${SIMPLE_BIN}

           Start Emulation
           Execute Command     cpu Step 5
  ${old}=  Execute Command     cpu GetItState

           ${tmp_file}=        Allocate Temporary File
           Execute Command     Save @${tmp_file}
           Execute Command     Load @${tmp_file}
           Execute Command     mach set 0
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

Should Survive Interrupt Handlers

            Create Machine      ${SIMPLE_BIN}

            Execute Command     nvic WriteDoubleWord 0x100 0x01
            Execute Command     machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0xFFFF0000 {size: 0x10000}"
            Start Emulation
            Execute Command     cpu Step 5

            Execute Command     nvic OnGPIO 0 true
            Execute Command     nvic OnGPIO 0 false
            Execute Command     cpu Step 11

    ${r1}=  Execute Command     sysbus ReadByte 0x20000000
    ${r2}=  Execute Command     sysbus ReadByte 0x20000004
    ${r3}=  Execute Command     sysbus ReadByte 0x20000008
    ${r4}=  Execute Command     sysbus ReadByte 0x2000000C
            Should Contain      ${r1}    0x01
            Should Contain      ${r2}    0x02
            Should Contain      ${r3}    0x00
            Should Contain      ${r4}    0x04

Should Work in BlockBeginHooks
            # Value returned in block begin concerns first instruction in current block

            Create Machine      ${SIMPLE_BIN}
            Create Log Tester   5000

            Start Emulation
            Execute Command     cpu Step 3
            Execute Command     cpu SetHookAtBlockBegin "self.DebugLog('PC '+ str(self.PC) + ';IT_state ' + hex(self.GetItState()).rstrip('L'))"
            Execute Command     cpu Step
            Wait For Log Entry  Checking next IT instruction status, while not in IT block
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
            Wait For Log Entry  Checking next IT instruction status, while not in IT block
            Wait For Log Entry  PC 0x8000054;IT_state 0x0

Should Work in BlockEndHooks
            # In BlockEnd both PC and It_status concerns first instruction of next block

            Create Machine      ${SIMPLE_BIN}
            Create Log Tester   5000

            Start Emulation                     #PC = 0x8000044
            Execute Command     cpu Step 3      #PC = 0x8000048
            Execute Command     cpu SetHookAtBlockEnd "self.DebugLog('PC '+ str(self.PC) + ';IT_state ' + hex(self.GetItState()).rstrip('L'))"
            Execute Command     cpu Step        #PC = 0x800004a
            Wait For Log Entry  PC 0x800004c;IT_state 0x5
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x800004e;IT_state 0xa
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x8000050;IT_state 0x14
            Execute Command     cpu Step
            Wait For Log Entry  PC 0x8000052;IT_state 0x8
            Execute Command     cpu Step
            Wait For Log Entry  Checking next IT instruction status, while not in IT block
            Wait For Log Entry  PC 0x8000054;IT_state 0x0

