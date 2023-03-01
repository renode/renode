*** Keywords ***
Create Machine
    [Arguments]                     ${binary}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/boards/stm32f4_discovery-kit.repl
    Execute Command                 sysbus LoadELF @${binary}
    Create Terminal Tester          sysbus.usart2

Run Test
    [Arguments]                     ${binary}
    Create Machine                  ${binary}
    Start Emulation
    Wait for Line On Uart           PROJECT EXECUTION SUCCESSFUL

*** Test Cases ***
Should Pass Zephyr mem_protect Test
    Run Test                        https://dl.antmicro.com/projects/renode/stm32f4_disco--zephyr-mem_protect.elf-s_1418612-2dce5412be6959ebb19a6ca9c1e61c700fc6517d

Should Pass Zephyr protection Test
    Run Test                        https://dl.antmicro.com/projects/renode/stm32f4_disco--zephyr-protection.elf-s_555424-ba244b9f0b1ee5bf2efcfc1b619b480d76553e9c

Should Pass Zephyr stackprot Test
    Run Test                        https://dl.antmicro.com/projects/renode/stm32f4_disco--zephyr-stackprot.elf-s_1301048-1b874b2d7d744113b06f48ef50bd857c3a3bb767

Should Pass Zephyr userspace Test
    Run Test                        https://dl.antmicro.com/projects/renode/stm32f4_disco--zephyr-userspace.elf-s_1287304-684a0dad9e1b5ca94fe5cf224a13067113dbdfa3
