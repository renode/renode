*** Keywords ***
Create Machine
    Execute Command               include @scripts/single-node/hifive_unleashed.resc

*** Test Cases ***
Should Return Snapshot At Time Stamp
    Create Machine

    Execute Command               emulation RunFor "0.01"

    # create a temporary file so it can be automatically removed after Renode finishes
    ${snap_path}=                 Allocate Temporary File
    Execute Command               Save @${snap_path}

    ${result_path}=               Execute Command  emulation SnapshotTracker GetLastSnapshotBeforeOrAtTimeStamp "0.01"
    Should Be Equal As Strings    ${snap_path.strip()}  ${result_path.strip()}

Should Return Older Snapshot
    Create Machine

    Execute Command               emulation RunFor "0.01"
    ${snap_path1}=                Allocate Temporary File
    Execute Command               Save @${snap_path1}

    Execute Command               emulation RunFor "0.01"
    ${snap_path2}=                Allocate Temporary File
    Execute Command               Save @${snap_path2}

    ${result_path}=               Execute Command  emulation SnapshotTracker GetLastSnapshotBeforeOrAtTimeStamp "0.015"
    Should Be Equal As Strings    ${snap_path1.strip()}  ${result_path.strip()}

Should Return Last Snapshot Before Deleted One
    Create Machine

    Execute Command               emulation RunFor "0.01"
    ${snap_path1}=                Allocate Temporary File
    Execute Command               Save @${snap_path1}

    Execute Command               emulation RunFor "0.01"
    ${snap_path2}=                Allocate Temporary File
    Execute Command               Save @${snap_path2}

    Remove File                   ${snap_path2}

    ${result_path}=               Execute Command  emulation SnapshotTracker GetLastSnapshotBeforeOrAtTimeStamp "1.0"
    Should Be Equal As Strings    ${snap_path1.strip()}  ${result_path.strip()}

Should Throw Exception When No Older Snapshots
    Create Machine

    Execute Command               emulation RunFor "0.01"
    ${snap_path}=                 Allocate Temporary File
    Execute Command               Save @${snap_path}

    Run Keyword And Expect Error  *There are no snapshots taken before this timestamp*    Execute Command  emulation SnapshotTracker GetLastSnapshotBeforeOrAtTimeStamp "0.005"

Should Throw Exception When No Snapshots
    Create Machine

    Run Keyword And Expect Error  *There are no snapshots taken before this timestamp*    Execute Command  emulation SnapshotTracker GetLastSnapshotBeforeOrAtTimeStamp "1.0"

Should Count Snapshots Properly
    Create Machine

    ${snap_path1}=                Allocate Temporary File
    Execute Command               Save @${snap_path1}

    Execute Command               emulation RunFor "0.001"
    ${snap_path2}=                Allocate Temporary File
    Execute Command               Save @${snap_path2}

    ${snapshots_count}=           Execute Command  emulation SnapshotTracker Count
    Should Be Equal As Integers   ${snapshots_count}  2
