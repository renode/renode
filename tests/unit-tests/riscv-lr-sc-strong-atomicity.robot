*** Settings ***
Test Setup                          Create Machine
Library                             Collections

*** Variables ***
${PLATFORM_PATH}                    ${CURDIR}${/}riscv-lr-sc-strong-atomicity.repl
${ORDINARY_ADDRESS}                 0x81000000
${MMIO_ADDRESS}                     0x00100000
${VARIABLE_ADDRESS_CPU1}            0x81000000
${VARIABLE_ADDRESS_CPU2}            0x81000100
${CORE_0_PC}                        0x80000000
${CORE_1_PC}                        0x80000100
${VARIABLE_VALUE}                   0x5
${NEW_VARIABLE_VALUE}               0xbeeeeeef

# Registers used
${x0}                               0
${a0}                               10
${a1}                               11
${a2}                               12
${a3}                               13
${a4}                               14

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription "${PLATFORM_PATH}"

    Execute Command                 emulation SingleStepBlocking False

    Reset Program Counters

Get Cpu On ${platform:(RV32|RV64)}
    ${cpu}=                         Set variable if  "${platform}" == "RV64"
    ...                             cpu
    ...                             cpu32
    [return]                        ${cpu}

Get Native Access Width On ${platform:(RV32|RV64)}
    ${width}=                       Set variable if  "${platform}" == "RV64"
    ...                             d
    ...                             w
    [return]                        ${width}

Get Supported Access Widths On ${platform:(RV32|RV64)}
    @{rv32_widths}=                 Create List  b  h  w
    @{rv64_only_widths}=            Create List  d
    @{rv64_widths}=                 Combine Lists  ${rv32_widths}  ${rv64_only_widths}

    ${widths}=                      Set variable if  "${platform}" == "RV64"
    ...                             ${rv64_widths}
    ...                             ${rv32_widths}

    [return]                        ${widths}

Reset Program Counters
    FOR  ${platform}  IN  RV64  RV32
        ${cpu}=                         Get Cpu On ${platform}
        Execute Command                 ${cpu}_0 PC ${CORE_0_PC}
        Execute Command                 ${cpu}_1 PC ${CORE_1_PC}
    END

${platform:(RV32|RV64)} Should Invalidate Reservation On Memory Write
    # Invariant: executing `write_steps` of `write_instructions` sets memory location `shared_variable_address` to `VARIABLE_VALUE`.
    # They intentionally set it to the same value as before, since we want to check that the store itself is detected regardless of value change.
    [Arguments]
    ...                             ${size}
    ...                             ${shared_variable_address}
    ...                             ${write_instructions}
    ...                             ${write_steps}=1

    # Reset PC
    Reset Program Counters

    # Place shared value in memory.
    Execute Command                 sysbus WriteQuadWord ${shared_variable_address} ${VARIABLE_VALUE}

    ${cpu}=                         Get Cpu On ${platform}

    # Prepare registers.
    FOR  ${core}  IN  0  1
        Execute Command                 ${cpu}_${core} SetRegister ${a0} ${shared_variable_address}
        Execute Command                 ${cpu}_${core} SetRegister ${a2} ${NEW_VARIABLE_VALUE}
        Execute Command                 ${cpu}_${core} SetRegister ${a4} ${VARIABLE_VALUE}
    END

    # Assemble LR/SC code for core 0.
    ${core_0_code}=                 catenate  SEPARATOR=${\n}
    ...                             lr.${size} a1, (a0);
    ...                             sc.${size} a3, a2, (a0);
    Execute Command                 ${cpu}_0 AssembleBlock ${CORE_0_PC} """${core_0_code}"""

    # Assemble memory write code for core 1.
    Execute Command                 ${cpu}_1 AssembleBlock ${CORE_1_PC} """${write_instructions}"""

    # Interleave core 1's write between LR and SC of core 0, which must cause invalidation.
    Execute Command                 ${cpu}_0 Step  # LR
    Execute Command                 ${cpu}_1 Step ${write_steps}  # write
    Execute Command                 ${cpu}_0 Step  # SC

    # Check for SC failure.
    ${value}=                       Execute Command  sysbus ReadQuadWord ${shared_variable_address}
    Should Not Be Equal As Integers  ${value}  ${NEW_VARIABLE_VALUE}  Expected value at ${shared_variable_address} to not be ${NEW_VARIABLE_VALUE} after interleaving LR/SC with `${write_instructions}` on ${platform}
    Register Should Be Equal        ${a3}  1  cpuName=${cpu}_0

*** Test Cases ***
Writes To Reservation Should Cause Invalidation
    [Tags]                          robot:continue-on-failure
    FOR  ${platform}  IN  RV64  RV32
        FOR  ${address}  IN  ${ORDINARY_ADDRESS}  ${MMIO_ADDRESS}
            ${native_width}=                Get Native Access Width On ${platform}
            ${supported_widths}=            Get Supported Access Widths On ${platform}

            ${platform} Should Invalidate Reservation On Memory Write  ${native_width}  ${address}
            ...                             lr.${native_width} a6, (a0); sc.${native_width} s2, a4, (a0);
            ...                             write_steps=2

            ${platform} Should Invalidate Reservation On Memory Write  ${native_width}  ${address}
            ...                             amoswap.${native_width} s2, a4, (a0);

            ${platform} Should Invalidate Reservation On Memory Write  ${native_width}  ${address}
            ...                             amoadd.${native_width} a4, x0, (a0);

            FOR  ${width}  IN  @{supported_widths}
                ${platform} Should Invalidate Reservation On Memory Write  ${native_width}  ${address}
                ...                             s${width} a4, (a0);
            END
        END
    END
