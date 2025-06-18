*** Variables ***
${UART}                             sysbus.uart0
${MPFS_ICYCLE_TICKLESS_KERNEL_ELF}  @https://dl.antmicro.com/projects/renode/zephyr-icicle-test_tickless_concept.elf-s_667256-3e789809fe48247fa36514fd7876468a76646c42

*** Keywords ***
Create Machine
    Execute Command          $elf=@https://dl.antmicro.com/projects/renode/zephyr-custom_k_busy_wait.elf-s_383952-e634ad4735a09c71058c885c75df67b8be827ce9
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/cpus/sifive-fu740.repl
    Execute Command          sysbus LoadELF $elf

*** Test Cases ***
Should Pass 10 Second Wait
    [Documentation]          Tests enabling Zephyr mode, this test should execute in about 10-15 seconds real-time.

    Create Machine
    Create Terminal Tester    ${UART}
    Execute Command          sysbus.s7 EnableZephyrMode
    Start Emulation
    Wait For Line On Uart    Waiting for 10 seconds...
    # k_busy_wait isn't accurate enough to reliably wait for exactly 10 seconds
    Wait For Line On Uart    Wait for 10 seconds completed  timeout=10.1

# This test depends on correct time flow counting in Zephyr. It will fail if EnableZephyrMode with `disableIfSymbolsPresent` logic does not work.
Should Pass Zephyr "tickless_kernel" test suite on mpfs_icicle_polarfire with ZephyrMode enabled and symbols excluded
    Execute Command          using sysbus
    Execute Command          include @platforms/boards/mpfs-icicle-kit.repl
    Execute Command          sysbus LoadELF ${MPFS_ICYCLE_TICKLESS_KERNEL_ELF}

    Create Terminal Tester   sysbus.mmuart0
    Create Log Tester         1
    Execute Command          e51 PerformanceInMips 80
    Execute Command          u54_1 IsHalted true
    Execute Command          u54_2 IsHalted true
    Execute Command          u54_3 IsHalted true
    Execute Command          u54_4 IsHalted true
    Execute Command          e51 EnableZephyrMode "CONFIG_TICKLESS_KERNEL"
    Wait For Log Entry       ZephyrMode is disabled because the symbol 'CONFIG_TICKLESS_KERNEL'
    Wait For Line On Uart    PROJECT EXECUTION SUCCESSFUL

