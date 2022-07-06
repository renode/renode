*** Variables ***
${UART}                       sysbus.uart0
${URI}                        https://dl.antmicro.com/projects/renode
${SCRIPT}                     scripts/single-node/hifive_unleashed.resc

*** Test Cases ***
Should Run Hifive Script With Enabled Profiler
    Execute Script            ${SCRIPT}

    ${TEST_DUMP_FILE}=        Allocate Temporary File

    Create Terminal Tester    ${UART}
    Execute Command           machine EnableProfiler "${TEST_DUMP_FILE}"
    Execute Command           emulation SetGlobalSerialExecution true
    Execute Command           emulation RunFor "1"

    ${DUMP_FILE_SIZE} =       Get File Size  ${TEST_DUMP_FILE}
    Should Be True            ${DUMP_FILE_SIZE} > 0
