*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${LOCAL_FILENAME}                   uartlite
${UART}                             sysbus.uart
${UARTLITE_SCRIPT}                  scripts/single-node/riscv_verilated_uartlite.resc
${LOG_TIMEOUT}                      1  # virtual seconds

*** Test Cases ***
Should Run UARTLite Binary
    [Tags]                          skip_osx
    Execute Command                 $uartLinux = ${URI}/Vuartlite-Linux-x86_64-813952320-s_1588208-03aa9ad82b2d5b3f7b55a78bd88fc38b028f68c5
    Execute Command                 $uartWindows = ${URI}/Vuartlite-Windows-x86_64-813952320.exe-s_3190226-d5621499892e547603a78a2debc7f392e3fc8ccb
    Execute Script                  ${UARTLITE_SCRIPT}
    Start Emulation
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           I'm alive! counter = 10

# Sleep after 1000 iterations in "simulate" loop (renode.cpp)
Should Handle Connection Timeout
    [Tags]                          skip_osx

    Execute Command                 $uartLinux = ${URI}/Vsleep-after-1000-iters-Linux-x86_64-813952320-s_1588248-2898f398242dfe43d8ad215ca61fccc25d70f465
    Execute Command                 $uartWindows = ${URI}/Vsleep-after-1000-iters-Windows-x86_64-813952320.exe-s_3191754-184419c4133fc8ffe6f88fe548284a91bc6d4fcf
    Execute Script                  ${UARTLITE_SCRIPT}
    Create Terminal Tester          ${UART}
    Create Log Tester               ${LOG_TIMEOUT}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 9
    Wait For Log Entry              Receive error!

# Both ports wrong when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Not Connecting
    [Tags]                          skip_osx

    Execute Command                 $uartLinux = ${URI}/Vwrong-ports-Linux-x86_64-813952320-s_1588208-bd9e027db686fc0aac56807ab3802d31c24bf644
    Execute Command                 $uartWindows = ${URI}/Vwrong-ports-Windows-x86_64-813952320.exe-s_3190226-ae586de412a9ea66134e8909ae777a5712670dfa
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the verilated peripheral (*) failed!*    Execute Script  ${UARTLITE_SCRIPT}

# Wrong "second" port when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Partly Connecting
    [Tags]                          skip_osx

    Execute Command                 $uartLinux = ${URI}/Vwrong-second-port-Linux-x86_64-813952320-s_1588208-fe328bc3c97f00ac28762b85f94c3ad37832bf5e
    Execute Command                 $uartWindows = ${URI}/Vwrong-second-port-Windows-x86_64-813952320.exe-s_3190226-91b879f230b52764df49b285b0315a6868c0fd99
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the verilated peripheral (*) failed!*    Execute Script  ${UARTLITE_SCRIPT}

# Starting emulation without SimulationFilePath(Linux|MacOS|Windows) set
Should Handle Empty UARTLite Binary
    [Tags]                          skip_osx

    Create Log Tester               ${LOG_TIMEOUT}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/verilated/riscv_verilated_uartlite.repl
    Execute Command                 showAnalyzer sysbus.uart
    Execute Command                 sysbus LoadELF ${URI}/uartlite--custom_uart_demo--zephyr.elf-s_184340-129eb92404f437a466cd8700f6743b1c5b0da912
    Execute Command                 sysbus.cpu PC `sysbus GetSymbolAddress "vinit"`
    Run Keyword And Expect Error    *Cannot start emulation. Set SimulationFilePath first!*    Start Emulation

# File Doesn't Exist
Should Handle Nonexistent UARTLite Binary
    [Tags]                          skip_osx

    Execute Command                 $uartLinux = @nonexistent-uart-binary
    Execute Command                 $uartWindows = @nonexistent-uart-binary
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Error starting verilated peripheral!*    Execute Script  ${UARTLITE_SCRIPT}
