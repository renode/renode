*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${CURDIR}/../../../src/Renode/RobotFrameworkEngine/renode-keywords.robot

*** Variables ***
${URI}                              @http://antmicro.com/projects/renode
${LOCAL_FILENAME}                   uartlite
${UART}                             sysbus.uart
${UARTLITE_SCRIPT}                  scripts/single-node/riscv_verilated_uartlite.resc

*** Test Cases ***
Should Run UARTLite Binary
    Execute Command                 $uart = ${URI}/verilator--uartlite_trace_off-s_252704-c703fe4dec057a9cbc391a0a750fe9f5777d8a74
    Execute Script                  ${UARTLITE_SCRIPT}
    Start Emulation
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           I'm alive! counter = 10

Should Detect Connection Error
    Execute Command                 $uart = ${URI}/verilator--verilated_connection_error_test-s_16352-11da4b9bcea8e859aeb4790d041edf973aadd735
    Create Log Tester
    Execute Script                  ${UARTLITE_SCRIPT}
    Start Emulation
    Wait For Log Entry              Connection error!

Should Detect Connection Timeout
    Execute Command                 $uart = ${URI}/verilator--verilated_connection_timeout-s_252704-2deb632c75dc1066ea423347c26b10151f92d88c
    Create Log Tester
    Execute Script                  ${UARTLITE_SCRIPT}
    Start Emulation
    Wait For Log Entry              Connection timeout!
