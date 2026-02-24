*** Variables ***
${ELF}                              @https://dl.antmicro.com/projects/renode/96b_avenger96--zephyr-hello_world.elf-s_572880-d977e423cde08219805a9221e80a97997379a782
${REPL}                             "${CURDIR}${/}zephyr-ram-console.repl"
${RAM_CONSOLE}                      sysbus.zephyr_ram_console

*** Keywords ***
Create Machine
    Execute Command                 $elf=${ELF}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${REPL}
    Execute Command                 sysbus LoadELF $elf

*** Test Cases ***
Should display hello world demo in ram console
    Create Machine
    Execute Command                 cpu0 CreateZephyrRamConsole
    Create Terminal Tester          ${RAM_CONSOLE}
    Wait For Line On Uart           Hello World!
