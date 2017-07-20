*** Settings ***
Library         String
Library         Process
Library         Collections
Library         OperatingSystem
Library         helper.py

*** Variables ***
${SERVER_REMOTE_DEBUG}    False
${SERVER_REMOTE_PORT}     12345
${SERVER_REMOTE_SUSPEND}  y
${SKIP_RUNNING_SERVER}    False
${CONFIGURATION}          Release
${PORT_NUMBER}            9999
${DIRECTORY}              ${CURDIR}/../../../output/bin/${CONFIGURATION}
${BINARY_NAME}            ./Renode.exe
${HOTSPOT_ACTION}         None
${DISABLE_XWT}            False

*** Keywords ***
Setup
    ${CONFIGURATION}=  Set Variable If  not ${SKIP_RUNNING_SERVER} and ${SERVER_REMOTE_DEBUG}
    ...    Debug
    ...    ${CONFIGURATION}

    @{PARAMS}=           Create List  --robot-server-port  ${PORT_NUMBER}
    Run Keyword If        ${DISABLE_XWT}
    ...    Insert Into List  ${PARAMS}  0  --disable-xwt

    Run Keyword If       not ${SKIP_RUNNING_SERVER}
    ...   File Should Exist    ${DIRECTORY}/${BINARY_NAME}  msg=Robot Framework remote server binary not found (${DIRECTORY}/${BINARY_NAME}). Did you forget to build it in ${CONFIGURATION} configuration?

    Run Keyword If       not ${SKIP_RUNNING_SERVER} and not ${SERVER_REMOTE_DEBUG}
    ...   Start Process  mono  ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}

    Run Keyword If       not ${SKIP_RUNNING_SERVER} and ${SERVER_REMOTE_DEBUG}
    ...   Start Process  mono
          ...            --debug
          ...            --debugger-agent\=transport\=dt_socket,address\=0.0.0.0:${SERVER_REMOTE_PORT},server\=y,suspend\=${SERVER_REMOTE_SUSPEND}
          ...            ${BINARY_NAME}  @{PARAMS}  cwd=${DIRECTORY}

    Wait Until Keyword Succeeds  60s  1s
    ...   Import Library  Remote  http://localhost:${PORT_NUMBER}/

    Reset Emulation

Teardown
    Run Keyword Unless  ${SKIP_RUNNING_SERVER}
    ...   Stop Remote Server

    Run Keyword Unless  ${SKIP_RUNNING_SERVER}
    ...   Wait For Process

Hot Spot
    Handle Hot Spot  ${HOTSPOT_ACTION}
