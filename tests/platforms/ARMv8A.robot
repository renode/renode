*** Variables ***
${UART}                           sysbus.uart0
${URI}                            @https://dl.antmicro.com/projects/renode

${ZEPHYR_HELLO_WORLD_ELF}         ${URI}/cortex_a53-zephyr-hello_world.elf-s_34096-272b1e50f90c8240d875daf679223f2d769e77dd
${ZEPHYR_SYNCHRONIZATION_ELF}     ${URI}/virt-a53--zephyr-synchronization.elf-s_582816-bb556dc10df7f09918db3c5d1f298cdd3f3290f3

*** Keywords ***
Create Machine
    Execute Command               using sysbus
    Execute Command               mach create
    Execute Command               machine LoadPlatformDescription @platforms/cpus/cortex-a53.repl

    Create Terminal Tester        ${UART}

*** Test Cases ***
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
