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
${LOG_TIMEOUT}                      15000

*** Test Cases ***
Should Run UARTLite Binary
    [Tags]                          skip_osx  skip_windows

    Execute Command                 $uart = ${URI}/uartlite_vtop-s_244552-c0691e81e8435bf89a2cc13d3634f4bcbbe91571
    Execute Script                  ${UARTLITE_SCRIPT}
    Start Emulation
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           I'm alive! counter = 10

Should Detect Connection Error
    [Tags]                          skipped

    Execute Command                 $uart = ${URI}/verilator--verilated_connection_error_test-s_16352-11da4b9bcea8e859aeb4790d041edf973aadd735
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Script                  ${UARTLITE_SCRIPT}
    Start Emulation
    Wait For Log Entry              Connection error!

Should Detect Connection Timeout
    [Tags]                          skipped

    Execute Command                 $uart = ${URI}/verilator--verilated_connection_timeout-s_252704-2deb632c75dc1066ea423347c26b10151f92d88c
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Script                  ${UARTLITE_SCRIPT}
    Start Emulation
    Wait For Log Entry              Receive timeout!
