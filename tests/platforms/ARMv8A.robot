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

    Create Terminal Tester        ${UART}

Step And Verify Accumulator
    [Arguments]    ${expected_value}

    Execute Command               cpu Step
    ${acc} =  Execute Command     cpu GetRegisterUnsafe 0
    Should Be Equal As Integers   ${acc}  ${expected_value}  base=16

*** Test Cases ***
Test CRC32X
    Create Machine
    Execute Command               cpu ExecutionMode SingleStepBlocking
    Start Emulation

    Execute Command               sysbus WriteDoubleWord 0x0 0x9ac34c00  # crc32x  w0, w0, x3
    Execute Command               sysbus WriteDoubleWord 0x4 0x9ac44c00  # crc32x  w0, w0, x4

    # Set the initial accumulator value.
    Execute Command               cpu SetRegisterUnsafeUlong 0 0xcafebee

    # Set source registers.
    Execute Command               cpu SetRegisterUnsafeUlong 3 0x1234567890abcdef
    Execute Command               cpu SetRegisterUnsafeUlong 4 0xfedcba0987654321

    # CRC has many caveats with conversions done on input/output/accumulator.
    # Let's make sure a proper version is used. Mono used to overwrite tlib's
    # implementation with zlib's crc32 which internally converts accumulator
    # and output and then the results here are 0x4ab0398 and 0xf77db35e.
    Step And Verify Accumulator   0x6189dcf1
    Step And Verify Accumulator   0x1bc6f80b

Test Running the Hello World Zephyr Sample
    Create Machine
    Execute Command               sysbus LoadELF ${ZEPHYR_HELLO_WORLD_ELF}

    Start Emulation

    Wait For Line On Uart         Booting Zephyr OS
    Wait For Line On Uart         Hello World!

Test Running the Zephyr Synchronization Sample
    Create Machine
    Execute Command               sysbus LoadELF ${ZEPHYR_SYNCHRONIZATION_ELF}

    Start Emulation

    Wait For Line On Uart         Booting Zephyr OS
    Wait For Line On Uart         thread_a: Hello World from cpu 0
    Wait For Line On Uart         thread_b: Hello World from cpu 0
    Wait For Line On Uart         thread_a: Hello World from cpu 0
    Wait For Line On Uart         thread_b: Hello World from cpu 0

Test Running the Zephyr Philosophers Sample
    Create Machine
    Execute Command               sysbus LoadELF ${ZEPHYR_PHILOSOPHERS_ELF}

    Start Emulation

    Wait For Line On Uart         Booting Zephyr OS
    Wait For Line On Uart         Philosopher 5.*STARVING  treatAsRegex=true
    Wait For Line On Uart         Philosopher 5.*HOLDING ONE FORK  treatAsRegex=true
    Wait For Line On Uart         Philosopher 5.*EATING  treatAsRegex=true
    Wait For Line On Uart         Philosopher 5.*THINKING  treatAsRegex=true

Test Running the Zephyr Kernel FPU Sharing Generic Test
    Create Machine
    Execute Command               sysbus LoadELF ${ZEPHYR_FPU_SHARING_ELF}

    Start Emulation

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

    Start Emulation

    Wait For Line On Uart         Booting all finished, dropped to user space
    Wait For Line On Uart         client: what's the answer to 342 + 74 + 283 + 37 + 534 ?
    Wait For Line On Uart         client: result was 1270
