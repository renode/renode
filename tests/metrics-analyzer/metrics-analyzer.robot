*** Settings ***
Library                       Process
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart0
${URI}                        https://dl.antmicro.com/projects/renode
${SCRIPT}                     scripts/single-node/hifive_unleashed.resc
${TEST_OUTPUT_DIR}            ${CURDIR}/../../output/tests       
${TEST_DUMP_FILE}             ${TEST_OUTPUT_DIR}/test_dump

*** Test Cases ***
Should Run Hifive Script With Enabled Profiler
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Execute Command           machine EnableProfiler "${TEST_DUMP_FILE}"
    Execute Command           emulation SetGlobalSerialExecution true
    Execute Command           emulation RunFor "1"
    Execute Command           Clear

Dump File Should Be Not Empty
    ${DUMP_FILE_SIZE} =       Get File Size  ${TEST_DUMP_FILE}
    Should Be True            ${DUMP_FILE_SIZE} > 0
