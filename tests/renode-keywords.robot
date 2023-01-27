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
${DIRECTORY}                 ${CURDIR}/../output/bin/${CONFIGURATION}
${BINARY_NAME}               Renode.exe
${HOTSPOT_ACTION}            None
${DISABLE_XWT}               False
${DEFAULT_UART_TIMEOUT}      8
${CREATE_SNAPSHOT_ON_FAIL}   True
${SAVE_LOG_ON_FAIL}          True
${HOLD_ON_ERROR}             False
${CREATE_EXECUTION_METRICS}  False
${NET_PLATFORM}              False
${PROFILER_PROCESS}          None

*** Keywords ***
Setup
    ${SYSTEM}=          Evaluate    platform.system()    modules=platform

    ${CONFIGURATION}=  Set Variable If  not ${SKIP_RUNNING_SERVER} and ${SERVER_REMOTE_DEBUG}
    ...    Debug
    ...    ${CONFIGURATION}

    # without --hide-log the output buffers may get full and the program can hang
    # http://robotframework.org/robotframework/latest/libraries/Process.html#Standard%20output%20and%20error%20streams
    @{PARAMS}=           Create List  --robot-server-port  ${PORT_NUMBER}  --hide-log

    IF  ${DISABLE_XWT}
        Insert Into List  ${PARAMS}  0  --disable-xwt
    END

    IF  not ${SKIP_RUNNING_SERVER}
        File Should Exist    ${DIRECTORY}/${BINARY_NAME}  msg=Robot Framework remote server binary not found (${DIRECTORY}/${BINARY_NAME}). Did you forget to build it in ${CONFIGURATION} configuration?
    END

    # this handles starting on Linux/macOS using mono launcher
    IF  not ${SKIP_RUNNING_SERVER} and not ${SERVER_REMOTE_DEBUG} and not '${SYSTEM}' == 'Windows' and not ${NET_PLATFORM}
        Start Process  mono  ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}
    END

    # this handles starting on Windows without an explicit launcher
    # we use 'shell=true' to execute process from current working directory
    IF  not ${SKIP_RUNNING_SERVER} and not ${SERVER_REMOTE_DEBUG} and '${SYSTEM}' == 'Windows'
        Start Process  ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}  shell=true
    END
    
    # this handles starting on all platforms with dotnet launcher
    # we use 'shell=true' to execute process from current working directory
    IF  not ${SKIP_RUNNING_SERVER} and not ${SERVER_REMOTE_DEBUG} and ${NET_PLATFORM}
        Start Process  dotnet ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}  shell=true
    END

    IF  not ${SKIP_RUNNING_SERVER} and ${SERVER_REMOTE_DEBUG} and not '${SYSTEM}' == 'Windows' and not ${NET_PLATFORM}
        Start Process  mono
          ...            --debug
          ...            --debugger-agent\=transport\=dt_socket,address\=0.0.0.0:${SERVER_REMOTE_PORT},server\=y,suspend\=${SERVER_REMOTE_SUSPEND}
          ...            ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}
    END

    IF  not ${SKIP_RUNNING_SERVER} and ${SERVER_REMOTE_DEBUG} and '${SYSTEM}' == 'Windows'
         Fatal Error  Windows doesn't support server remote debug option.
    END

    #The distinction between operating systems is because localhost is not universally understood on Linux and 127.0.0.1 is not always available on Windows.
    IF  not '${SYSTEM}' == 'Windows'
        Wait Until Keyword Succeeds  60s  1s
          ...   Import Library  Remote  http://127.0.0.1:${PORT_NUMBER}/
    END

    IF  '${SYSTEM}' == 'Windows'
        Wait Until Keyword Succeeds  60s  1s
          ...   Import Library  Remote  http://localhost:${PORT_NUMBER}/
    END

    Set Default Uart Timeout  ${DEFAULT_UART_TIMEOUT}

    IF  ${SAVE_LOG_ON_FAIL}
        Enable Logging To Cache
    END

    ${allowed_chars}=   Set Variable                 abcdefghijklmnopqrstuvwxyz01234567890_-
    ${metrics_fname}=   Convert To Lower Case        ${SUITE_NAME}
    ${metrics_fname}=   Replace String               ${metrics_fname}      ${SPACE}              _
    ${metrics_fname}=   Replace String Using Regexp  ${metrics_fname}      [^${allowed_chars}]+  ${EMPTY}
    ${metrics_path}=    Join Path                    ${RESULTS_DIRECTORY}  profiler-${metrics_fname}

    IF      ${CREATE_EXECUTION_METRICS}
        Execute Command    EnableProfilerGlobally "${metrics_path}"
    END

    Reset Emulation

Teardown
    IF  not ${SKIP_RUNNING_SERVER}
        Stop Remote Server
    END

    IF  not ${SKIP_RUNNING_SERVER}
        Wait For Process
    END

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

Test Setup
    IF  'profiling' in @{TEST TAGS}
        Start Profiler
    END

Test Teardown
    Stop Profiler

    IF  ${CREATE_SNAPSHOT_ON_FAIL}
        Run Keyword If Test Failed
          ...   Create Snapshot Of Failed Test
    END

    IF  ${SAVE_LOG_ON_FAIL}
        Run Keyword If Test Failed
          ...   Save Log Of Failed Test
    END

    ${res}=  Run Keyword And Ignore Error
          ...    Import Library  Dialogs

    IF  ${HOLD_ON_ERROR}
        Run Keyword If Test Failed  Run Keywords
        ...         Run Keyword If    '${res[0]}' == 'FAIL'    Log                Couldn't load the Dialogs library - interactive debugging is not possible    console=True
        ...    AND  Run Keyword If    '${res[0]}' != 'FAIL'    Open GUI
        ...    AND  Run Keyword If    '${res[0]}' != 'FAIL'    Pause Execution    Test failed. Press OK once done debugging.
        ...    AND  Run Keyword If    '${res[0]}' != 'FAIL'    Close GUI
    END

    Reset Emulation
    Clear Cached Log

Hot Spot
    Handle Hot Spot  ${HOTSPOT_ACTION}

Start Profiler Or Skip
    IF  not ${NET_PLATFORM}
        Fail                   Failed to run profiler. Available only for .NET platform.  skipped
    END

    Start Profiler

Start Profiler
    IF  not ${NET_PLATFORM}
        Fail                   Failed to run profiler. Available only for .NET platform.
    END

    ${test_name}=               Set Variable  ${SUITE NAME}.${TEST NAME}
    ${test_name}=               Replace String  ${test_name}  ${SPACE}  _

    ${traces_dir}=              Set Variable  ${RESULTS_DIRECTORY}/traces
    Create Directory            ${traces_dir}

    ${trace_path}=              Set Variable  ${traces_dir}/${test_name}
    Log To Console              !!!!! Writing nettrace to "${trace_path}.nettrace"
    Log To Console              !!!!! Writing speedscope trace to "${trace_path}.speedscope.json"
    # note that those logs may not be bundled with log and snapshot saving info

    ${proc}=                    Start Process  dotnet  trace  collect  -p  ${RENODE_PID}  --format  Speedscope  -o  ${trace_path}.nettrace
    Set Test Variable           ${PROFILER_PROCESS}  ${proc}

Stop Profiler
    IF  ${PROFILER_PROCESS}
        Terminate Process           ${PROFILER_PROCESS}
        Set Test Variable           ${PROFILER_PROCESS}  None
    END
