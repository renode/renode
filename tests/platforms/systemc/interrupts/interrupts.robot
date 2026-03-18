*** Variables ***
${ZEPHYR_BINARY}                    @https://dl.antmicro.com/projects/renode/systemc-examples-zephyr-interrupts-stm32f401_mini.elf-s_573712-209c153accbf90335274ee5ae16eb9abb74d7808
${SYSTEMC_BINARY}                   @https://dl.antmicro.com/projects/renode/x64-systemc--interrupts.elf-s_1183328-9c7ec16d6e9b2f738e6e8e53f3534401407f886f
${PLATFORM}                         @tests/platforms/systemc/interrupts/interrupts.repl
${UART}                             sysbus.usart1

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 sysbus LoadELF ${ZEPHYR_BINARY}
    Execute Command                 sysbus.systemc SystemCExecutablePath ${SYSTEMC_BINARY}

*** Test Cases ***
Should Invoke Interrupt Handlers Initiated By SystemC
    [Tags]                          skip_windows    skip_osx    skip_host_aarch64
    Create Machine
    Create Terminal Tester          ${UART}
    Start Emulation

    Wait For Line On Uart           Interrupt handler for interrupter 0 (every 1 second)
    Wait For Line On Uart           Interrupt handler for interrupter 1 (every 3 seconds)
