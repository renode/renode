*** Variables ***
${UART}                           sysbus.uart0
${URI}                            @https://dl.antmicro.com/projects/renode

${ZEPHYR_HELLO_WORLD_ELF}         ${URI}/cortex_a53-zephyr-hello_world.elf-s_34096-272b1e50f90c8240d875daf679223f2d769e77dd
${ZEPHYR_SYNCHRONIZATION_ELF}     ${URI}/virt-a53--zephyr-synchronization.elf-s_582816-bb556dc10df7f09918db3c5d1f298cdd3f3290f3
${ZEPHYR_PHILOSOPHERS_ELF}        ${URI}/zephyr_philosophers_a53.elf-s_731440-e6e5bd1c2151b7e5d38d272b01108493e8ef88b4
${ZEPHYR_FPU_SHARING_ELF}         ${URI}/zephyr_tests_kernel_fpu_sharing_generic_qemu_cortex_a53.elf-s_763936-8839da556c9913ed1817fc213a79c60de8f0d8e2

${SEL4_ADDER_ELF}                 ${URI}/camkes_adder_elfloader_aarch64-s_3408064-4385f32dd7a3235af3905c0a473598fc90853b7a

*** Keywords ***
Create Machine
    [Arguments]    ${gic_version}=3

    Execute Command               using sysbus
    Execute Command               mach create
    Execute Command               machine LoadPlatformDescription @platforms/cpus/cortex-a53-gicv${gic_version}.repl

    Create Terminal Tester        ${UART}  defaultPauseEmulation=True
    Execute Command               showAnalyzer ${UART}

Step And Verify Accumulator
    [Arguments]    ${expected_value}

    Execute Command               cpu Step
    ${acc} =  Execute Command     cpu GetRegister 0
    Should Be Equal As Integers   ${acc}  ${expected_value}  base=16

Verify System Registers
    [Arguments]    ${names}  ${expected_values}

    ${names_length} =   Get Length    ${names}
    ${values_length} =  Get Length    ${expected_values}
    Should Be Equal  ${names_length}  ${values_length}

    ${all_values} =  Execute Command    cpu GetAllSystemRegisterValues
    FOR    ${index}    IN RANGE  ${names_length}
        ${name} =  Set Variable  ${names[${index}]}
        ${expected_value} =  Set Variable  ${expected_values[${index}]}

        ${match} =  Get Regexp Matches  ${all_values}  ${name}.*(0x[0-9A-F]+)  1  flags=MULTILINE
        IF  ${match}
            Should Be Equal    ${match[0]}    ${expected_value}
            ...  msg="Invalid value of '${name}' system register: ${match[0]}; expected: ${expected_value}"
        ELSE
            Fail  "${name} not found in the system registers list: ${all_values}"
        END
    END

Verify Timer Register
    [Arguments]    ${system_register_name}    ${timer_register_name}

    Execute Command               cpu GetSystemRegisterValue "${system_register_name}"
    Wait For Log Entry            Read from ${timer_register_name}

*** Test Cases ***
Should Get Correct EL and SS on CPU Creation
    # This platform uses `Cortex-A53` CPU - ARMv8A
    # We only check if EL and SS are reflected correctly on C# side, for their usage in peripherals
    Create Machine

    ${ss}=                             Execute Command  sysbus.cpu SecurityState
    ${el}=                             Execute Command  sysbus.cpu ExceptionLevel

    Should Be Equal As Strings         ${ss.split()[0].strip()}  Secure
    Should Be Equal As Strings         ${el.split()[0].strip()}  EL3_MonitorMode

Test Accessing ARM Generic Timer Registers Through AArch64 System Registers
    Create Machine
    Create Log Tester             0
    Execute Command               logLevel 0 cpu.timer

    # Read logs for '*Count' registers are disabled by default because they tend to be read very often.
    Execute Command               cpu.timer EnableCountReadLogs true

    # AArch64 system register reads go through tlib and are handled by ARM Generic Timer which prints a DEBUG access log.
    # The log line is used to verify that a proper peripheral register is connected to the given AArch64 system register.
    Verify Timer Register         CNTFRQ_EL0         Frequency
    Verify Timer Register         CNTHCTL_EL2        HypervisorControl
    Verify Timer Register         CNTKCTL_EL1        KernelControl

    Verify Timer Register         CNTPCT_EL0         PhysicalCount
    Verify Timer Register         CNTPCTSS_EL0       PhysicalSelfSynchronizedCount
    Verify Timer Register         CNTPOFF_EL2        PhysicalOffset

    Verify Timer Register         CNTVCT_EL0         VirtualCount
    Verify Timer Register         CNTVCTSS_EL0       VirtualSelfSynchronizedCount
    Verify Timer Register         CNTVOFF_EL2        VirtualOffset

    Verify Timer Register         CNTHP_CTL_EL2      NonSecureEL2PhysicalTimerControl
    Verify Timer Register         CNTHP_CVAL_EL2     NonSecureEL2PhysicalTimerCompareValue
    Verify Timer Register         CNTHP_TVAL_EL2     NonSecureEL2PhysicalTimerValue

    Verify Timer Register         CNTHPS_CTL_EL2     SecureEL2PhysicalTimerControl
    Verify Timer Register         CNTHPS_CVAL_EL2    SecureEL2PhysicalTimerCompareValue
    Verify Timer Register         CNTHPS_TVAL_EL2    SecureEL2PhysicalTimerValue

    Verify Timer Register         CNTHV_CTL_EL2      NonSecureEL2VirtualTimerControl
    Verify Timer Register         CNTHV_CVAL_EL2     NonSecureEL2VirtualTimerCompareValue
    Verify Timer Register         CNTHV_TVAL_EL2     NonSecureEL2VirtualTimerValue

    Verify Timer Register         CNTHVS_CTL_EL2     SecureEL2VirtualTimerControl
    Verify Timer Register         CNTHVS_CVAL_EL2    SecureEL2VirtualTimerCompareValue
    Verify Timer Register         CNTHVS_TVAL_EL2    SecureEL2VirtualTimerValue

    Verify Timer Register         CNTP_CTL_EL0       EL1PhysicalTimerControl
    Verify Timer Register         CNTP_CVAL_EL0      EL1PhysicalTimerCompareValue
    Verify Timer Register         CNTP_TVAL_EL0      EL1PhysicalTimerValue

    Verify Timer Register         CNTPS_CTL_EL1      EL3PhysicalTimerControl
    Verify Timer Register         CNTPS_CVAL_EL1     EL3PhysicalTimerCompareValue
    Verify Timer Register         CNTPS_TVAL_EL1     EL3PhysicalTimerValue

    Verify Timer Register         CNTV_CTL_EL0       EL1VirtualTimerControl
    Verify Timer Register         CNTV_CVAL_EL0      EL1VirtualTimerCompareValue
    Verify Timer Register         CNTV_TVAL_EL0      EL1VirtualTimerValue

Test Accessing System Registers
    Create Machine

    ${MIDR_val} =         Set Variable  0x410FD034
    ${new_DAIF} =         Set Variable  0x180
    ${new_NZCV} =         Set Variable  0xA0000000
    ${new_SCTLR} =        Set Variable  0xDEADBEEF

    @{register_names} =   Create List   DAIF   MIDR_EL1     NZCV        SCTLR_EL3
    @{expected_values} =  Create List   0x3C0  ${MIDR_val}  0x40000000  0xC50838

    Verify System Registers       ${register_names}  ${expected_values}

    # MIDR_EL1 is a Read-Only register. Setting it should fail.
    Run Keyword And Expect Error  KeywordException: *Writing the MIDR_EL1 register isn't supported*
    ...  Execute Command          cpu SetSystemRegisterValue "MIDR_EL1" 0xDEADBEEF

    Execute Command               cpu SetSystemRegisterValue "DAIF" ${new_DAIF}
    Execute Command               cpu SetSystemRegisterValue "NZCV" ${new_NZCV}
    Execute Command               cpu SetSystemRegisterValue "SCTLR_EL3" ${new_SCTLR}

    @{expected_values} =  Create List   ${new_DAIF}  ${MIDR_val}  ${new_NZCV}  ${new_SCTLR}
    Verify System Registers       ${register_names}  ${expected_values}

Test CRC32X
    Create Machine

    Execute Command               sysbus WriteDoubleWord 0x0 0x9ac34c00  # crc32x  w0, w0, x3
    Execute Command               sysbus WriteDoubleWord 0x4 0x9ac44c00  # crc32x  w0, w0, x4

    # Set the initial accumulator value.
    Execute Command               cpu SetRegisterUlong 0 0xcafebee

    # Set source registers.
    Execute Command               cpu SetRegisterUlong 3 0x1234567890abcdef
    Execute Command               cpu SetRegisterUlong 4 0xfedcba0987654321

    # CRC has many caveats with conversions done on input/output/accumulator.
    # Let's make sure a proper version is used. Mono used to overwrite tlib's
    # implementation with zlib's crc32 which internally converts accumulator
    # and output and then the results here are 0x4ab0398 and 0xf77db35e.
    Step And Verify Accumulator   0x6189dcf1
    Step And Verify Accumulator   0x1bc6f80b

Test CRC32CX
    Create Machine

    Execute Command               sysbus WriteDoubleWord 0x0 0x9ac35c00  # crc32cx  w0, w0, x3
    Execute Command               sysbus WriteDoubleWord 0x4 0x9ac45c00  # crc32cx  w0, w0, x4

    # Set the initial accumulator value.
    Execute Command               cpu SetRegisterUlong 0 0xcafebee

    # Set source registers.
    Execute Command               cpu SetRegisterUlong 3 0x1234567890abcdef
    Execute Command               cpu SetRegisterUlong 4 0xfedcba0987654321

    Step And Verify Accumulator   0x8da20236
    Step And Verify Accumulator   0xbcfc085a

Test Running the Hello World Zephyr Sample
    Create Machine
    Execute Command               sysbus LoadELF ${ZEPHYR_HELLO_WORLD_ELF}

    Wait For Line On Uart         Booting Zephyr OS
    Provides                      zephyr-hello-world-after-booting
    Wait For Line On Uart         Hello World!

Test Resuming Zephyr Hello World After Deserialization
    Requires                      zephyr-hello-world-after-booting
    Execute Command               showAnalyzer ${UART}
    Wait For Line On Uart         Hello World!

Test Running the Zephyr Synchronization Sample
    Create Machine
    Execute Command               sysbus LoadELF ${ZEPHYR_SYNCHRONIZATION_ELF}

    Wait For Line On Uart         Booting Zephyr OS
    Wait For Line On Uart         thread_a: Hello World from cpu 0
    Wait For Line On Uart         thread_b: Hello World from cpu 0
    Wait For Line On Uart         thread_a: Hello World from cpu 0
    Wait For Line On Uart         thread_b: Hello World from cpu 0

Test Running the Zephyr Philosophers Sample
    Create Machine
    Execute Command               sysbus LoadELF ${ZEPHYR_PHILOSOPHERS_ELF}

    Wait For Line On Uart         Booting Zephyr OS
    Wait For Line On Uart         Philosopher 5.*STARVING  treatAsRegex=true
    Wait For Line On Uart         Philosopher 5.*HOLDING ONE FORK  treatAsRegex=true
    Wait For Line On Uart         Philosopher 5.*EATING  treatAsRegex=true
    Wait For Line On Uart         Philosopher 5.*THINKING  treatAsRegex=true

Test Running the Zephyr Kernel FPU Sharing Generic Test
    Create Machine
    Execute Command               sysbus LoadELF ${ZEPHYR_FPU_SHARING_ELF}

    Wait For Line On Uart         Booting Zephyr OS
    Wait For Line On Uart         Running TESTSUITE fpu_sharing_generic

    # The PASS line is currently printed after about 10.1 virtual seconds from the start.
    Wait For Line On Uart         START - test_load_store
    Wait For Line On Uart         PASS - test_load_store  timeout=12

    # The test prints 5 "Pi calculation OK after X (high) + Y (low) tests" lines.
    # Let's finish testing after the first one. It takes about 5 virtual seconds to
    # reach it from the start and the whole test takes about 50 virtual seconds.
    Wait For Line On Uart         START - test_pi
    Wait For Line On Uart         Pi calculation OK

Test Running the seL4 Adder Sample
    Create Machine                gic_version=2
    Execute Command               sysbus LoadELF ${SEL4_ADDER_ELF}
    # seL4 expects to be at most in EL2
    Execute Command               cpu SetAvailableExceptionLevels true false
    # Initialize UART since we don't have a bootloader
    Execute Command               ${UART} WriteDoubleWord 0x30 0x301
    # Set 7-bit word length to hush the warning that 5-bit WLEN is unsupported.
    Execute Command               ${UART} WriteDoubleWord 0x2c 0x40  #b10 << 5

    Wait For Line On Uart         Booting all finished, dropped to user space
    Wait For Line On Uart         client: what's the answer to 342 + 74 + 283 + 37 + 534 ?
    Wait For Line On Uart         client: result was 1270
