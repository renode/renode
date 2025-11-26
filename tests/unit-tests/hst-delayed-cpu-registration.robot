*** Variables ***
${SHARED_ADDRESS}                   0x81000000
${PC}                               0x80000000
${VARIABLE_VALUE}                   0x5
${NEW_VARIABLE_VALUE}               0xbeeeeeef

# Registers used
${a0}                               10
${a1}                               11
${a2}                               12
${a3}                               13

*** Keywords ***
Add CPU ${core}
    [Arguments]                     ${value}
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu_${core}: CPU.RiscV64 @ sysbus { timeProvider: empty; cpuType: \\"rv64gc\\"}"
    Execute Command                 cpu_${core} ExecutionMode SingleStep

    Execute Command                 cpu_${core} PC ${PC}
    Execute Command                 cpu_${core} SetRegister ${a0} ${SHARED_ADDRESS}
    Execute Command                 cpu_${core} SetRegister ${a2} ${value}

*** Test Cases ***
Should Register HST For Both CPUs When Second CPU Is Added
    # Create a very simple machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "ddr: Memory.MappedMemory @ sysbus 0x80000000 { size: 0x80000000 }"
    Create Log Tester               0
    Execute Command                 logLevel 0

    # Just in case check if store table is not allocated nor initialized at machine creation
    Should Not Be In Log            Allocating store table with size
    Should Not Be In Log            initialize_store_table: initializing with ptr

    # Add first CPU
    Add CPU 0                       ${NEW_VARIABLE_VALUE}

    # Check if store table is not allocated nor initialized for one CPU
    Should Not Be In Log            Allocating store table with size
    Should Not Be In Log            initialize_store_table: initializing with ptr

    # Add second CPU
    Add CPU 1                       ${VARIABLE_VALUE}

    # Now store table should be allocated
    Wait For Log Entry              Store table allocated
    # Both cores should get pointers to the store table
    Wait For Log Entry              cpu_0: initialize_store_table: initializing with ptr
    Wait For Log Entry              cpu_1: initialize_store_table: initializing with ptr

    # Assemble LR/SC code
    ${code}=                        catenate  SEPARATOR=${\n}
    ...                             lr.d a1, (a0);
    ...                             sc.d a3, a2, (a0);
    Execute Command                 cpu_0 AssembleBlock ${PC} """${code}"""

    # Now check if store table is properly registered for cpu_0
    Execute Command                 sysbus WriteQuadWord ${SHARED_ADDRESS} ${VARIABLE_VALUE}
    Execute Command                 cpu_0 Step  # LR
    Execute Command                 cpu_1 Step 2  # write
    Execute Command                 cpu_0 Step  # SC

    # Check for SC failure.
    ${value}=                       Execute Command  sysbus ReadQuadWord ${SHARED_ADDRESS}
    Should Not Be Equal As Integers  ${value}  ${NEW_VARIABLE_VALUE}  Expected value at ${SHARED_ADDRESS} to not be ${NEW_VARIABLE_VALUE} after interleaving LR/SC
    Register Should Be Equal        ${a3}  1  cpuName=cpu_0
