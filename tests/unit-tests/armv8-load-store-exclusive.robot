*** Settings ***
Test Setup                          Create Machine

*** Variables ***
${PLATFORM_PATH}                    ${CURDIR}${/}armv8-load-store-exclusive.repl
${ORDINARY_ADDRESS}                 0x41000000
${MMIO_ADDRESS}                     0x00100000
${LOOP_ITERATIONS}                  100
${CORE_0_PC}                        0x40000000
${CORE_1_PC}                        0x40000100
${VARIABLE_VALUE}                   0x5
${NEW_VARIABLE_VALUE}               0xbeeeeeef

# Repeatedly increments the value in [x7|r7] until enough loop iterations have run.
${ASSEMBLY_LDX_STX_LOOP}            SEPARATOR=\n
...                                 repeat: ldxr x9, [x7];
...                                 add x9, x9, #1;
...                                 stxr w15, x9, [x7];
...                                 cbnz w15, repeat;
...                                 add x8, x8, #-1;
...                                 cbnz x8, repeat;
...                                 b .;
${ASSEMBLY_LDX_STX_128_LOOP}        SEPARATOR=\n
...                                 repeat: ldxp x9, x13, [x7];
...                                 add x9, x9, #1;
...                                 stxp w15, x9, x13, [x7];
...                                 cbnz w15, repeat;
...                                 add x8, x8, #-1;
...                                 cbnz x8, repeat;
...                                 b .;
${ASSEMBLY_LDREX_STREX_LOOP}        SEPARATOR=\n
...                                 repeat: ldrex r9, [r7];
...                                 add r9, r9, #1;
...                                 strex r6, r9, [r7];
...                                 cmp r6, #0;
...                                 bne repeat;
...                                 subs r8, r8, #1;
...                                 bne repeat;
...                                 b .;

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription "${PLATFORM_PATH}"
    Reset Program Counters

Reset Program Counters
    Execute Command                 cpu0_a64 PC ${CORE_0_PC}
    Execute Command                 cpu0_a32 PC ${CORE_0_PC}
    Execute Command                 cpu1_a64 PC ${CORE_1_PC}
    Execute Command                 cpu1_a32 PC ${CORE_1_PC}

Get Register ${number} On ${platform:(a32|a64)}
    ${register}=                    Set variable if  "${platform}" == "a64"
    ...                             x${number}
    ...                             r${number}
    [return]                        ${register}

# Status registers are always 32 bit

Get Status Register On ${platform:(a32|a64)}
    ${register}=                    Set variable if  "${platform}" == "a64"
    ...                             w6
    ...                             r6
    [return]                        ${register}

Get Status Register Index On ${platform:(a32|a64)}
    ${register}=                    Set variable if  "${platform}" == "a64"
    ...                             6
    ...                             106
    [return]                        ${register}

Get Load Reserve On ${platform:(a32|a64)}
    ${instruction}=                 Set Variable if  "${platform}" == "a64"
    ...                             ldxr
    ...                             ldrex
    [return]                        ${instruction}

Get Store Exclusive On ${platform:(a32|a64)}
    ${instruction}=                 Set Variable if  "${platform}" == "a64"
    ...                             stxr
    ...                             strex
    [return]                        ${instruction}

Get Load Store Exclusive Pair On ${platform:(a32|a64)} ${inst_suffix:(r|p|x|xd)} ${reg_size:(x|w)}
    IF  '${platform}' == 'a64'
        ${instructions}=                Set variable if  "${inst_suffix}" == "p"
        ...                             ldx${inst_suffix} ${reg_size}11, ${reg_size}12, [x7]; stx${inst_suffix} w6, ${reg_size}8, ${reg_size}9, [x7];
        ...                             ldx${inst_suffix} ${reg_size}11, [x7]; stx${inst_suffix} w6, ${reg_size}8, [x7];
    ELSE
        # A32 has only one type of register i.e. 'r'
        ${instructions}=                Set variable if  "${inst_suffix}" == "xd"
        ...                             ldre${inst_suffix} r10, r11, [r7]; stre${inst_suffix} r6, r8, r9, [r7];
        ...                             ldre${inst_suffix} r10, [r7]; stre${inst_suffix} r6, r8, [r7];
    END
    [return]                        ${instructions}

Halt Unused Cores ${platform:(a32|a64)}
    IF  '${platform}' == 'a64'
        Execute Command                 cpu0_a32 IsHalted true
        Execute Command                 cpu1_a32 IsHalted true
    ELSE
        Execute Command                 cpu0_a64 IsHalted true
        Execute Command                 cpu1_a64 IsHalted true
    END

Contended Memory Value Should Increment To Correct Sum On ${platform:(a32|a64)}
    [Arguments]
    ...                             ${assembly_loop_core_0}
    ...                             ${assembly_loop_core_1}

    ${counter_reg}=                 Get Register 7 On ${platform}
    ${increments_reg}=              Get Register 8 On ${platform}
    ${step_reg}=                    Get Register 9 On ${platform}

    Halt Unused Cores ${platform}

    Execute Command                 cpu0_${platform} ExecutionMode Continuous
    Execute Command                 cpu1_${platform} ExecutionMode Continuous

    Execute Command                 logLevel 0

    # Repeatedly increment a memory location from two cores
    ${shared_memory_counter}=       Set Variable  0x40000600
    ${counter_start_value}=         Set Variable  0
    ${increments_per_core}=         Set Variable  10000000
    ${increment_step_size}=         Set Variable  1

    # Initialize shared memory counter.
    Execute Command                 sysbus WriteQuadWord ${shared_memory_counter} ${counter_start_value}

    # Set up registers for first core.
    Execute Command                 cpu0_${platform} SetRegister "${counter_reg}" ${shared_memory_counter}
    Execute Command                 cpu0_${platform} SetRegister "${increments_reg}" ${increments_per_core}
    Execute Command                 cpu0_${platform} SetRegister "${step_reg}" ${increment_step_size}

    # Set up registers for second core.
    Execute Command                 cpu1_${platform} SetRegister "${counter_reg}" ${shared_memory_counter}
    Execute Command                 cpu1_${platform} SetRegister "${increments_reg}" ${increments_per_core}
    Execute Command                 cpu1_${platform} SetRegister "${step_reg}" ${increment_step_size}

    # Place machine code at PC for both cores.
    ${assembly_size_0}=             Execute Command  cpu0_${platform} AssembleBlock ${CORE_0_PC} "${assembly_loop_core_0}"
    ${assembly_size_1}=             Execute Command  cpu1_${platform} AssembleBlock ${CORE_1_PC} "${assembly_loop_core_1}"

    # Calculate end addresses.
    # The -4 is for the 'b .' and needs to be put at the start due to weird robot/python string conversion
    ${core_0_end_pc}=               Evaluate  -4 + ${CORE_0_PC} + ${assembly_size_0}
    ${core_1_end_pc}=               Evaluate  -4 + ${CORE_1_PC} + ${assembly_size_1}

    # For detecting when loops are finished.
    Create Log Tester               0

    # Print when exiting loop.
    Execute Command                 cpu0_${platform} AddHook ${core_0_end_pc} "self.InfoLog('cpu0_${platform} finished'); self.IsHalted = True"
    Execute Command                 cpu1_${platform} AddHook ${core_1_end_pc} "self.InfoLog('cpu1_${platform} finished'); self.IsHalted = True"

    # Wait for the loops to finish...
    Wait For Log Entry              cpu0_${platform} finished  timeout=10  keep=true
    Wait For Log Entry              cpu1_${platform} finished  timeout=10  keep=true

    # In the end, the shared memory counter should've been incremented 2*increments_per_core times.
    ${counter_final_value}=         Execute Command  sysbus ReadQuadWord ${shared_memory_counter}
    Should Be Equal As Integers     ${counter_final_value}  ${2 * ${increments_per_core}}  "Counter should now have been incremented to ${2 * ${increments_per_core}} but it contains ${counter_final_value}"

Test Invalidation of Shared Memory Address On ${platform:(a32|a64)}
    [Arguments]
    ...                             ${register_size}
    ...                             ${inst_suffix}
    ...                             ${write_instructions}
    ...                             ${shared_variable_address}
    ...                             ${write_steps_core_1}=1

    ${status_reg}=                  Get Register 6 On ${platform}
    ${address_reg}=                 Get Register 7 On ${platform}
    ${reg8}=                        Get Register 8 On ${platform}

    Reset Program Counters

    # Prepare registers.
    FOR  ${core}  IN  0  1
        Execute Command                 cpu${core}_${platform} SetRegister "${address_reg}" ${shared_variable_address}
        Execute Command                 cpu${core}_${platform} SetRegister "${reg8}" ${NEW_VARIABLE_VALUE}
    END

    # Assemble load/store exclusive code for core 0.
    ${core_0_code}=                 Get Load Store Exclusive Pair On ${platform} ${inst_suffix} ${register_size}
    Execute Command                 cpu0_${platform} AssembleBlock ${CORE_0_PC} "${core_0_code}"

    Execute Command                 cpu1_${platform} AssembleBlock ${CORE_1_PC} """${write_instructions}"""

    # Interleave core 1's write between load exclusive and store exclusive of core 0, which must cause invalidation.
    Execute Command                 cpu0_${platform} Step  # load_exclusive
    Execute Command                 cpu1_${platform} Step ${write_steps_core_1}  # write
    Execute Command                 cpu0_${platform} Step  # store_exclusive

    # Check for store_exclusive failure.
    ${value}=                       Execute Command  sysbus ReadQuadWord ${shared_variable_address}
    Should Not Be Equal As Integers  ${value}  ${NEW_VARIABLE_VALUE}  Expected value at ${shared_variable_address} to not be ${NEW_VARIABLE_VALUE} after interleaving `${core_0_code}` with `${write_instructions}`
    Register Should Be Equal        ${status_reg}  1  cpuName=cpu0_${platform}

Test Store Exclusive To The Same Reservation On ${platform:(a32|a64)}
    # Try to update memory address with number 6
    # This will check if simple load/store exclusive behaves correctly

    ${status_reg}=                  Get Status Register On ${platform}
    ${address_reg}=                 Get Register 7 On ${platform}
    ${store_reg}=                   Get Register 8 On ${platform}
    ${load_reg}=                    Get Register 9 On ${platform}
    ${load_exclusive}=              Get Load Reserve On ${platform}
    ${store_exclusive}=             Get Store Exclusive On ${platform}

    # Needed because Renode's current CPU register list does not contain the 32-bit 'w' alias
    ${status_reg_index}=            Get Status Register Index On ${platform}

    ${ASSEMBLY}=                    catenate  SEPARATOR=
    ...                             ${load_exclusive} ${load_reg}, [${address_reg}];
    ...                             ${store_exclusive} ${status_reg}, ${store_reg}, [${address_reg}];
    ...                             ${store_exclusive} ${status_reg}, ${store_reg}, [${address_reg}];

    Execute Command                 cpu0_${platform} SetRegister "${store_reg}" 0x6
    Execute Command                 cpu0_${platform} SetRegister "${address_reg}" ${ORDINARY_ADDRESS}
    Execute Command                 sysbus WriteDoubleWord ${ORDINARY_ADDRESS} ${VARIABLE_VALUE}

    # Check for successful store exclusive
    Execute Command                 cpu0_${platform} AssembleBlock ${CORE_0_PC} "${ASSEMBLY}"
    Execute Command                 cpu0_${platform} Step
    Register Should Be Equal        ${load_reg}  ${VARIABLE_VALUE}  cpuName=cpu0_${platform}
    Execute Command                 cpu0_${platform} Step
    Register Should Be Equal        ${status_reg_index}  0x0  cpuName=cpu0_${platform}

    ${res}=                         Execute Command  sysbus ReadDoubleWord ${ORDINARY_ADDRESS}
    Should Be Equal As Integers     ${res}  6

    # Try to perform a store exclusive on something that isn't reserved - this should fail (returns 1)
    Execute Command                 cpu0_${platform} Step

    # Check if the store exclusive failed (correct behavior)
    Register Should Be Equal        ${status_reg_index}  0x1  cpuName=cpu0_${platform}

    ${res}=                         Execute Command  sysbus ReadDoubleWord ${ORDINARY_ADDRESS}
    Should Be Equal As Integers     ${res}  0x00000006

Test Consecutive Load Store Exclusives On Two ${platform:(a32|a64)} Cores
    ${status_reg}=                  Get Status Register On ${platform}
    ${address_reg}=                 Get Register 7 On ${platform}
    ${reg8}=                        Get Register 8 On ${platform}
    ${load_exclusive}=              Get Load Reserve On ${platform}
    ${store_exclusive}=             Get Store Exclusive On ${platform}

    # Needed because Renode's current CPU register list does not contain the 32-bit 'w' alias
    ${status_reg_index}=            Get Status Register Index On ${platform}

    ${ASSEMBLY}=                    catenate  SEPARATOR=
    ...                             ${load_exclusive} ${reg8}, [${address_reg}];
    ...                             ${store_exclusive} ${status_reg}, ${reg8}, [${address_reg}];

    Execute Command                 cpu0_${platform} SetRegister "${address_reg}" ${ORDINARY_ADDRESS}
    Execute Command                 cpu1_${platform} SetRegister "${address_reg}" ${ORDINARY_ADDRESS}

    # Check for successful store on second core
    Execute Command                 cpu1_${platform} AssembleBlock ${CORE_1_PC} "${ASSEMBLY}"
    Execute Command                 cpu1_${platform} Step 2
    Register Should Be Equal        ${status_reg_index}  0x0  cpuName=cpu1_${platform}

    # Check for successful store on first core
    Execute Command                 cpu0_${platform} AssembleBlock ${CORE_0_PC} "${ASSEMBLY}"
    Execute Command                 cpu0_${platform} Step 2
    Register Should Be Equal        ${status_reg_index}  0x0  cpuName=cpu0_${platform}

Test Single Core Looping Load Store Exclusive Pairs To Same Reservation On ${platform:(a32|a64)}
    ${status_reg}=                  Get Status Register On ${platform}
    ${address_reg}=                 Get Register 7 On ${platform}
    ${accumulator_reg}=             Get Register 8 On ${platform}
    ${iteration_reg}=               Get Register 9 On ${platform}
    ${load_excl}=                   Get Load Reserve On ${platform}
    ${store_excl}=                  Get Store Exclusive On ${platform}

    ${ASSEMBLY}=                    catenate  SEPARATOR=
    ...                             repeat: ${load_excl} ${accumulator_reg}, [${address_reg}];
    ...                             add ${accumulator_reg}, ${accumulator_reg}, #1;
    ...                             ${store_excl} ${status_reg}, ${accumulator_reg}, [${address_reg}];
    ...                             cmp ${status_reg}, #0;
    ...                             bne repeat;
    ...                             subs ${iteration_reg}, ${iteration_reg}, #1;
    ...                             bne repeat;
    ...                             b .;

    # Needed because Renode's current CPU register list does not contain the 32-bit 'w' alias
    ${status_reg_index}=            Get Status Register Index On ${platform}

    ${start_value}=                 Set Variable  0

    Execute Command                 sysbus WriteDoubleWord ${ORDINARY_ADDRESS} ${start_value}

    # Set up registers
    Execute Command                 cpu0_${platform} SetRegister "${address_reg}" ${ORDINARY_ADDRESS}
    Execute Command                 cpu0_${platform} SetRegister "${iteration_reg}" ${LOOP_ITERATIONS}

    # The assembly increments the value in [address_reg] until enough loop iterations have run.
    Execute Command                 cpu0_${platform} AssembleBlock ${CORE_0_PC} "${ASSEMBLY}"

    FOR  ${i}  IN RANGE  ${start_value}  ${LOOP_ITERATIONS}
        ${next_i}=                      Set Variable  ${${i} + 1}

        # Execute load reserve, which should give the memory counter value
        Execute Command                 cpu0_${platform} Step
        Register Should Be Equal        ${accumulator_reg}  ${i}  cpuName=cpu0_${platform}

        # Execute add, which should increment the counter value
        Execute Command                 cpu0_${platform} Step
        Register Should Be Equal        ${accumulator_reg}  ${next_i}  cpuName=cpu0_${platform}

        # Execute store exclusive, which should succeed in storing the incremented value to memory
        Execute Command                 cpu0_${platform} Step
        Register Should Be Equal        ${status_reg_index}  0  cpuName=cpu0_${platform}
        ${res}=                         Execute Command  sysbus ReadDoubleWord ${ORDINARY_ADDRESS}
        Should Be Equal As Integers     ${res}  ${next_i}  "Memory location should now contain ${next_i} but it contains ${res}"

        # The cmp,bne shouldn't need to jump to repeat, just step over it.
        Execute Command                 cpu0_${platform} Step 2

        # Check for successful decrement of loop counter
        Execute Command                 cpu0_${platform} Step
        Register Should Be Equal        ${iteration_reg}  ${${LOOP_ITERATIONS} - ${next_i}}  cpuName=cpu0_${platform}

        # jump back to start of next loop (if not at final iteration)
        Execute Command                 cpu0_${platform} Step
    END

    # In the end, it should've been incremented LOOP_ITERATIONS times.
    Register Should Be Equal        ${iteration_reg}  0  cpuName=cpu0_${platform}
    ${res}=                         Execute Command  sysbus ReadDoubleWord ${ORDINARY_ADDRESS}
    Should Be Equal As Integers     ${res}  ${LOOP_ITERATIONS}  "Memory location should now have been incremented to ${LOOP_ITERATIONS} but it contains ${res}"

*** Test Cases ***
Should Handle Multiple Store Exclusives To The Same Reservation a32
    Test Store Exclusive To The Same Reservation On a32

Should Handle Multiple Store Exclusives To The Same Reservation a64
    Test Store Exclusive To The Same Reservation On a64

Should Handle Consecutive Load Store Exclusives On Two Cores a32
    Test Consecutive Load Store Exclusives On Two a32 Cores

Should Handle Consecutive Load Store Exclusives On Two Cores a64
    Test Consecutive Load Store Exclusives On Two a64 Cores

Should Handle Looping Single Core LDREX/STREX Pairs To Same Reservation a32
    Test Single Core Looping Load Store Exclusive Pairs To Same Reservation On a32

Should Handle Looping Single Core LDXR/STXR Pairs To Same Reservation a64
    Test Single Core Looping Load Store Exclusive Pairs To Same Reservation On a64

Two LDREX/STREX Loops Should Increment To Correct Sum
    Contended Memory Value Should Increment To Correct Sum On a32
    ...                             assembly_loop_core_0=${ASSEMBLY_LDREX_STREX_LOOP}
    ...                             assembly_loop_core_1=${ASSEMBLY_LDREX_STREX_LOOP}

Two LDXR/STXR Loops Should Increment To Correct Sum
    Contended Memory Value Should Increment To Correct Sum On a64
    ...                             assembly_loop_core_0=${ASSEMBLY_LDX_STX_LOOP}
    ...                             assembly_loop_core_1=${ASSEMBLY_LDX_STX_LOOP}

Two LDXP/STXP Loops Should Increment To Correct Sum
    Contended Memory Value Should Increment To Correct Sum On a64
    ...                             assembly_loop_core_0=${ASSEMBLY_LDX_STX_128_LOOP}
    ...                             assembly_loop_core_1=${ASSEMBLY_LDX_STX_128_LOOP}

LDXR/STXR And LDADD Loops Should Increment To Correct Sum
    ${ASSEMBLY_LDADD_LOOP}=         catenate  SEPARATOR=
    ...                             repeat: ldadd x9, x10, [x7];
    ...                             add x8, x8, #-1;
    ...                             cbnz x8, repeat;
    ...                             b .;
    Contended Memory Value Should Increment To Correct Sum On a64
    ...                             assembly_loop_core_0=${ASSEMBLY_LDADD_LOOP}
    ...                             assembly_loop_core_1=${ASSEMBLY_LDX_STX_LOOP}

Writes To Reservation Should Cause Invalidation On a64
    [Tags]                          robot:continue-on-failure
    [Template]                      Test Invalidation of Shared Memory Address On a64
    FOR  ${address}  IN  ${ORDINARY_ADDRESS}  ${MMIO_ADDRESS}
        FOR  ${cpu0_register_size}  IN  x  w
            FOR  ${inst_suffix}  IN  r  p
                FOR  ${cpu1_reg_size}  IN  x  w
                    ${cpu0_register_size}
                    ...                             ${inst_suffix}
                    ...                             ldxr ${cpu1_reg_size}11, [x7]; stxr w13, ${cpu1_reg_size}12, [x7];
                    ...                             ${address}
                    ...                             write_steps_core_1=2

                    ${cpu0_register_size}
                    ...                             ${inst_suffix}
                    ...                             ldxp ${cpu1_reg_size}11, ${cpu1_reg_size}12, [x7]; stxp w13, ${cpu1_reg_size}11, ${cpu1_reg_size}12, [x7];
                    ...                             ${address}
                    ...                             write_steps_core_1=2

                    ${cpu0_register_size}
                    ...                             ${inst_suffix}
                    ...                             casp ${cpu1_reg_size}12, ${cpu1_reg_size}13, ${cpu1_reg_size}0, ${cpu1_reg_size}1, [x7];
                    ...                             ${address}

                    ${cpu0_register_size}
                    ...                             ${inst_suffix}
                    ...                             cas ${cpu1_reg_size}12, ${cpu1_reg_size}0, [x7];
                    ...                             ${address}

                    ${cpu0_register_size}
                    ...                             ${inst_suffix}
                    ...                             ldadd ${cpu1_reg_size}0, ${cpu1_reg_size}0, [x7];
                    ...                             ${address}

                    ${cpu0_register_size}
                    ...                             ${inst_suffix}
                    ...                             stp ${cpu1_reg_size}10, ${cpu1_reg_size}11, [x7];
                    ...                             ${address}

                    ${cpu0_register_size}
                    ...                             ${inst_suffix}
                    ...                             stnp ${cpu1_reg_size}10, ${cpu1_reg_size}11, [x7];
                    ...                             ${address}

                    FOR  ${store_type}  IN  r  ur  tr
                        ${cpu0_register_size}
                        ...                             ${inst_suffix}
                        ...                             st${store_type} ${cpu1_reg_size}12, [x7];
                        ...                             ${address}
                    END
                END

                # This is put outside of the above loop because these store instructions only support the 'w' register variant
                FOR  ${store_type}  IN  rb  rh  urb  urh  trb  trh
                    ${cpu0_register_size}
                    ...                             ${inst_suffix}
                    ...                             st${store_type} w12, [x7];
                    ...                             ${address}
                END
            END
        END
    END

Writes To Reservation Should Cause Invalidation On a32
    # A32 does not support Large System Extensions (LSE),
    # so the available atomic instructions are more limited.
    # SWP on A32 ARMv8 is not supported.
    [Template]                      Test Invalidation of Shared Memory Address On a32
    FOR  ${address}  IN  ${ORDINARY_ADDRESS}  ${MMIO_ADDRESS}
        FOR  ${inst_suffix}  IN  x  xb  xh  xd
            r  # register_size
            ...                             ${inst_suffix}
            ...                             ldrex r0, [r7]; strex r0, r0, [r7];
            ...                             ${address}
            ...                             write_steps_core_1=2

            FOR  ${access_width}  IN  r  rb  rh
                r  # register_size
                ...                             ${inst_suffix}
                ...                             st${access_width} r0, [r7];
                ...                             ${address}
            END
        END
    END
