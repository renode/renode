*** Settings ***
Library         Process
Suite Setup     No Operation    # No need to run Renode, so override the default setup
Suite Teardown  No Operation
Test Setup      No Operation
Test Teardown   No Operation


*** Variables ***
${RENODE_TEST}          ${CURDIR}/../../renode-test
${SUBPROCESS_TIMEOUT}   60s


*** Keywords ***
Create Temp Directory
    ${name} =   Generate Random String

    Create Directory    ${TEMPDIR}/${name}

    RETURN  ${TEMPDIR}/${name}

Run Renode Test
    [Arguments]     ${file}    ${verbose}=False

    ${SYSTEM} =     Evaluate    platform.system()   modules=platform

    ${outputDir} =  Create Temp Directory

    ${RenodeTestOptions} =    Create List

    # Subprocess test results are not used but let's keep them separated form this test suite
    # results.
    Append To List  ${RenodeTestOptions}  --results-dir=${outputDir}

    IF  "${CONFIGURATION}" == "Debug"
        Append To List      ${RenodeTestOptions}  --debug
    END

    IF  ${verbose}
        Append To List      ${RenodeTestOptions}  --verbose
    END

    Append To List  ${RenodeTestOptions}  ${file}

    IF  '${SYSTEM}' == 'Windows'
        ${process} =    Set Variable    ${RENODE_TEST}.bat
    ELSE
        ${process} =    Set Variable    ${RENODE_TEST}
    END

    # Redirect stdout and stderr to files to avoid problems described in Robot documentation
    # (https://robotframework.org/robotframework/latest/libraries/Process.html#standard-output-and-error-streams)
    # that makes this calls to hang forever.
    ${result} =     Run Process     ${process}      @{RenodeTestOptions}
    ...             timeout=${SUBPROCESS_TIMEOUT}    on_timeout=kill
    ...             stdout=${outputDir}/stdout.txt    stderr=${outputDir}/stderr.txt

    RETURN      ${result}


*** Test Cases ***
Renode Test Should Display Error And Warning Messages
    ${result} =     Run Renode Test     ${CURDIR}/renode-test_logs.robot.rst

    Should Match Regexp     ${result.stdout}    ERROR: Error in file .* No module named 'Not Found Library'
    Should Contain          ${result.stdout}    WARN: This is a warning
    Should Contain          ${result.stdout}    ERROR: This is an error
    Should Contain          ${result.stdout}    WARN: Keyword 'Deprecated Keyword' is deprecated.

Verbose Renode Test Should Display All Messages
    ${result} =     Run Renode Test     ${CURDIR}/renode-test_logs.robot.rst    verbose=True

    Should Match Regexp     ${result.stdout}    ERROR: Error in file .* No module named 'Not Found Library'
    Should Contain          ${result.stdout}    TRACE: This is a trace
    Should Contain          ${result.stdout}    DEBUG: This is a debug
    Should Contain          ${result.stdout}    INFO: This is an info
    Should Contain          ${result.stdout}    WARN: This is a warning
    Should Contain          ${result.stdout}    ERROR: This is an error
    Should Contain          ${result.stdout}    WARN: Keyword 'Deprecated Keyword' is deprecated.
