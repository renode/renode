*** Settings ***
Test Template  Check Mounting And File Listing

*** Variables ***
${UART}                       sysbus.usart1
${URI}                        @https://dl.antmicro.com/projects/renode
${SD_CARD}                    ${URI}/test-fs-ext2.img-s_524288-67f5bc210d7be8905b4de4ae5d70a8a142459110
${STM32F_ELF}                 ${URI}/zephyr-stm32f746g-fs_sample_ext.elf-s_1001008-cee4776b4dcca6ee5bb892b04426134b038c6d00
${STM32F_REPL}                @platforms/boards/stm32f7_discovery-bb.repl
${STM32H_REPL}                @platforms/cpus/stm32h743.repl
${STM32H_ELF}                 @https://dl.antmicro.com/projects/renode/zephyr-stm32h747i-fs_sample_ext.elf-s_1183824-6a3b96a821387ade23d9633a12dcfe67dae02686

*** Keywords ***
Create Machine
    [Arguments]  ${repl}  ${elf}
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription ${repl}
    Execute Command          machine SdCardFromFile ${SD_CARD} sysbus.sdmmc 153600000 False "SDMMC"
    Execute Command          sysbus LoadELF ${elf}

Check Mounting And File Listing
    [Arguments]  ${repl}  ${elf}
    Create Machine  ${repl}  ${elf}
    Create Terminal Tester    ${UART}
    
    Wait For Line On Uart    Disk mounted.
    Wait For Line On Uart    [DIR ] lost+found

*** Test Cases ***
Should Mount And List Files On STM32F
    ${STM32F_REPL}  ${STM32F_ELF}

Should Mount And List Files On STM32H
    ${STM32H_REPL}  ${STM32H_ELF}
