*** Settings ***
Test Teardown                       Custom Test Teardown
Test Timeout                        1 minute  # Quickly timeout even when emulation isn't started
Library                             Process
Library                             OperatingSystem

*** Variables ***
${PORT}                             3345
${SERVER_NAME}                      server
${EXTERNALLY_CONTROLED_RESC}        scripts/complex/external_control/renode_externally_controlled.resc

*** Keywords ***
Custom Test Teardown
    Test Teardown

    Return From Keyword If          'skipped' in @{TEST TAGS}

    ${is_process_running}=          Is Process Running
    IF  ${is_process_running}
        ${result}=                      Terminate Process
        Fail                            Unfinished process during teardown
        Log                             Process rc: ${result.rc}
        Log                             Process stdout:${\n}${result.stdout}
        Log                             Process stderr:${\n}${result.stderr}
    END

 Create Machine And Connect Remote Renode
    [Arguments]                     ${remote_renode_resc}
    Create Log Tester               1

    Execute Command                 emulation CreateExternalControlServer "${SERVER_NAME}" ${PORT}
    Execute Command                 mach create "machine"
    Execute Command                 logLevel 0 ${SERVER_NAME}

    ${remote_renode}=               Start Renode  ${PORT}  ${remote_renode_resc}

    Wait For Log Entry              ${SERVER_NAME}: Connection accepted  startEmulation=false

    [Return]                        ${remote_renode}

Start Renode
    [Arguments]                     ${port}  ${resc}

    # Redirect outputs to files to avoid filling up buffers
    ${stdoutFile}=                  Allocate Temporary File
    ${stderrFile}=                  Allocate Temporary File

    @{args}=                        Split Command Line  ${COMMAND}
    Append To List                  ${args}  --console  -e  $client_port=${PORT}; i "${resc}"

    ${proc}=                        Start Process  @{args}  cwd=${DIRECTORY}  stdout=${stdoutFile}  stderr=${stderrFile}  stdin=PIPE
    [Return]                        ${proc}

Execute Command In Process
    [Arguments]                     ${proc}  ${command}

    Evaluate                        $proc.stdin.write("${command}\\n".encode("utf-8"))
    Evaluate                        $proc.stdin.flush()

Quit Renode
    [Arguments]                     ${proc}  ${timeout}=1 minute

    Execute Command In Process      ${proc}  quit

    ${result}=                      Wait For Process  ${proc}
    Log                             Remote Renode stdout:${\n}${result.stdout}
    Log                             Remote Renode stderr:${\n}${result.stderr}
    Should Be Equal As Integers     ${result.rc}  0  msg=Process failed with exit code

    [Return]                        ${result.stdout}

*** Test Cases ***
Should Connect Two Renodes
    [Tags]                          basic-tests  skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC}

    Quit Renode                     ${remote}

Should Synchronize Time Between Two Renodes
    [Tags]                          skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC}

    Wait For Log Entry              ${SERVER_NAME}: Registered time elapsed callback  startEmulation=false

    Execute Command                 emulation RunFor "0.0002"
    Execute Command In Process      ${remote}  emulation GetTimeSourceInfo

    ${output}=                      Quit Renode  ${remote}
    Should Contain                  ${output}  Elapsed Virtual Time: 00:00:00.000200000
