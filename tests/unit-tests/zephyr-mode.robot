*** Variables ***
${UART}                       sysbus.uart0

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
