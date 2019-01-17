*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${CURDIR}/../../../../src/Renode/RobotFrameworkEngine/renode-keywords.robot        

*** Variables ***
${URI}                              http://antmicro.com/projects/renode
${HOSTED_FILENAME}                  verilator--uartlite-trace_off.elf-s_241952-7b6b5f214fefb1631511de5065c87be9a7657c43
${LOCAL_FILENAME}                   uartlite
${UART}                             sysbus.uart

*** Keywords ***
Download File
    [Arguments]  ${URL}  ${FILENAME}
    Run and Return RC               wget -O ${FILENAME} ${URL}
    Run and Return RC               chmod u+x ${FILENAME}

Remove File
    [Arguments]  ${FILENAME}
    Run and Return RC               rm ${FILENAME}

*** Test Cases ***
Should Run UARTLite Binary
    Download File                   ${URI}/${HOSTED_FILENAME}  ${LOCAL_FILENAME}
    Execute Script                  tests/platforms/verilated/uartlite/uartlite.resc
    Start Emulation
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           I'm alive! counter = 1
    Remove File                     ${LOCAL_FILENAME}