# Some influential variables:
#   USER_RENODE_DIR - path to an extracted Renode package (must contain librenode.so in the bin/
#                     subdirectory for packages or in the package root for portable packages)
#                     Optional when running from a Renode source tree built with ./build.sh --shared
#                     For packages: tar -C <dir> --strip-components=1 -xf renode-*.linux.tar.gz
#                     Then pass: renode-test --variable USER_RENODE_DIR:<dir> <suite>.robot
#   CONFIGURATION   - Renode build configuration. Normally overridden by renode-test so you don't have
#                     to worry about it, but specified here to please the LSP.

*** Variables ***
${CONFIGURATION}                    Release
${USER_RENODE_DIR}                  ${EMPTY}
${RENODE_CFG}                       ${CONFIGURATION}

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
