********************************** Variables **********************************

${URI}                              @https://dl.antmicro.com/projects/renode

${MEM_PROTECT_BINARY}               ${URI}/zephyr_tests_kernel_mem_protect_mem_protect_fvp_baser_aemv8r_aarch32.elf-s_1588116-5e9567fdd71944d758098fb6078c399703fb8135
${PROTECTION_BINARY}                ${URI}/zephyr_tests_kernel_mem_protect_protection_fvp_baser_aemv8r_aarch32.elf-s_523044-d3f20216e74913fa258d21404c83282f27d7749b
${STACKPROT_BINARY}                 ${URI}/zephyr_tests_kernel_mem_protect_stackprot_fvp_baser_aemv8r_aarch32.elf-s_1305768-fc659d9da17b27a39236a6fbb914fdad83103409
${USERSPACE_BINARY}                 ${URI}/zephyr_tests_kernel_mem_protect_userspace_fvp_baser_aemv8r_aarch32.elf-s_1418592-34442d722b26aa21e9c62b9dc31db2fba9871837

${UART}                             sysbus.uart0

${NON_DEFAULT_REGION_COUNT}         24

*********************************** Keywords **********************************
Initialize Emulation
    [Arguments]                     ${binary}  ${region_count}=None

    Execute Command                 mach create

    IF  ${region_count} != None
        ${mpu_regions_string}=      Catenate  SEPARATOR=\n
        ...                         """
        ...                         using "platforms/cpus/cortex-r52.repl"
        ...
        ...                         cpu:
        ...                         ${SPACE*4}mpuRegionsCount: ${region_count}
        ...                         """
        Execute Command             machine LoadPlatformDescriptionFromString ${mpu_regions_string}
    ELSE
        Execute Command             machine LoadPlatformDescription @platforms/cpus/cortex-r52.repl
    END

    Execute Command                 sysbus LoadELF ${binary}
    Set Default Uart Timeout        1
    Create Terminal Tester          ${UART}

Run Test
    [Arguments]                     ${bin}  ${region_count}=None
    Initialize Emulation            ${bin}  ${region_count}
    Wait For Line On Uart           TESTSUITE [a-z_]+ succeeded  treatAsRegex=true

Expect Mpu Regions Count
    [Arguments]                     ${expected_count}
    ${reg_value}=                   Execute Command  sysbus.cpu GetSystemRegisterValue "MPUIR"
    ${regions_count}=               Evaluate         int(${reg_value}) >> 8

    Should Be Equal As Integers     ${regions_count}  ${expected_count}

********************************** Test Cases *********************************
Should have correct default configuration
    Initialize Emulation            ${PROTECTION_BINARY}
    Expect Mpu Regions Count        16

Should pass the protection test
    Run Test                        ${PROTECTION_BINARY}

Should pass the mem_protect test
    Run Test                        ${MEM_PROTECT_BINARY}

Should pass the userspace test
    Run Test                        ${USERSPACE_BINARY}

Should pass the stackprotect test
    Run Test                        ${STACKPROT_BINARY}

# For Cortex-R Zephyr retrieves count of MPU regions in runtime.
# The same binary can be used for various regions counts.
Should respect the configured number of regions with more regions
    Initialize Emulation            ${PROTECTION_BINARY}  ${NON_DEFAULT_REGION_COUNT}
    Expect Mpu Regions Count        ${NON_DEFAULT_REGION_COUNT}

Should pass the protection test with more regions
    Run Test                        ${PROTECTION_BINARY}  ${NON_DEFAULT_REGION_COUNT}

Should pass the mem_protect test with more regions
    Run Test                        ${MEM_PROTECT_BINARY}  ${NON_DEFAULT_REGION_COUNT}

Should pass the userspace test with more regions
    Run Test                        ${USERSPACE_BINARY}  ${NON_DEFAULT_REGION_COUNT}

Should pass the stackprotect test with more regions
    Run Test                        ${STACKPROT_BINARY}  ${NON_DEFAULT_REGION_COUNT}
