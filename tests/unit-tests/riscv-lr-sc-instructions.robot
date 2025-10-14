*** Variables ***
${UART}                             sysbus.mmuart1
${URI}                              @https://dl.antmicro.com/projects/renode
${PLATFORM}                         @platforms/cpus/polarfire-soc.repl
${SHARED_VARIABLE_ADDRESS}          0x81000000
${VARIABLE_ADDRESS_CPU1}            0x81000000
${VARIABLE_ADDRESS_CPU2}            0x81000100
${LOOP_ITERATIONS}                  100
${CORE_1_PC}                        0x80000000
${CORE_2_PC}                        0x80000100
${VARIABLE_VALUE}                   0x5
${NEW_VARIABLE_VALUE}               0xbeeeeeef

# Registers used
${x0}                               0
${a0}                               10
${a1}                               11
${a2}                               12
${a3}                               13
${a4}                               14

# Repeatedly increments the value in (a0) until enough loop iterations have run.
${ASSEMBLY_LRSC_LOOP}               SEPARATOR=
...                                 repeat: lr.d a4, (a0);
...                                 add a4, a4, a2;
...                                 sc.d a4, a4, (a0);
...                                 bnez a4, repeat;
...                                 addi a1, a1, -1;
...                                 bnez a1, repeat;
...                                 j 0;

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 sysbus.u54_1 ExecutionMode SingleStep
    Execute Command                 sysbus.u54_2 ExecutionMode SingleStep
    Execute Command                 sysbus.u54_1 PC ${CORE_1_PC}
    Execute Command                 sysbus.u54_2 PC ${CORE_2_PC}

    Execute Command                 sysbus.u54_3 IsHalted true
    Execute Command                 sysbus.u54_4 IsHalted true
    Execute Command                 sysbus.e51 IsHalted true


Assemble Instruction
    [Arguments]                     ${cpu}  ${mnemonic}  ${operands}=  ${address}=0
    ${len}=                         Execute Command  sysbus.${cpu} AssembleBlock ${address} "${mnemonic} ${operands}"

Create Reservations
    # Just write 5 to memory, we'll use this to check for successful and failed writes
    Execute Command                 sysbus WriteDoubleWord ${VARIABLE_ADDRESS_CPU1} ${VARIABLE_VALUE}
    Execute Command                 sysbus WriteDoubleWord ${VARIABLE_ADDRESS_CPU2} ${VARIABLE_VALUE}

    # Make a0 hold the memory address

    # li a0, ${VARIABLE_ADDRESS_CPU1} (two instructions)
    Assemble Instruction            u54_1  li  a0, ${VARIABLE_ADDRESS_CPU1}  0x80000000
    Execute Command                 sysbus.u54_1 Step 2
    Register Should Be Equal        ${a0}  ${VARIABLE_ADDRESS_CPU1}  cpuName=u54_1

    # li a0, ${VARIABLE_ADDRESS_CPU2} (three instructions)
    Assemble Instruction            u54_2  li  a0, ${VARIABLE_ADDRESS_CPU2}  0x80000100
    Execute Command                 sysbus.u54_2 Step 3
    Register Should Be Equal        ${a0}  ${VARIABLE_ADDRESS_CPU2}  cpuName=u54_2

    # Create reservation on first core
    Assemble Instruction            u54_1  lr.d  a1, (a0)  0x80000006
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a1}  ${VARIABLE_VALUE}  cpuName=u54_1

    # Create reservation on second core
    Assemble Instruction            u54_2  lr.d  a1, (a0)  0x8000010A
    Execute Command                 sysbus.u54_2 Step
    Register Should Be Equal        ${a1}  ${VARIABLE_VALUE}  cpuName=u54_2

Contended Memory Value Should Increment To Correct Sum
    [Arguments]
    ...                             ${assembly_loop_core_1}
    ...                             ${assembly_loop_core_2}
    Create Machine

    Execute Command                 sysbus.u54_1 ExecutionMode Continuous
    Execute Command                 sysbus.u54_2 ExecutionMode Continuous

    Execute Command                 logLevel 0

    # Repeatedly increment a memory location from two cores

    ${shared_memory_counter}=       Set Variable  0x80000600
    ${counter_start_value}=         Set Variable  0
    ${increments_per_core}=         Set Variable  10000000
    ${increment_step_size}=         Set Variable  1

    # Initialize shared memory counter.
    Execute Command                 sysbus WriteQuadWord ${shared_memory_counter} ${counter_start_value}

    # Set up registers for first core.
    Execute Command                 u54_1 SetRegister ${a0} ${shared_memory_counter}
    Execute Command                 u54_1 SetRegister ${a1} ${increments_per_core}
    Execute Command                 u54_1 SetRegister ${a2} ${increment_step_size}
    Execute Command                 u54_1 SetRegister ${a3} 0x1234

    # Set up registers for second core.
    Execute Command                 u54_2 SetRegister ${a0} ${shared_memory_counter}
    Execute Command                 u54_2 SetRegister ${a1} ${increments_per_core}
    Execute Command                 u54_2 SetRegister ${a2} ${increment_step_size}
    Execute Command                 u54_2 SetRegister ${a3} 0x1234

    # Place machine code at PC for both cores.
    ${assembly_size_1}=             Execute Command  u54_1 AssembleBlock ${CORE_1_PC} "${assembly_loop_core_1}"
    ${assembly_size_2}=             Execute Command  u54_2 AssembleBlock ${CORE_2_PC} "${assembly_loop_core_2}"

    # Calculate end addresses.
    # The -2 is for the 'j 0' and needs to be put at the start due to weird robot/python string conversion
    ${core_1_end_pc}=               Evaluate  -2 + ${CORE_1_PC} + ${assembly_size_1}
    ${core_2_end_pc}=               Evaluate  -2 + ${CORE_2_PC} + ${assembly_size_2}

    # For detecting when loops are finished.
    Create Log Tester               0

    # Print when exiting loop.
    Execute Command                 u54_1 AddHook ${core_1_end_pc} "self.InfoLog('u54_1 finished'); self.IsHalted = True"
    Execute Command                 u54_2 AddHook ${core_2_end_pc} "self.InfoLog('u54_2 finished'); self.IsHalted = True"

    # Wait for the loops to finish...
    Wait For Log Entry              u54_1 finished  timeout=10  keep=true
    Wait For Log Entry              u54_2 finished  timeout=10  keep=true

    # In the end, the shared memory counter should've been incremented 2*increments_per_core times.
    ${counter_final_value}=         Execute Command  sysbus ReadQuadWord ${shared_memory_counter}
    Should Be Equal As Integers     ${counter_final_value}  ${2 * ${increments_per_core}}  "Counter should now have been incremented to ${2 * ${increments_per_core}} but it contains ${counter_final_value}"

*** Test Cases ***
Should Handle Multiple Writes To Same Reservation
    Create Machine
    Create Reservations

    # Try to update memory address with number 6
    # This will check if simple LR/SC behaves correctly

    Assemble Instruction            u54_1  li  a2, 0x6  0x8000000A
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a2}  0x6  cpuName=u54_1

    # Check for successful SC
    Assemble Instruction            u54_1  sc.d  a3, a2, (a0)  0x8000000C
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a3}  0x0  cpuName=u54_1

    ${res}=                         Execute Command  sysbus ReadDoubleWord ${VARIABLE_ADDRESS_CPU1}
    Should Be Equal As Integers     ${res}  6

    # Try to SC on something that isn't reserved - this should fail (returns 1)

    Assemble Instruction            u54_1  sc.d  a3, zero, (a0)  0x80000010
    Execute Command                 sysbus.u54_1 Step

    # Check if SC failed (correct behavior)
    Register Should Be Equal        ${a3}  0x1  cpuName=u54_1

    ${res}=                         Execute Command  sysbus ReadDoubleWord ${VARIABLE_ADDRESS_CPU1}
    Should Be Equal As Integers     ${res}  0x00000006

Should Work On Multiple Cores
    Create Machine
    Create Reservations

    # Having reservations on two cores, we try to store on both of them

    Assemble Instruction            u54_1  li  a2, 0x6  0x8000000A
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a2}  0x6  cpuName=u54_1

    Assemble Instruction            u54_2  li  a2, 0x7  0x8000010E
    Execute Command                 sysbus.u54_2 Step
    Register Should Be Equal        ${a2}  0x7  cpuName=u54_2

    # Check for successful store on second core
    Assemble Instruction            u54_2  sc.d  a3, a2, (a0)  0x80000110
    Execute Command                 sysbus.u54_2 Step
    Register Should Be Equal        ${a3}  0x0  cpuName=u54_2

    # Check for successful store on first core
    Assemble Instruction            u54_1  sc.d  a3, a2, (a0)  0x8000000C
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a3}  0x0  cpuName=u54_1

Should Drop Other Core Reservation On SC
    Create Machine
    Create Reservations

    # Check if SC on other core's LR will drop the reservation

    Assemble Instruction            u54_1  li  a2, 0x6  0x8000000A
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a2}  0x6  cpuName=u54_1

    # Get the address of second core's reservation to first core's a0
    Assemble Instruction            u54_1  li  a0, ${VARIABLE_ADDRESS_CPU2}  0x8000000C
    Execute Command                 sysbus.u54_1 Step 3
    Register Should Be Equal        ${a0}  ${VARIABLE_ADDRESS_CPU2}  cpuName=u54_1

    # Try to store on second core's reservation
    Assemble Instruction            u54_1  sc.d  a3, a2, (a0)  0x80000016
    Execute Command                 sysbus.u54_1 Step
    Register Should Be Equal        ${a3}  0x1  cpuName=u54_1

    # Try to store on second core's reservation by second core
    Assemble Instruction            u54_2  sc.d  a3, a2, (a0)  0x80000110
    Execute Command                 sysbus.u54_2 Step
    Register Should Be Equal        ${a3}  0x0  cpuName=u54_2

Should Handle Looping LR/SC Pairs To Same Reservation
    Create Machine

    ${start_value}=                 Set Variable  0

    Execute Command                 sysbus WriteDoubleWord ${VARIABLE_ADDRESS_CPU1} ${start_value}

    # Repeatedly increment a memory location on one core

    # The assembly instructions to execute in this test.
    # It repeatedly increments the value in (a0) until enough loop iterations have run.
    ${ASSEMBLY_LRSC_LOOP}=          catenate  SEPARATOR=
    ...                             repeat: lr.w a4, (a0);
    ...                             addi a4, a4, 1;
    ...                             sc.w a4, a4, (a0);
    ...                             bnez a4, repeat;
    ...                             addi a1, a1, -1;
    ...                             bnez a1, repeat;
    ...                             j 0;

    # Set up registers
    Execute Command                 u54_1 SetRegister ${a0} ${VARIABLE_ADDRESS_CPU1}
    Execute Command                 u54_1 SetRegister ${a1} ${LOOP_ITERATIONS}

    # Place machine code at PC.
    Execute Command                 sysbus.u54_1 AssembleBlock 0x80000000 "${ASSEMBLY_LRSC_LOOP}"

    FOR  ${i}  IN RANGE  ${start_value}  ${LOOP_ITERATIONS}
        ${next_i}=                      Set Variable  ${${i} + 1}

        # Execute lr.w, which should give the memory counter value
        Execute Command                 sysbus.u54_1 Step
        Register Should Be Equal        ${a4}  ${i}  cpuName=u54_1

        # Execute addi, which should increment the counter value
        Execute Command                 sysbus.u54_1 Step
        Register Should Be Equal        ${a4}  ${next_i}  cpuName=u54_1

        # Execute sc.w, which should succeed in storing the incremented value to memory
        Execute Command                 sysbus.u54_1 Step
        Register Should Be Equal        ${a4}  0  cpuName=u54_1
        ${res}=                         Execute Command  sysbus ReadDoubleWord ${VARIABLE_ADDRESS_CPU1}
        Should Be Equal As Integers     ${res}  ${next_i}  "Memory location should now contain ${next_i} but it contains ${res}"

        # bnez shouldn't need to jump to repeat, just step over it.
        Execute Command                 sysbus.u54_1 Step

        # Check for successful decrement of loop counter
        Execute Command                 sysbus.u54_1 Step
        Register Should Be Equal        ${a1}  ${${LOOP_ITERATIONS} - ${next_i}}  cpuName=u54_1

        # jump back to start of next loop (if not at final iteration)
        Execute Command                 sysbus.u54_1 Step
    END

    # In the end, it should've been incremented LOOP_ITERATIONS times.
    Register Should Be Equal        ${a1}  0  cpuName=u54_1
    ${res}=                         Execute Command  sysbus ReadDoubleWord ${VARIABLE_ADDRESS_CPU1}
    Should Be Equal As Integers     ${res}  ${LOOP_ITERATIONS}  "Memory location should now have been incremented to ${LOOP_ITERATIONS} but it contains ${res}"

Two LR/SC Loops Should Increment To Correct Sum
    Contended Memory Value Should Increment To Correct Sum
    ...                             assembly_loop_core_1=${ASSEMBLY_LRSC_LOOP}
    ...                             assembly_loop_core_2=${ASSEMBLY_LRSC_LOOP}

LR/SC And Amoadd Loops Should Increment To Correct Sum
    ${ASSEMBLY_AMOADD_LOOP}=        catenate  SEPARATOR=
    ...                             repeat: amoadd.d x0, a2, (a0);
    ...                             addi a1, a1, -1;
    ...                             bnez a1, repeat;
    ...                             j 0;
    Contended Memory Value Should Increment To Correct Sum
    ...                             assembly_loop_core_1=${ASSEMBLY_AMOADD_LOOP}
    ...                             assembly_loop_core_2=${ASSEMBLY_LRSC_LOOP}
