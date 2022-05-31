*** Settings ***
Library         String
Library         Process
Library         Collections
Library         OperatingSystem
Library         helper.py

*** Variables ***
${SERVER_REMOTE_DEBUG}       False
${SERVER_REMOTE_PORT}        12345
${SERVER_REMOTE_SUSPEND}     y
${SKIP_RUNNING_SERVER}       False
${CONFIGURATION}             Release
${PORT_NUMBER}               9999
${DIRECTORY}                 ${CURDIR}/../../../output/bin/${CONFIGURATION}
${BINARY_NAME}               Renode.exe
${HOTSPOT_ACTION}            None
${DISABLE_XWT}               False
${DEFAULT_UART_TIMEOUT}      8
${CREATE_SNAPSHOT_ON_FAIL}   True
${SAVE_LOG_ON_FAIL}          True
${HOLD_ON_ERROR}             False
${CREATE_EXECUTION_METRICS}  False

*** Keywords ***
Setup
    ${SYSTEM}=          Evaluate    platform.system()    modules=platform

    ${CONFIGURATION}=  Set Variable If  not ${SKIP_RUNNING_SERVER} and ${SERVER_REMOTE_DEBUG}
    ...    Debug
    ...    ${CONFIGURATION}

    # without --hide-log the output buffers may get full and the program can hang
    # http://robotframework.org/robotframework/latest/libraries/Process.html#Standard%20output%20and%20error%20streams
    @{PARAMS}=           Create List  --robot-server-port  ${PORT_NUMBER}  --hide-log

    Run Keyword If        ${DISABLE_XWT}
    ...    Insert Into List  ${PARAMS}  0  --disable-xwt

    Run Keyword If       not ${SKIP_RUNNING_SERVER}
    ...   File Should Exist    ${DIRECTORY}/${BINARY_NAME}  msg=Robot Framework remote server binary not found (${DIRECTORY}/${BINARY_NAME}). Did you forget to build it in ${CONFIGURATION} configuration?

    # this handles starting on Linux/macOS using mono launcher
    Run Keyword If       not ${SKIP_RUNNING_SERVER} and not ${SERVER_REMOTE_DEBUG} and not '${SYSTEM}' == 'Windows'
    ...   Start Process  mono  ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}

    # this handles starting on Windows without an explicit launcher
    # we use 'shell=true' to execute process from current working directory
    Run Keyword If       not ${SKIP_RUNNING_SERVER} and not ${SERVER_REMOTE_DEBUG} and '${SYSTEM}' == 'Windows'
    ...   Start Process  ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}  shell=true

    Run Keyword If       not ${SKIP_RUNNING_SERVER} and ${SERVER_REMOTE_DEBUG} and not '${SYSTEM}' == 'Windows'
    ...   Start Process  mono
          ...            --debug
          ...            --debugger-agent\=transport\=dt_socket,address\=0.0.0.0:${SERVER_REMOTE_PORT},server\=y,suspend\=${SERVER_REMOTE_SUSPEND}
          ...            ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}

    Run Keyword If       not ${SKIP_RUNNING_SERVER} and ${SERVER_REMOTE_DEBUG} and '${SYSTEM}' == 'Windows'
    ...    Fatal Error  Windows doesn't support server remote debug option.

    #The distinction between operating systems is because localhost is not universally understood on Linux and 127.0.0.1 is not always available on Windows.
    Run Keyword If       not '${SYSTEM}' == 'Windows'
    ...   Wait Until Keyword Succeeds  60s  1s
          ...   Import Library  Remote  http://127.0.0.1:${PORT_NUMBER}/
    Run Keyword If       '${SYSTEM}' == 'Windows'
    ...   Wait Until Keyword Succeeds  60s  1s
          ...   Import Library  Remote  http://localhost:${PORT_NUMBER}/

    Set Default Uart Timeout  ${DEFAULT_UART_TIMEOUT}

    Run Keyword If  ${SAVE_LOG_ON_FAIL}
    ...   Enable Logging To Cache

    ${allowed_chars}=   Set Variable                 abcdefghijklmnopqrstuvwxyz01234567890_-
    ${metrics_fname}=   Convert To Lower Case        ${SUITE_NAME}
    ${metrics_fname}=   Replace String               ${metrics_fname}      ${SPACE}              _
    ${metrics_fname}=   Replace String Using Regexp  ${metrics_fname}      [^${allowed_chars}]+  ${EMPTY}
    ${metrics_path}=    Join Path                    ${RESULTS_DIRECTORY}  profiler-${metrics_fname}

    Run Keyword If      ${CREATE_EXECUTION_METRICS}
    ...   Execute Command    EnableProfilerGlobally "${metrics_path}"

    Reset Emulation

Teardown
    Run Keyword Unless  ${SKIP_RUNNING_SERVER}
    ...   Stop Remote Server

    Run Keyword Unless  ${SKIP_RUNNING_SERVER}
    ...   Wait For Process

Create Snapshot Of Failed Test
    Return From Keyword If   'skipped' in @{TEST TAGS}

    ${test_name}=      Set Variable  ${SUITE NAME}.${TEST NAME}.fail.save
    ${test_name}=      Replace String  ${test_name}  ${SPACE}  _

    ${snapshots_dir}=  Set Variable  ${RESULTS_DIRECTORY}/snapshots
    Create Directory   ${snapshots_dir}

    ${snapshot_path}=  Set Variable  "${snapshots_dir}/${test_name}"
    Execute Command  Save ${snapshot_path}
    Log To Console   !!!!! Emulation's state saved to ${snapshot_path}

Save Log Of Failed Test
    Return From Keyword If   'skipped' in @{TEST TAGS}

    ${test_name}=      Set Variable  ${SUITE NAME}.${TEST NAME}
    ${test_name}=      Replace String  ${test_name}  ${SPACE}  _

    ${logs_dir}=       Set Variable  ${RESULTS_DIRECTORY}/logs
    Create Directory   ${logs_dir}

    ${log_path}=       Set Variable  ${logs_dir}/${test_name}.log
    Log To Console     !!!!! Log saved to "${log_path}"
    Save Cached Log    ${log_path}

Test Teardown
    Run Keyword If  ${CREATE_SNAPSHOT_ON_FAIL}
    ...   Run Keyword If Test Failed
          ...   Create Snapshot Of Failed Test

    Run Keyword If  ${SAVE_LOG_ON_FAIL}
    ...   Run Keyword If Test Failed
          ...   Save Log Of Failed Test

    ${res}=  Run Keyword And Ignore Error
          ...    Import Library  Dialogs

    Run Keyword If      ${HOLD_ON_ERROR}
    ...   Run Keyword If Test Failed  Run Keywords
        ...         Run Keyword If    '${res[0]}' == 'FAIL'    Log                Couldn't load the Dialogs library - interactive debugging is not possible    console=True
        ...    AND  Run Keyword If    '${res[0]}' != 'FAIL'    Open GUI
        ...    AND  Run Keyword If    '${res[0]}' != 'FAIL'    Pause Execution    Test failed. Press OK once done debugging.
        ...    AND  Run Keyword If    '${res[0]}' != 'FAIL'    Close GUI
    Reset Emulation
    Clear Cached Log

Hot Spot
    Handle Hot Spot  ${HOTSPOT_ACTION}
