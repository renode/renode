*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Keywords ***
Check Zephyr Version
    Wait For Prompt On Uart  $
    Write Line To Uart       version
    Wait For Line On Uart    Zephyr version 2.6.99

*** Test Cases ***
Should Handle Version Command In Zephyr Shell
    Execute Command          include @scripts/single-node/stm32l072.resc

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Check Zephyr Version

Should Handle Version Command In Zephyr Shell On Lpuart
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/bl072z_lrwan1--zephyr-shell_module_lpuart.elf-s_1197384-aea9caa07fddc35583bd09cb47563a11a2f90935

    Create Terminal Tester   sysbus.lpuart1

    Start Emulation

    Check Zephyr Version

Should Handle DMA Memory To Memory Transfer
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-chan_blen_transfer.elf-s_669628-623c4f2b14cad8e52db12d8b1b46effd1a89b644

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    PASS - [dma_m2m.test_dma_m2m_chan0_burst16]
    Wait For Line On Uart    PASS - [dma_m2m.test_dma_m2m_chan0_burst8]
    Wait For Line On Uart    PASS - [dma_m2m.test_dma_m2m_chan1_burst16]
    Wait For Line On Uart    PASS - [dma_m2m.test_dma_m2m_chan1_burst8]


Should Handle DMA Memory To Memory Loop Transfer
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-loop_transfer.elf-s_692948-f182b72146a77daeb4b73ece0aff2498aeaa5876

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    PASS - [dma_m2m_loop.test_dma_m2m_loop]
    Wait For Line On Uart    PASS - [dma_m2m_loop.test_dma_m2m_loop_suspend_resume]
