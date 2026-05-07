# Note that this test is different from most others: it does not use the Renode instance started by
# robot_tests_provider at all, instead it builds a native host process that hosts a separate Renode
# instance, in order to test the NativeInterface itself. This means that most of the flags you pass
# to renode-test (`--show-log` etc) will have no effect as they will only apply to an unused Renode
# instance, not the one started here.
#
# Some influential variables:
#   USER_RENODE_DIR - path to an extracted Renode package (must contain bin/librenode.so).
#                     Optional when running from a Renode source tree built with ./build.sh --shared
#                     For packages: tar -C <dir> --strip-components=1 -xf renode-*.linux.tar.gz
#                     Then pass: renode-test --variable USER_RENODE_DIR:<dir> native-interface.robot

*** Settings ***
Suite Setup                         Setup And Start NativeInterface
Suite Teardown                      Stop NativeInterface And Teardown
Library                             ${CURDIR}/ni_library.py  AS  NI

*** Variables ***
${RENODE_DIR}                       ${CURDIR}/../..
${USER_RENODE_DIR}                  ${EMPTY}
${RENODE_CFG}                       ${CONFIGURATION}
${NI_ROBOT_PORT}                    3343
${NI_PROCESS}                       ${None}

*** Keywords ***
Setup And Start NativeInterface
    Setup

    IF  $USER_RENODE_DIR == ''
        # Fall back to environment variable
        ${USER_RENODE_DIR}=             Set Variable  %{USER_RENODE_DIR=}
    END

    IF  $USER_RENODE_DIR != ''
        ${RENODE_DIR}=                  Set Variable  ${USER_RENODE_DIR}
    END

    ${EXAMPLE_SRC}=                 Set Variable  ${RENODE_DIR}/tools/NativeInterface/example
    ${BUILD_DIR}=                   Set Variable  ${EXAMPLE_SRC}/build
    ${BINARY}=                      Set Variable  ${BUILD_DIR}/librenode_example

    IF  $USER_RENODE_DIR != ''
        ${r}=                           Run Process  cmake
        ...                             -DUSER_RENODE_DIR\=${USER_RENODE_DIR}
        ...                             -DRENODE_CFG\=${RENODE_CFG}
        ...                             -B  ${BUILD_DIR}
        ...                             -S  ${EXAMPLE_SRC}
    ELSE
        ${r}=                           Run Process  cmake
        ...                             -DRENODE_CFG\=${RENODE_CFG}
        ...                             -B  ${BUILD_DIR}
        ...                             -S  ${EXAMPLE_SRC}
    END
    Should Be Equal As Integers     ${r.rc}  0  msg=cmake configure failed: ${r.stderr}

    ${r}=                           Run Process  cmake  --build  ${BUILD_DIR}
    Should Be Equal As Integers     ${r.rc}  0  msg=cmake build failed: ${r.stderr}

    # stdin=PIPE: fgets in main.c blocks; EOF would trigger quit and kill the process
    ${process}=                     Start Process  ${BINARY}
    ...                             -R  ${NI_ROBOT_PORT}
    ...                             stdin=PIPE
    Set Suite Variable              ${NI_PROCESS}  ${process}

    Wait Until Keyword Succeeds     30s  2s  NI.Connect  ${NI_ROBOT_PORT}

Stop NativeInterface And Teardown
    IF  $NI_PROCESS != $None
        Terminate Process               ${NI_PROCESS}  kill=true
    END

    Teardown

*** Test Cases ***
NativeInterface Can Run VexRiscv
    [Tags]                          skip_windows  skip_portable  basic-tests
    [Timeout]                       1 minute
    NI.Execute Command              include @scripts/single-node/murax.resc
    NI.Create Terminal Tester       sysbus.uart

    # Murax demo outputs 'A' on startup, then echoes input
    NI.Write Char On Uart           n
    NI.Write Char On Uart           t
    NI.Wait For Prompt On Uart      Ant
