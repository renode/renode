*** Variables ***
${PLATFORM_MIV}                         platforms/cpus/miv.repl
${PLATFORM_MIV_EXECUTABLE_ARRAY_MEM}    ./miv_array_mem.repl
${PLATFORM_MIXED_OVERLAPPING}           ./miv_mixed_overlapping_mem.repl
*** Keywords ***

Create Machine From Repl
    [Arguments]            ${repl_path}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${repl_path}

    Execute Command                 sysbus LoadELF @https://dl.antmicro.com/projects/renode/shell-demo-miv.elf-s_803248-ea4ddb074325b2cc1aae56800d099c7cf56e592a false true cpu
    Create Terminal Tester          sysbus.uart  timeout=1


Zephyr Console Should Work
    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              help

    Wait For Line On Uart           Please press the <Tab> button to see all available commands.
    Wait For Line On Uart           ou can also use the <Tab> button to prompt or auto-complete all commands or its subcommands.
    Wait For Line On Uart           You can try to call commands with <-h> or <--help> parameter for more information.

*** Test Cases ***
Should Still Run Zephyr From Mapped Memory
    Create Machine From Repl        ${PLATFORM_MIV}
    Zephyr Console Should Work

Should Run Zephyr From Array Memory
    Create Machine From Repl        ${PLATFORM_MIV_EXECUTABLE_ARRAY_MEM}
    Zephyr Console Should Work

Should Execute From Mixed Memory Page
    Create Machine From Repl        ${PLATFORM_MIXED_OVERLAPPING}
    Execute Command                 ddr ZeroRange 0x0 0x100
    Zephyr Console Should Work
