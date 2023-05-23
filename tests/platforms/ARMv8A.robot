*** Variables ***
${UART}                           sysbus.uart0
${URI}                            @https://dl.antmicro.com/projects/renode

${ZEPHYR_HELLO_WORLD_ELF}         ${URI}/cortex_a53-zephyr-hello_world.elf-s_34096-272b1e50f90c8240d875daf679223f2d769e77dd
${ZEPHYR_SYNCHRONIZATION_ELF}     ${URI}/virt-a53--zephyr-synchronization.elf-s_582816-bb556dc10df7f09918db3c5d1f298cdd3f3290f3
${ZEPHYR_PHILOSOPHERS_ELF}        ${URI}/zephyr_philosophers_a53.elf-s_731440-e6e5bd1c2151b7e5d38d272b01108493e8ef88b4

*** Keywords ***
Create Machine
    Execute Command               using sysbus
    Execute Command               mach create
    Execute Command               machine LoadPlatformDescription @platforms/cpus/cortex-a53.repl

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
