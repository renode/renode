*** Variables ***
${MMU_LOG_PREFIX}=                  cpu: Using incorrect MMU mode for translation of address${SPACE}
${MMU_LOG_SUFFIX}=                  , current MMU mode is 1, mapping is for MMU mode 0


*** Keywords ***
Create Machine
    [Arguments]                     ${binary}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/boards/stm32f4_discovery-kit.repl
    Execute Command                 sysbus LoadELF @${binary}
    Create Terminal Tester          sysbus.usart2  defaultPauseEmulation=true

Run Test
    [Arguments]                     ${binary}
    Create Machine                  ${binary}
    Start Emulation
    Wait for Line On Uart           PROJECT EXECUTION SUCCESSFUL

Wait For MMU Warning
    [Arguments]                     ${address}
    Wait For Log Entry              ${MMU_LOG_PREFIX}${address}${MMU_LOG_SUFFIX}  treatAsRegex=true

MMU Warning Should Not Appear
    [Arguments]                     ${address}
    Should Not Be In Log            ${MMU_LOG_PREFIX}${address}${MMU_LOG_SUFFIX}  treatAsRegex=true

*** Test Cases ***
Should Pass Zephyr mem_protect Test
    Run Test                        https://dl.antmicro.com/projects/renode/stm32f4_disco--zephyr-mem_protect.elf-s_1418612-2dce5412be6959ebb19a6ca9c1e61c700fc6517d

Should Pass Zephyr protection Test
    Run Test                        https://dl.antmicro.com/projects/renode/stm32f4_disco--zephyr-protection.elf-s_555424-ba244b9f0b1ee5bf2efcfc1b619b480d76553e9c

Should Pass Zephyr stackprot Test
    Run Test                        https://dl.antmicro.com/projects/renode/stm32f4_disco--zephyr-stackprot.elf-s_1301048-1b874b2d7d744113b06f48ef50bd857c3a3bb767

Should Pass Zephyr userspace Test
    Run Test                        https://dl.antmicro.com/projects/renode/stm32f4_disco--zephyr-userspace.elf-s_1287304-684a0dad9e1b5ca94fe5cf224a13067113dbdfa3

Should Warn When Translating Address From Incorrect MMU Mode
    Create Machine                  https://dl.antmicro.com/projects/renode/stm32f4disco-busyloop.elf-s_881696-d1250d7865417a6180e639aaca696042ca3212cb
    Wait For Line On Uart           Hello
    # Make sure we are in the user mode busyloop
    Execute Command                 emulation RunFor "0.1"

    # Set USERSETMPEND, this makes a simple sub-page mapping at 0xE00EF00 for 4 bytes
    ${CCR_VALUE}=  Execute Command  nvic ReadDoubleWord 0xD14
    ${CCR_VALUE}=  Evaluate         (${CCR_VALUE} | 0b10)
    Execute Command                 nvic WriteDoubleWord 0xD14 ${CCR_VALUE}

    Create Log Tester               1
    Execute Command                 cpu TranslateAddress 0xE000E000 Write
    Wait For MMU Warning            0xE000E000
    Execute Command                 cpu TranslateAddress 0xE000EF04 Write
    Wait For MMU Warning            0xE000EF04
    Execute Command                 cpu TranslateAddress 0xE000EF00 Write
    MMU Warning Should Not Appear   0xE000EF00
    # Make sure a valid translation in the same page doesn't cause other translations to succeed (ie. translation respects oneshot page policy)
    Execute Command                 cpu TranslateAddress 0xE000EF04 Write
    Wait For MMU Warning            0xE000EF04
