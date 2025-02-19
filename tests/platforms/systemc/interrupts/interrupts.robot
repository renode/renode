*** Variables ***
${ZEPHYR_BINARY}                    @https://dl.antmicro.com/projects/renode/systemc-examples-zephyr-interrupts-stm32f401_mini.elf-s_573712-209c153accbf90335274ee5ae16eb9abb74d7808
${SYSTEMC_BINARY}                   @https://dl.antmicro.com/projects/renode/x64-systemc--interrupts.elf-s_1017672-89c2d9745bc1fbc82c3ee727ae0d248415ed6d35
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
    [Tags]                          skip_windows    skip_osx    skip_host_arm
    Create Machine
    Create Terminal Tester          ${UART}
    Start Emulation

    Wait For Line On Uart           Interrupt handler for interrupter 0 (every 1 second)
    Wait For Line On Uart           Interrupt handler for interrupter 1 (every 3 seconds)
