*** Variables ***
${SYSTEMC_BINARY}                   @https://dl.antmicro.com/projects/renode/x64-systemc--transaction-delay.elf-s_730520-71a2e317e0f42799b7679af5dba036e918a7146e
${ZEPHYR_BINARY}                    @https://dl.antmicro.com/projects/renode/systemc-examples-zephyr-transaction-delay-stm32f401_mini.elf-s_572316-f591f8f491f1f3480aa6f7284d2bdbef3bebb8d5
${UART}                             sysbus.usart1

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @tests/platforms/systemc/transaction-delay/transaction-delay.repl
    Execute Command                 sysbus LoadELF ${ZEPHYR_BINARY}
    Execute Command                 systemc SystemCExecutablePath ${SYSTEMC_BINARY}

Virtual Time Should Be Equal To
    [Arguments]                     ${time_string}
    ${res}=                         Execute Command  machine ElapsedVirtualTime
    Should Contain                  ${res}  Elapsed Virtual Time: ${time_string}

*** Test Cases ***
Should Respect SystemC Transaction Durations
    [Tags]                          skip_windows    skip_osx    skip_host_arm
    Create Machine
    Create Terminal Tester          ${UART}
    Start Emulation

    Wait For Line On Uart           SystemC virtual time (1s transaction delay): 1 s
    Virtual Time Should Be Equal To  00:00:02

    Wait For Line On Uart           SystemC virtual time (1s transaction delay): 2 s
    Virtual Time Should Be Equal To  00:00:03

    Wait For Line On Uart           SystemC virtual time (1s transaction delay): 6 s
    Virtual Time Should Be Equal To  00:00:07
