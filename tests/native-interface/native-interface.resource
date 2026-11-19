# Some influential variables:
#   USER_RENODE_DIR - path to an extracted Renode package (must contain librenode.so in the bin/
#                     subdirectory for packages or in the package root for portable packages)
#                     Optional when running from a Renode source tree built with ./build.sh --shared
#                     For packages: tar -C <dir> --strip-components=1 -xf renode-*.linux.tar.gz
#                     Then pass: renode-test --variable USER_RENODE_DIR:<dir> <suite>.robot
#   CONFIGURATION   - Renode build configuration. Normally overridden by renode-test so you don't have
#                     to worry about it, but specified here to please the LSP.

*** Settings ***
Library                             OperatingSystem

*** Variables ***
${CONFIGURATION}                    Release
${USER_RENODE_DIR}                  ${EMPTY}
${RENODE_CFG}                       ${CONFIGURATION}
${EXAMPLE_DIR}                      ${CURDIR}/../../tools/NativeInterface/example

*** Keywords ***
Get User Renode Dir
    IF  $USER_RENODE_DIR != ''
        RETURN                          ${USER_RENODE_DIR}
    END
    # Fall back to environment variable
    RETURN                          %{USER_RENODE_DIR=}

Build NativeInterface Project
    [Arguments]                     ${source_dir}  ${build_dir}
    ${user_renode_dir}=             Get User Renode Dir

    IF  $user_renode_dir != ''
        ${r}=                           Run Process  cmake
        ...                             -DUSER_RENODE_DIR\=${user_renode_dir}
        ...                             -DRENODE_CFG\=${RENODE_CFG}
        ...                             -B  ${build_dir}
        ...                             -G  Unix Makefiles
        ...                             -S  ${source_dir}
    ELSE
        ${r}=                           Run Process  cmake
        ...                             -DRENODE_CFG\=${RENODE_CFG}
        ...                             -B  ${build_dir}
        ...                             -G  Unix Makefiles
        ...                             -S  ${source_dir}
    END
    Should Be Equal As Integers     ${r.rc}  0  msg=cmake configure failed: ${r.stderr}

    ${r}=                           Run Process  cmake  --build  ${build_dir}
    Should Be Equal As Integers     ${r.rc}  0  msg=cmake build failed: ${r.stderr}

Run Native Host
    [Arguments]                     ${host}  @{args}
    # The host's own Renode runs the test, so the host's output replaces the test log of the unused
    # Renode, and Renode Test Teardown keeps that log only when the test fails.
    ${log_path}=                    Get Test Log Path
    # Closes the unused Renode's handle on the log before the host opens it. The call returns only
    # after the handle is closed, so the two never write to the file at the same time.
    Close Log File
    # Writes the outputs to a file, because Run Process reads a pipe only after the host exits, and
    # a host with much output would block on a full pipe.
    ${result}=                      Run Process  ${host}  @{args}  stdout=${log_path}  stderr=STDOUT
    ...                             timeout=60s  on_timeout=kill
    Should Be Equal As Integers     ${result.rc}  0  msg=Host exited with code ${result.rc}

Run Guest Program With Native Host
    [Arguments]                     ${program}  ${host}  @{args}
    ${build_dir}=                   Allocate Temporary Directory  native-host-build
    Build NativeInterface Project   ${EXAMPLE_DIR}  ${build_dir}

    # The machine is named after the suite file, and each host hardcodes that name.
    ${suite}=                       Evaluate  os.path.splitext(os.path.basename($SUITE_SOURCE))[0]  modules=os.path
    ${script}=                      Catenate  SEPARATOR=${\n}
    ...                             mach create "${suite}"
    ...                             machine LoadPlatformDescription @platforms/cpus/cortex-a78.repl
    ...                             machine LoadPlatformDescriptionFromString "dut: Bus.ExternalControlBusPeripheral @ sysbus 0x10000000 { size: 0x1000 }"
    ...                             machine LoadPlatformDescriptionFromString "gpio: GPIOPort.ARM_AHB_GPIO @ sysbus 0x10001000"
    ...                             cpu AssembleBlock 0x40000000 """
    ...                             ${program}
    ...                             """ triple="arm64"
    ...                             cpu PC 0x40000000
    ${script_path}=                 Set Variable  ${build_dir}/${suite}.resc
    Create File                     ${script_path}  ${script}

    Run Native Host                 ${build_dir}/${host}  ${script_path}  @{args}
