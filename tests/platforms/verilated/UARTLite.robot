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
    Execute Command                 $uartLinux = ${URI}/Vuartlite-linux-x86_64-33843-s_1521056-b5a082c7c788c6761802434529daf741c78091ac
    Execute Command                 $uartWindows = ${URI}/Vuartlite-windows-33757.exe-s_3190318-182aee388141925862dfa8636ad228656fc99ca5
    Execute Script                  ${UARTLITE_SCRIPT}
    Start Emulation
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           I'm alive! counter = 10

# Sleep after 1000 iterations in "simulate" loop (renode.cpp)
Should Handle Connection Timeout
    [Tags]                          skip_osx

    Execute Command                 $uartLinux = ${URI}/Vsleep-after-1000-iters-linux-x86_64-33843-s_1521104-de0fc618f54204dac233f9ebcadbd663da212d30
    Execute Command                 $uartWindows = ${URI}/Vsleep-after-1000-iters-windows-33757.exe-s_3191846-9a828c3c90fc50d4c97ab7059ee2341c5c09a34e
    Execute Script                  ${UARTLITE_SCRIPT}
    Create Terminal Tester          ${UART}
    Create Log Tester               ${LOG_TIMEOUT}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 9
    Wait For Log Entry              Receive error!

# Both ports wrong when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Not Connecting
    [Tags]                          skip_osx

    Execute Command                 $uartLinux = ${URI}/Vwrong-ports-linux-x86_64-33843-s_1521056-f60e1b069eff601d3e93344d5d04ed1bc9d161a7
    Execute Command                 $uartWindows = ${URI}/Vwrong-ports-windows-33757.exe-s_3190318-cd2d3148a9243907b5350705db35dc19b1c46c22
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the verilated peripheral (*) failed!*    Execute Script  ${UARTLITE_SCRIPT}

# Wrong "second" port when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Partly Connecting
    [Tags]                          skip_osx

    Execute Command                 $uartLinux = ${URI}/Vwrong-second-port-linux-x86_64-33843-s_1521056-80641f5b7726636227ae531ae92f99004fb16d23
    Execute Command                 $uartWindows = ${URI}/Vwrong-second-port-windows-33757.exe-s_3190318-69ed9baa4919bd6d64e154db775b57f46baa5855
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
