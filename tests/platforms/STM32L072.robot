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

Independent Watchdog Should Trigger Reset
    # We can't use stm32l072.resc in this test because it defines a reset macro
    # that loads a Zephyr ELF which gets triggered by the watchdog reset. This
    # would obviously make the test fail because it would suddenly start running
    # a different Zephyr application, but even if it reloaded the same ELF the
    # test would still fail because `m_state` would be reset. We manually define
    # a reset macro that only resets PC and SP to their initial values.
    Execute Command          mach create
    Execute Command          using sysbus
    Execute Command          machine LoadPlatformDescription @platforms/cpus/stm32l072.repl
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/zephyr-drivers_watchdog_wdt_basic_api-test.elf-s_463344-248e7e6eb8a681a33c4bf8fdb45c6bf95bcb57fd

    ${pc}=  Execute Command      sysbus GetSymbolAddress "z_arm_reset"
    ${sp}=  Execute Command      sysbus GetSymbolAddress "z_idle_stacks"

    Execute Command          macro reset "cpu0 PC ${pc}; cpu0 SP ${sp}"

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    PROJECT EXECUTION SUCCESSFUL
