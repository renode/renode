*** Variables ***
${UART}                           sysbus.uart0
${URI}                            @https://dl.antmicro.com/projects/renode

${ZEPHYR_HELLO_WORLD_ELF}         ${URI}/cortex_a53-zephyr-hello_world.elf-s_34096-272b1e50f90c8240d875daf679223f2d769e77dd

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
