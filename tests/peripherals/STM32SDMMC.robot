*** Variables ***
${UART}                       sysbus.usart1
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/stm32f7_discovery-bb.repl
    Execute Command          machine SdCardFromFile ${URI}/test-fs-ext2.img-s_524288-67f5bc210d7be8905b4de4ae5d70a8a142459110 sysbus.sdmmc 153600000 False "SDMMC"
    Execute Command          sysbus LoadELF ${URI}/zephyr-stm32f746g-fs_sample_ext.elf-s_1001008-cee4776b4dcca6ee5bb892b04426134b038c6d00

*** Test Cases ***
Should Mount And List Files
    Create Machine
    Create Terminal Tester    ${UART}
    
    Wait For Line On Uart    Disk mounted.
    Wait For Line On Uart    [DIR ] lost+found
