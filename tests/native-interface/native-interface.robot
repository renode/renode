# Note that this test is different from most others: it does not use the Renode instance started by
# robot_tests_provider at all, instead it builds a native host process that hosts a separate Renode
# instance, in order to test the NativeInterface itself. This means that most of the flags you pass
# to renode-test (`--show-log` etc) will have no effect as they will only apply to an unused Renode
# instance, not the one started here.
#
# See native-interface.resource for the variables that select which librenode is used.

*** Settings ***
Suite Setup                         Setup And Start NativeInterface
Suite Teardown                      Stop NativeInterface And Teardown
Library                             ${CURDIR}/ni_library.py  AS  NI
Resource                            ${CURDIR}/native-interface.resource

*** Variables ***
${RENODE_DIR}                       ${CURDIR}/../..
${NI_ROBOT_PORT}                    3343
${NI_PROCESS}                       ${None}

*** Keywords ***
Setup And Start NativeInterface
    Setup

    ${user_renode_dir}=             Get User Renode Dir
    IF  $user_renode_dir != ''
        ${RENODE_DIR}=                  Set Variable  ${user_renode_dir}
    END

    ${EXAMPLE_SRC}=                 Set Variable  ${RENODE_DIR}/tools/NativeInterface/example
    ${BUILD_DIR}=                   Set Variable  ${RESULTS_DIRECTORY}/native-interface-example-build
    ${BINARY}=                      Set Variable  ${BUILD_DIR}/librenode_example

    Build NativeInterface Project   ${EXAMPLE_SRC}  ${BUILD_DIR}

    # stdin=PIPE: fgets in main.c blocks; EOF would trigger quit and kill the process
    ${process}=                     Start Process  ${BINARY}
    ...                             -R  ${NI_ROBOT_PORT}
    ...                             stdin=PIPE
    Set Suite Variable              ${NI_PROCESS}  ${process}

    TRY
        Wait Until Keyword Succeeds    30s  2s  NI.Connect  ${NI_ROBOT_PORT}
    EXCEPT    Keyword * failed after retrying *    type=GLOB
        # The process probably failed to start but we need to communicate with it anyway to have results.
        Terminate Process           ${NI_PROCESS}  kill=true
        ${rc}=                      Get Process Result  ${NI_PROCESS}  rc=true
        ${stdout}=                  Get Process Result  ${NI_PROCESS}  stdout=true
        ${stderr}=                  Get Process Result  ${NI_PROCESS}  stderr=true
        Set Suite Variable          ${NI_PROCESS}  ${None}
        Fail                        Process failed to start with code: ${rc}; stdout: '${stdout}'; stderr: '${stderr}'
    END

Stop NativeInterface And Teardown
    IF  $NI_PROCESS != $None
        Terminate Process               ${NI_PROCESS}  kill=true
    END

    Teardown

*** Test Cases ***
NativeInterface Can Run VexRiscv
    [Tags]                          basic-tests
    [Timeout]                       1 minute
    NI.Execute Command              include @scripts/single-node/murax.resc
    NI.Create Terminal Tester       sysbus.uart

    # Murax demo outputs 'A' on startup, then echoes input
    NI.Write Char On Uart           n
    NI.Write Char On Uart           t
    NI.Wait For Prompt On Uart      Ant
