*** Variables ***
${PROTIMER_BLOCK_ADDRESS}       0xA021C000
${SEQACC_BLOCK_ADDRESS}         0xA025C000
${RAM_ADDRESS}                  0x10000000
# With a 38.4MHz clock (currently hard-coded in the radio model), setting the integer part of 
# PRECOUNT to 383 sets the PRECNT overflow to a nice round frequency of 100KHz (one tick very 10us)
${PROTIMER_PRECOUNT_TOP_VALUE}  0x017F0000
${SEQ0_START_ADDRESS}           0x10000000
${SEQ1_START_ADDRESS}           0x10001000
${BASE_ADDRESS_0}               0x10010000
${BASE_ADDRESS_1}               0x10020000
${SPARE_RAM_ADDRESS}            0x10030000
${END_SEQUENCE}                 0xFFFFFFFF
@{TEST_WORDS}                   0xABCD1234  0xDEADBEEF  0xBAADFEED
@{TEST_WORDS_2}                 0x99887766  0x55443322  0x1100FFEE
@{ZEROED_WORDS}                 0  0  0
${REPL_STRING}=                 SEPARATOR=
...  """                                                                                                                      ${\n}
...  radio: Wireless.SiLabs_xG301_LPW @ {                                                                                     ${\n}
...  ${SPACE*4}sysbus new Bus.BusMultiRegistration { address: ${PROTIMER_BLOCK_ADDRESS}; size: 0x4000; region: "protimer_s" } ${\n}
...  }                                                                                                                        ${\n}
...  ram: Memory.MappedMemory @ sysbus ${RAM_ADDRESS}                                                                         ${\n}
...  ${SPACE*4}size: 0x400000                                                                                                 ${\n}
...  seqacc: Miscellaneous.SiLabs.SiLabs_SEQACC_1 @ sysbus ${SEQACC_BLOCK_ADDRESS}                                            ${\n}
...  ${SPACE*4}frequency: 38400000                                                                                            ${\n}
...  ${SPACE*4}protocolTimer: radio                                                                                           ${\n}
...  """

# PROTIMER registers
${PROTIMER_CTRL_REG}            0x0008
${PROTIMER_CMD_REG}             0x000C
${PROTIMER_BASECNT_REG}         0x001C
${PROTIMER_WRAPCNT_REG}         0x0020
${PROTIMER_PRECNT_TOP_REG}      0x0034
${PROTIMER_BASECNT_TOP_REG}     0x0038
${PROTIMER_WRAPCNT_TOP_REG}     0x003C

# SEQACC registers
${SEQACC_ENABLE_REG}            0x0004
${SEQACC_CONFIG_REG}            0x0010
${SEQACC_CTRL_REG}              0x0014
${SEQACC_STATUS_REG}            0x0018
${SEQACC_BUSY_REG}              0x001C
${SEQACC_IF_REG}                0x0020
${SEQACC_IEN_REG}               0x0024
${SEQACC_CTRL2_REG}             0x0030
${SEQACC_EQ_COND_MASK_0_REG}    0x003C
${SEQACC_EQ_COND_MASK_1_REG}    0x0040
${SEQACC_START_ADDRESS_0_REG}   0x0050
${SEQACC_SEQUENCE_CFG_0_REG}    0x0054
${SEQACC_START_ADDRESS_1_REG}   0x0058
${SEQACC_SEQUENCE_CFG_1_REG}    0x005C
${SEQACC_BASE_ADDRESS_0_REG}    0x00D0
${SEQACC_BASE_ADDRESS_1_REG}    0x00D4

*** Keywords ***
Create Machine
    Execute Command             mach create "test"
    Execute Command             machine LoadPlatformDescriptionFromString ${REPL_STRING}
    Execute Command             logLevel 3

Read ProTimer Register
    [Arguments]  ${offset}
    ${addr}                     evaluate  ${PROTIMER_BLOCK_ADDRESS} + ${offset}
    ${reg_val}=                 Execute Command  sysbus ReadDoubleWord ${addr}
    RETURN                      ${reg_val}

Write ProTimer Register
    [Arguments]  ${offset}  ${value}
    ${addr}                     evaluate  ${PROTIMER_BLOCK_ADDRESS} + ${offset}
    Execute Command             sysbus WriteDoubleWord ${addr} ${value}

Read SeqAcc Register
    [Arguments]  ${offset}
    ${addr}                     evaluate  ${SEQACC_BLOCK_ADDRESS} + ${offset}
    ${reg_val}=                 Execute Command  sysbus ReadDoubleWord ${addr}
    RETURN                      ${reg_val}

Write SeqAcc Register
    [Arguments]  ${offset}  ${value}
    ${addr}                     evaluate  ${SEQACC_BLOCK_ADDRESS} + ${offset}
    Execute Command             sysbus WriteDoubleWord ${addr} ${value}

Configure And Start Protimer
    # Set the PRECNT to be sourced by the clock, BASECNT and WRAPCNT sourced by PRECNT overflows
    Write ProTimer Register     ${PROTIMER_CTRL_REG}  0x540
    Write ProTimer Register     ${PROTIMER_PRECNT_TOP_REG}  ${PROTIMER_PRECOUNT_TOP_VALUE}
    Write ProTimer Register     ${PROTIMER_BASECNT_TOP_REG}  0xFFFFFFFF
    Write ProTimer Register     ${PROTIMER_WRAPCNT_TOP_REG}  0xFFFFFFFF
    # Start the protimer
    Write ProTimer Register     ${PROTIMER_CMD_REG}  0x1

Configure Sequencer Accelerator
    # Enable the Sequencer Accelerator
    Write SeqAcc Register       ${SEQACC_ENABLE_REG}  0x1
    # BASEPOS=24, TIMEBASE=PreCountOverflow
    Write SeqAcc Register       ${SEQACC_CONFIG_REG}  0x10180
    # CONT_WRITE_POS=16
    Write SeqAcc Register       ${SEQACC_SEQUENCE_CFG_0_REG}  0x10
    Write SeqAcc Register       ${SEQACC_SEQUENCE_CFG_1_REG}  0x10
    # Start Addresses
    Write SeqAcc Register       ${SEQACC_START_ADDRESS_0_REG}  ${SEQ0_START_ADDRESS}
    Write SeqAcc Register       ${SEQACC_START_ADDRESS_1_REG}  ${SEQ1_START_ADDRESS}
    # Base Addresses
    Write SeqAcc Register       ${SEQACC_BASE_ADDRESS_0_REG}  ${BASE_ADDRESS_0}
    Write SeqAcc Register       ${SEQACC_BASE_ADDRESS_1_REG}  ${BASE_ADDRESS_1}
    # Enable interrupts
    Write SeqAcc Register       ${SEQACC_IEN_REG}  0xE00000FF
       
Assert SeqAcc IRQ Is Set
    ${irqState}=                    Execute Command  sysbus.seqacc HostIRQ
    Should Contain                  ${irqState}  GPIO: set

Assert SeqAcc IRQ Is Unset
    ${irqState}=                    Execute Command  sysbus.seqacc HostIRQ
    Should Contain                  ${irqState}  GPIO: unset

Clear SeqAcc Interrupt              
    Write SeqAcc Register           ${SEQACC_IF_REG}  0

Set Instruction With ExtOpCode
    [Arguments]  ${index}  ${offset}  ${arg_word}  ${data_word}  ${append_end_sequence}
    IF  ${index} == 0
        ${start_addr}=              Set Variable  ${SEQ0_START_ADDRESS}
    ELSE
        ${start_addr}=              Set Variable  ${SEQ1_START_ADDRESS}  
    END
    ${arg_addr}                     evaluate  ${start_addr} + ${offset}
    Execute Command                 sysbus WriteDoubleWord ${arg_addr} ${arg_word}
    ${move_swap}=                   Get Move Swap Flag  ${index}
    IF  ${move_swap}
        ${base_index}               evaluate  (${arg_word} >> 24) & 0xF
        IF  ${base_index} == 0
            ${addr}=                Set Variable  ${BASE_ADDRESS_0}
        ELSE
            ${addr}=                Set Variable  ${BASE_ADDRESS_1}
        END
    ELSE
        ${addr}                     evaluate  ${arg_addr} + 4
    END
    Execute Command                 sysbus WriteDoubleWord ${addr} ${data_word}
    IF  ${append_end_sequence}
        ${addr}                     evaluate  ${arg_addr} + 8
        Execute Command             sysbus WriteDoubleWord ${addr} ${END_SEQUENCE}
    END

Set Instruction With Length
    [Arguments]  ${index}  ${offset}  ${arg_word}  ${append_end_sequence}
    IF  ${index} == 0
        ${start_addr}=              Set Variable  ${SEQ0_START_ADDRESS}
    ELSE
        ${start_addr}=              Set Variable  ${SEQ1_START_ADDRESS}  
    END
    ${length}                       evaluate  (${arg_word} >> 16) & 0xFF
    ${arg_addr}                     evaluate  ${start_addr} + ${offset}
    Execute Command                 sysbus WriteDoubleWord ${arg_addr} ${arg_word}
    ${move_swap}=                   Get Move Swap Flag  ${index}
    IF  ${move_swap}
        ${base_index}               evaluate  (${arg_word} >> 24) & 0xF
        IF  ${base_index} == 0
            ${addr}=                Set Variable  ${BASE_ADDRESS_0}
        ELSE
            ${addr}=                Set Variable  ${BASE_ADDRESS_1}
        END
    ELSE
        ${addr}                     evaluate  ${arg_addr} + 4
    END    
    FOR  ${i}  IN RANGE  0  ${length}
        Execute Command             sysbus WriteDoubleWord ${addr} ${TEST_WORDS}[${i}]
        ${addr}                     evaluate  ${addr} + 4
    END
    IF  ${append_end_sequence}
        ${addr}                     evaluate  ${arg_addr} + 4 + ${length}*4
        Execute Command             sysbus WriteDoubleWord ${addr} ${END_SEQUENCE}
    END

Start Sequence
    [Arguments]  ${index}
    IF  ${index} == 0
        ${reg_val}=                 Set Variable  0x1
    ELSE
        ${reg_val}=                 Set Variable  0x2
    END
    Write SeqAcc Register           ${SEQACC_CTRL_REG}  ${reg_val}

Abort Sequence
    [Arguments]  ${index}
    IF  ${index} == 0
        ${reg_val}=                 Set Variable  0x10000
    ELSE
        ${reg_val}=                 Set Variable  0x20000
    END
    Write SeqAcc Register           ${SEQACC_CTRL_REG}  ${reg_val}

Set Move Swap Flag
    [Arguments]  ${index}  ${flag}
    IF  ${index} == 0
        ${reg_val}=                 Read SeqAcc Register  ${SEQACC_SEQUENCE_CFG_0_REG}
    ELSE
        ${reg_val}=                 Read SeqAcc Register  ${SEQACC_SEQUENCE_CFG_1_REG}
    END
    IF  ${flag}
        ${reg_val}                  evaluate  (${reg_val} | (1 << 14))
    ELSE
        ${reg_val}                  evaluate  (${reg_val} & ~(1 << 14))
    END
    IF  ${index} == 0
        Write SeqAcc Register       ${SEQACC_SEQUENCE_CFG_0_REG}  ${reg_val}
    ELSE
        Write SeqAcc Register       ${SEQACC_SEQUENCE_CFG_1_REG}  ${reg_val}
    END

Get Move Swap Flag
    [Arguments]  ${index}
    IF  ${index} == 0
        ${reg_val}=                 Read SeqAcc Register  ${SEQACC_SEQUENCE_CFG_0_REG}
    ELSE
        ${reg_val}=                 Read SeqAcc Register  ${SEQACC_SEQUENCE_CFG_1_REG}
    END
    ${ret}                          evaluate  ((${reg_val} & (1 << 14)) > 0) 
    RETURN                          ${ret}

Set Disable Reset Absolute Delay Counter
    [Arguments]  ${index}  ${flag}
    IF  ${index} == 0
        ${reg_val}=                 Read SeqAcc Register  ${SEQACC_SEQUENCE_CFG_0_REG}
    ELSE
        ${reg_val}=                 Read SeqAcc Register  ${SEQACC_SEQUENCE_CFG_1_REG}
    END
    IF  ${flag}
        ${reg_val}                  evaluate  (${reg_val} | (1 << 13))
    ELSE
        ${reg_val}                  evaluate  (${reg_val} & ~(1 << 13))
    END
    IF  ${index} == 0
        Write SeqAcc Register       ${SEQACC_SEQUENCE_CFG_0_REG}  ${reg_val}
    ELSE
        Write SeqAcc Register       ${SEQACC_SEQUENCE_CFG_1_REG}  ${reg_val}
    END

Reset Absolute Delay Counter
    Write SeqAcc Register           ${SEQACC_CTRL2_REG}  0x1

Clear Memory
    [Arguments]  ${clear_addr}  ${length}
    FOR  ${i}  IN RANGE  0  ${length}
        ${addr}                     evaluate  ${clear_addr} + ${i}*4
        Execute Command             sysbus WriteDoubleWord ${addr} 0
    END

Check Memory Content
    [Arguments]  ${check_addr}  ${list}  ${list_start_index}  ${length}
    FOR  ${i}  IN RANGE  0  ${length}
        ${addr}                       evaluate  ${check_addr} + ${i}*4
        ${read_val}=                  Execute Command  sysbus ReadDoubleWord ${addr}
        ${index}                      evaluate  ${list_start_index} + ${i}
        Should Be Equal As Integers   ${read_val}  ${list}[${index}]
    END

*** Test Cases ***

Write Op Codes
    Create Machine
    Configure Sequencer Accelerator
    Assert SeqAcc IRQ Is Unset

    # OpCode: Write at baseAddress0, length=1
    Clear Memory                      ${BASE_ADDRESS_0}  1
    Set Instruction With Length       0  0  0x00010000  True
    Start Sequence                    0
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    Assert SeqAcc IRQ Is Unset

    # OpCode: Write at baseAddress1, length=1
    Clear Memory                      ${BASE_ADDRESS_1}  1
    Set Instruction With Length       0  0  0x01010000  True
    Start Sequence                    0
    Check Memory Content              ${BASE_ADDRESS_1}  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    Assert SeqAcc IRQ Is Unset

    # OpCode: Write at baseAddress0, length=3
    Clear Memory                      ${BASE_ADDRESS_0}  3
    Set Instruction With Length       0  0  0x00030000  True
    Start Sequence                    0
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  0  3
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: WriteNoInc at baseAddress0, length=3
    Clear Memory                      ${BASE_ADDRESS_0}  3
    Set Instruction With Length       0  0  0x90030000  True
    Start Sequence                    0
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  2  1
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  2
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

Move Op Codes
    Create Machine
    Configure Sequencer Accelerator

    # OpCode: Move at baseAddress0, length=1
    Clear Memory                      ${BASE_ADDRESS_0}  1
    Set Instruction With Length       0  0  0x50010000  True
    Start Sequence                    0
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: Move at baseAddress0, length=3
    Clear Memory                      ${BASE_ADDRESS_0}  3
    Set Instruction With Length       0  0  0x50030000  True
    Start Sequence                    0
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  0  3
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: MoveNoInc at baseAddress0, length=3
    Clear Memory                      ${BASE_ADDRESS_0}  3
    Set Instruction With Length       0  0  0x60030000  True
    Start Sequence                    0
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  2  1
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  2
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: MoveBlock at baseAddress0, length=3
    Clear Memory                      ${BASE_ADDRESS_0}  3
    FOR  ${i}  IN RANGE  0  3
        ${addr}                       evaluate  ${SPARE_RAM_ADDRESS} + ${i}*4
        Execute Command               sysbus WriteDoubleWord ${addr} ${TEST_WORDS}[${i}]
    END
    Execute Command                   sysbus WriteDoubleWord ${SEQ0_START_ADDRESS} 0xC0030000
    ${addr}                           evaluate  ${SEQ0_START_ADDRESS} + 4
    Execute Command                   sysbus WriteDoubleWord ${addr} ${SPARE_RAM_ADDRESS}
    ${addr}                           evaluate  ${addr} + 4
    Execute Command                   sysbus WriteDoubleWord ${addr} ${END_SEQUENCE}
    Start Sequence                    0
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  0  3
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: Move at baseAddress0, length=1, with MOVSWAP set
    Set Move Swap Flag                0  True
    Clear Memory                      ${SEQ0_START_ADDRESS}+4   1
    Set Instruction With Length       0  0  0x50010000  True
    Start Sequence                    0
    Check Memory Content              ${SEQ0_START_ADDRESS}+4  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: Move at baseAddress0, length=3, with MOVSWAP set
    Clear Memory                      ${SEQ0_START_ADDRESS}+4   3
    Set Instruction With Length       0  0  0x50030000  True
    Start Sequence                    0
    Check Memory Content              ${SEQ0_START_ADDRESS}+4  ${TEST_WORDS}  0  3
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: MoveBlock at baseAddress0, length=3, , with MOVSWAP set
    Clear Memory                      ${SPARE_RAM_ADDRESS}  3
    FOR  ${i}  IN RANGE  0  3
        ${addr}                       evaluate  ${BASE_ADDRESS_0} + ${i}*4
        Execute Command               sysbus WriteDoubleWord ${addr} ${TEST_WORDS}[${i}]
    END
    Execute Command                   sysbus WriteDoubleWord ${SEQ0_START_ADDRESS} 0xC0030000
    ${addr}                           evaluate  ${SEQ0_START_ADDRESS} + 4
    Execute Command                   sysbus WriteDoubleWord ${addr} ${SPARE_RAM_ADDRESS}
    ${addr}                           evaluate  ${addr} + 4
    Execute Command                   sysbus WriteDoubleWord ${addr} ${END_SEQUENCE}
    Start Sequence                    0
    Check Memory Content              ${SPARE_RAM_ADDRESS}  ${TEST_WORDS}  0  3
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

Logic Operator Op Codes
    Create Machine
    Configure Sequencer Accelerator

    # OpCode: And at baseAddress0, length=3
    FOR  ${i}  IN RANGE  0  3
        ${addr}                       evaluate  ${BASE_ADDRESS_0} + ${i}*4
        Execute Command               sysbus WriteDoubleWord ${addr} ${TEST_WORDS_2}[${i}]
    END
    Set Instruction With Length       0  0  0x10030000  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    FOR  ${i}  IN RANGE  0  3
        ${addr}                       evaluate  ${BASE_ADDRESS_0} + ${i}*4
        ${read_val}=                  Execute Command  sysbus ReadDoubleWord ${addr}
        ${expected_val}               evaluate  ${TEST_WORDS}[${i}] & ${TEST_WORDS_2}[${i}]
        Should Be Equal As Integers   ${read_val}  ${expected_val}
    END

    # OpCode: Xor at baseAddress0, length=3
    FOR  ${i}  IN RANGE  0  3
        ${addr}                       evaluate  ${BASE_ADDRESS_0} + ${i}*4
        Execute Command               sysbus WriteDoubleWord ${addr} ${TEST_WORDS_2}[${i}]
    END
    Set Instruction With Length       0  0  0x20030000  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    FOR  ${i}  IN RANGE  0  3
        ${addr}                       evaluate  ${BASE_ADDRESS_0} + ${i}*4
        ${read_val}=                  Execute Command  sysbus ReadDoubleWord ${addr}
        ${expected_val}               evaluate  ${TEST_WORDS}[${i}] ^ ${TEST_WORDS_2}[${i}]
        Should Be Equal As Integers   ${read_val}  ${expected_val}
    END

    # OpCode: Or at baseAddress0, length=3
    FOR  ${i}  IN RANGE  0  3
        ${addr}                       evaluate  ${BASE_ADDRESS_0} + ${i}*4
        Execute Command               sysbus WriteDoubleWord ${addr} ${TEST_WORDS_2}[${i}]
    END
    Set Instruction With Length       0  0  0x30030000  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    FOR  ${i}  IN RANGE  0  3
        ${addr}                       evaluate  ${BASE_ADDRESS_0} + ${i}*4
        ${read_val}=                  Execute Command  sysbus ReadDoubleWord ${addr}
        ${expected_val}               evaluate  ${TEST_WORDS}[${i}] | ${TEST_WORDS_2}[${i}]
        Should Be Equal As Integers   ${read_val}  ${expected_val}
    END

Jump Op Codes
    Create Machine
    Configure Sequencer Accelerator

    # OpCode: Jump, absolute address, dataword=0 (if data word is 0, the jump instruction is ignored)
    Clear Memory                      ${BASE_ADDRESS_0}  1
    Set Instruction With ExtOpCode    0  0  0xA0010000  0x0  False
    # Write, length 1
    Set Instruction With Length       0  8  0x00010000  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  0  1

    # OpCode: Jump, relative address, dataword=0 (if data word is 0, the jump instruction is ignored)
    Clear Memory                      ${BASE_ADDRESS_0}  1
    Set Instruction With ExtOpCode    0  0  0xA0000000  0x0  False
    # Write, length 1
    Set Instruction With Length       0  8  0x00010000  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    Check Memory Content              ${BASE_ADDRESS_0}  ${TEST_WORDS}  0  1

    # OpCode: Jump, absolute address (should skip write instruction)
    Clear Memory                      ${BASE_ADDRESS_0}  1
    ${addr}                           evaluate  ${SEQ0_START_ADDRESS} + 16
    Set Instruction With ExtOpCode    0  0  0xA0010000  ${addr}  False
    # Write, length 1
    Set Instruction With Length       0  8  0x00010000  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    Check Memory Content              ${BASE_ADDRESS_0}  ${ZEROED_WORDS}  0  1

    # OpCode: Jump, relative address (should skip write instruction)
    Clear Memory                      ${BASE_ADDRESS_0}  1
    Set Instruction With ExtOpCode    0  0  0xA0000000  8  False
    # Write, length 1
    Set Instruction With Length       0  8  0x00010000  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    Check Memory Content              ${BASE_ADDRESS_0}  ${ZEROED_WORDS}  0  1

Delay Op Codes
    Create Machine
    Configure Sequencer Accelerator
    Configure And Start Protimer

    # First make sure protimer is functioning, 1 second of simulation = 100000 PRECNT overflows
    Execute Command                   emulation RunFor "1"
    ${read_val}=                      Read ProTimer Register  ${PROTIMER_BASECNT_REG}
    Should Be Equal As Integers       ${read_val}  100000

    # OpCode: Delay (relative)
    Set Instruction With ExtOpCode    0  0  0x40000000  99999  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    # Test BUSY register
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_BUSY_REG}
    Should Be Equal As Integers       ${read_val}  0x1
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: Delay (absolute), DISABSRST = 0, absolute delay counter is reset when sequence start. 
    Set Instruction With ExtOpCode    0  0  0x40010000  99999  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: Delay (absolute), DISABSRST = 0, absolute delay counter is reset when sequence start. 
    # Run it one more time to confirm the absolute delay counter gets reset
    Set Instruction With ExtOpCode    0  0  0x40010000  99999  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    Set Disable Reset Absolute Delay Counter  0  True

    # OpCode: Delay (absolute), DISABSRST = 1, absolute delay counter is NOT reset when sequence start. 
    # The counter should start from the 100000 value
    Set Instruction With ExtOpCode    0  0  0x40010000  199999  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    Set Disable Reset Absolute Delay Counter  0  False

    # OpCode: Delay (absolute), DISABSRST = 0, absolute delay counter is reset when sequence start. 
    # In the middle of the delay, manually reset the absolute delay counter.
    Set Instruction With ExtOpCode    0  0  0x40010000  99999  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    Reset Absolute Delay Counter
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # Test multiple sequences (pending/resuming)
    # OpCode: Delay (relative)
    Set Instruction With ExtOpCode    0  0  0x40000000  99999  True
    Start Sequence                    0
    # OpCode: Delay (relative)
    Set Instruction With ExtOpCode    1  0  0x40000000  99999  True
    Start Sequence                    1
    # Check sequence 0 is running
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_BUSY_REG}
    Should Be Equal As Integers       ${read_val}  0x1
    # Check sequence 1 is pending
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_STATUS_REG}
    Should Be Equal As Integers       ${read_val}  0x2
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    # Check sequence 1 is running
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_BUSY_REG}
    Should Be Equal As Integers       ${read_val}  0x2
    # Check no sequence is pending
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_STATUS_REG}
    Should Be Equal As Integers       ${read_val}  0x0
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    # Check no sequence is running
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_BUSY_REG}
    Should Be Equal As Integers       ${read_val}  0x0
    # Check no sequence is pending
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_STATUS_REG}

    # Test sequence abort
    # OpCode: Delay (relative)
    Set Instruction With ExtOpCode    0  0  0x40000000  99999  True
    Start Sequence                    0
    # Check sequence 0 is running
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_BUSY_REG}
    Should Be Equal As Integers       ${read_val}  0x1
    Assert SeqAcc IRQ Is Unset
    Execute Command                   emulation RunFor "0.5"
    Assert SeqAcc IRQ Is Unset
    Abort Sequence                    0
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    # Check no sequence is running
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_BUSY_REG}
    Should Be Equal As Integers       ${read_val}  0x0
    # Check no sequence is pending
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_STATUS_REG}

WaitForRegister Op Codes
    Create Machine
    Configure Sequencer Accelerator
    ${reg_addr}                       Set Variable  ${BASE_ADDRESS_0}
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_1_REG}  0
    
    # OpCode: WaitForReg, All
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0
    Set Instruction With ExtOpCode    0  0  0x70000000  0xFF00FF00  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    # Set only some the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0000FF00
    Execute Command                   emulation RunFor "0.000005"
    # Set ALL the bits of the mask bits
    Assert SeqAcc IRQ Is Unset
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF00FF00
    Execute Command                   emulation RunFor "0.000005"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt
    ${read_val}=                      Read SeqAcc Register  ${SEQACC_BUSY_REG}
    Should Be Equal As Integers       ${read_val}  0

    # OpCode: WaitForReg, Any
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0
    Set Instruction With ExtOpCode    0  0  0x70010000  0xFF00FF00  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    # Set only some the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0000FF00
    Execute Command                   emulation RunFor "0.000005"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: WaitForReg, NegAll
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF00FF00
    Set Instruction With ExtOpCode    0  0  0x70020000  0xFF00FF00  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    # Negate only some the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF000000
    Execute Command                   emulation RunFor "0.000005"
    # Negate ALL the bits of the mask bits
    Assert SeqAcc IRQ Is Unset
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x00000000
    Execute Command                   emulation RunFor "0.000005"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: WaitForReg, NegAny
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF00FF00
    Set Instruction With ExtOpCode    0  0  0x70030000  0xFF00FF00  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    # Negate only some the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF000000
    Execute Command                   emulation RunFor "0.000005"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: WaitForReg, Eq0
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0xFF00FF00
    Set Instruction With ExtOpCode    0  0  0x70040000  0x0F000F00  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    # Set only some the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000000
    Execute Command                   emulation RunFor "0.000005"
    # Set ALL the bits of the mask bits
    Assert SeqAcc IRQ Is Unset
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000F00
    Execute Command                   emulation RunFor "0.000005"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: WaitForReg, Neq0
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000F00
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0xFF00FF00    
    Set Instruction With ExtOpCode    0  0  0x70050000  0x0F000F00  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    # Set only some the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000000
    Execute Command                   emulation RunFor "0.000005"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0

    # OpCode: WaitForReg, Eq1
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_1_REG}  0xFF00FF00    
    Set Instruction With ExtOpCode    0  0  0x70060000  0x0F000F00  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    # Set only some the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000000
    Execute Command                   emulation RunFor "0.000005"
    # Set ALL the bits of the mask bits
    Assert SeqAcc IRQ Is Unset
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000F00
    Execute Command                   emulation RunFor "0.000005"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: WaitForReg, Neq1
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000F00
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_1_REG}  0xFF00FF00    
    Set Instruction With ExtOpCode    0  0  0x70070000  0x0F000F00  True
    Start Sequence                    0
    Assert SeqAcc IRQ Is Unset
    # Set only some the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000000
    Execute Command                   emulation RunFor "0.000005"
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

# RENODE-???: Signals haven't been implemented/connected, so we can't test WaitForSig and Trigger Op Codes
#WaitForSig Op Codes
#Trigger Op Codes


SkipCond Op Codes
    # RENODE-???: Signals haven't been connected yet, so we can't test signal related skip conditions
    Create Machine
    Configure Sequencer Accelerator
    ${reg_addr}                       Set Variable  ${BASE_ADDRESS_0}
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_1_REG}  0

    # OpCode: SkipCond, RegAll (condition=FALSE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set ONLY SOME of the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0000FF00
    Set Instruction With ExtOpCode    0  0  0xD0000000  0xFF00FF00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check both writes occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${TEST_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegAll (condition=TRUE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set ALL the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF00FF00
    Set Instruction With ExtOpCode    0  0  0xD0000000  0xFF00FF00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check only the second write occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegAny (condition=FALSE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set NONE of the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x00000000
    Set Instruction With ExtOpCode    0  0  0xD0010000  0xFF00FF00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check both writes occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${TEST_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegAny (condition=TRUE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set SOME of the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x10000000
    Set Instruction With ExtOpCode    0  0  0xD0010000  0xFF00FF00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check only the second write occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegNegAll (condition=FALSE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Negate SOME the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF000000
    Set Instruction With ExtOpCode    0  0  0xD0020000  0xFF00FF00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check both writes occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${TEST_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegNegAll (condition=TRUE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Negate ALL the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x00000000
    Set Instruction With ExtOpCode    0  0  0xD0020000  0xFF00FF00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check only the second write occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegNegAny (condition=FALSE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Negate NONE of the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF00FF00
    Set Instruction With ExtOpCode    0  0  0xD0030000  0xFF00FF00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check both writes occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${TEST_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegNegAny (condition=TRUE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Negate SOME of the bits of the mask bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0xFF000000
    Set Instruction With ExtOpCode    0  0  0xD0030000  0xFF00FF00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check only the second write occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegEq0 (condition=FALSE)
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0xFF00FF00
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set SOME of the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000000
    Set Instruction With ExtOpCode    0  0  0xD0040000  0x0F000F00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check both writes occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${TEST_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegEq0 (condition=TRUE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set ALL the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000F00
    Set Instruction With ExtOpCode    0  0  0xD0040000  0x0F000F00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check only the second write occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegNeq0 (condition=FALSE)
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0xFF00FF00
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set ALL the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000F00
    Set Instruction With ExtOpCode    0  0  0xD0050000  0x0F000F00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check both writes occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${TEST_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegNeq0 (condition=TRUE)
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0xFF00FF00
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set SOME of the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000000
    Set Instruction With ExtOpCode    0  0  0xD0050000  0x0F000F00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check only the second write occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegEq1 (condition=FALSE)
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_1_REG}  0xFF00FF00
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set SOME of the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000000
    Set Instruction With ExtOpCode    0  0  0xD0060000  0x0F000F00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check both writes occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${TEST_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegEq1 (condition=TRUE)
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set ALL the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000F00
    Set Instruction With ExtOpCode    0  0  0xD0060000  0x0F000F00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check only the second write occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegNeq1 (condition=FALSE)
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0xFF00FF00
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set ALL the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000F00
    Set Instruction With ExtOpCode    0  0  0xD0070000  0x0F000F00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check both writes occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${TEST_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt

    # OpCode: SkipCond, RegNeq1 (condition=TRUE)
    Write SeqAcc Register             ${SEQACC_EQ_COND_MASK_0_REG}  0xFF00FF00
    Clear Memory                      ${BASE_ADDRESS_0}+4  1
    Clear Memory                      ${BASE_ADDRESS_0}+8  1
    # Set SOME of the bits of the data bits
    Execute Command                   sysbus WriteDoubleWord ${reg_addr} 0x0F000000
    Set Instruction With ExtOpCode    0  0  0xD0070000  0x0F000F00  False    
    # Write at baseAddress0, length=1
    Set Instruction With Length       0  8  0x00010004  False
    # Write at baseAddress0+4, length=1
    Set Instruction With Length       0  16  0x00010008  True
    Start Sequence                    0
    # Check only the second write occurred
    Check Memory Content              ${BASE_ADDRESS_0}+4  ${ZEROED_WORDS}  0  1
    Check Memory Content              ${BASE_ADDRESS_0}+8  ${TEST_WORDS}  0  1
    Assert SeqAcc IRQ Is Set
    Clear SeqAcc Interrupt