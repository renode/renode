*** Variables ***
${REMOTE}                               https://dl.antmicro.com/projects/renode

${RENODE_ROOT}                          ${CURDIR}${/}..${/}..${/}
${SNAPSHOT_PATH}                        ${RENODE_ROOT}current_build_snapshot
${SNAPSHOT_GZIP_PATH}                   ${SNAPSHOT_PATH}.gz
${ERROR_MESSAGE_BASE}                   KeywordException: Could not execute command '\.*': There was an error executing command '\.*'
${CORRUPTED_STATE_ERROR_MESSAGE_REGEX}  ${ERROR_MESSAGE_BASE}This snapshot is incompatible or the emulation's state is corrupted. Snapshot version: \.*. Your version: \.*
${CORRUPTED_METADATA_ERROR_REGEX}       ${ERROR_MESSAGE_BASE}The snapshot cannot be loaded as its metadata is corrupted.

*** Keywords ***
Try Execute Load Operation
    [Arguments]                     ${file}  ${error_msg_regex}
    ${error_msg}=                   Run Keyword And Expect Error  *  Execute Command  Load @${REMOTE}/${file}
    Should Match Regexp             ${error_msg}  ${error_msg_regex}

Verify Snapshot Load
    [Arguments]                     ${file}
    Execute Command                 Load @${file}
    Execute Command                 mach set 0
    Create Terminal Tester          sysbus.uart0  timeout=5  defaultPauseEmulation=true
    Wait For Line On Uart           uart:~$  includeUnfinishedLine=true
    Write Line To Uart              demo ping
    Wait For Line On Uart           pong  includeUnfinishedLine=true

*** Test Cases ***
Create Save For Current Build
    Execute Command                 include @scripts/single-node/zynqmp_zephyr.resc
    Execute Command                 start
    Execute Command                 Save @${SNAPSHOT_PATH}

Load Snapshot From Same Build
    Verify Snapshot Load            ${SNAPSHOT_PATH}

Load Gzipped Snapshot From Same Build
    Gzip File                       ${SNAPSHOT_PATH}  ${SNAPSHOT_GZIP_PATH}
    Verify Snapshot Load            ${SNAPSHOT_GZIP_PATH}

    Remove File                     ${SNAPSHOT_PATH}
    Remove File                     ${SNAPSHOT_GZIP_PATH}

Try Load Snapshot With Corrupted Simulation State
    Try Execute Load Operation      renode_snapshot_corrupted_simulation_state--renode-1.15.3  ${CORRUPTED_STATE_ERROR_MESSAGE_REGEX}

Try Load Snapshot With Corrupted Metadata
    Try Execute Load Operation      renode_snapshot_corrupted_metadata--d86a7c7f  ${CORRUPTED_METADATA_ERROR_REGEX}
