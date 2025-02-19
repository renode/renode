*** Variables ***
${SYSTEMC_BINARY}                   @https://dl.antmicro.com/projects/renode/x64-systemc--multiple-peripherals.elf-s_1045808-e4358ec1f6d94e52e0d946c5c6acb80e157523b5
${ZEPHYR_BINARY}                    @https://dl.antmicro.com/projects/renode/systemc-examples-zephyr-multiple-peripherals-stm32f401_mini.elf-s_574416-8bc080d4e6c922e7c89a233d1f74f6d9bcb45274
${PLATFORM}                         @tests/platforms/systemc/multiple-peripherals/multiple-peripherals.repl
${UART}                             sysbus.usart1

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 sysbus.systemc_peripheral_A SystemCExecutablePath ${SYSTEMC_BINARY}
    Execute Command                 sysbus.systemc_peripheral_B SystemCExecutablePath ${SYSTEMC_BINARY}
    Execute Command                 sysbus.systemc_peripheral_C SystemCExecutablePath ${SYSTEMC_BINARY}
    Execute Command                 sysbus LoadELF ${ZEPHYR_BINARY}

*** Test Cases ***
Should Run The Multiple Peripherals Example
    [Tags]                          skip_windows    skip_osx    skip_host_arm
    Create Machine
    Create Terminal Tester          ${UART}
    Start Emulation

    Wait For Line On Uart           Example complete!
