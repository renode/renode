*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/quickfeather.resc

*** Keywords ***
Run Emulation With Auto Save
    [Arguments]  ${emulation_time}  ${auto_save_period}
    Execute Command  autoSave true ${auto_save_period}
    Execute Command  emulation RunFor "${emulation_time}"

*** Test Cases ***
Should Take First Snapshot Immediately
    Execute Script                ${SCRIPT}
    Execute Command               autoSave true 0.1

    ${snapshots_count}=           Execute Command  emulation SnapshotTracker Count
    Should Be Equal As Integers   ${snapshots_count}  1

Should Take Snapshot Exactly At Timestamp
    Execute Script                ${SCRIPT}
    Run Emulation With Auto Save  emulation_time=0.011  auto_save_period=0.01

    ${snapshots_count}=           Execute Command  emulation SnapshotTracker Count
    ${snapshots_info}=            Execute Command  emulation SnapshotTracker PrintDetailedSnapshotsInfo

    Should Be Equal As Integers   ${snapshots_count}  2
    Should Contain                ${snapshots_info}   00:00:00.000000
    Should Contain                ${snapshots_info}   00:00:00.010000

Should Take Snapshots Periodically
    Execute Script                ${SCRIPT}
    Run Emulation With Auto Save  emulation_time=0.05  auto_save_period=0.01

    ${snapshots_count}=           Execute Command  emulation SnapshotTracker Count
    ${snapshots_info}=            Execute Command  emulation SnapshotTracker PrintDetailedSnapshotsInfo

    Should Be Equal As Integers   ${snapshots_count}  6
    Should Contain                ${snapshots_info}   00:00:00.000000
    Should Contain                ${snapshots_info}   00:00:00.010000
    Should Contain                ${snapshots_info}   00:00:00.020000
    Should Contain                ${snapshots_info}   00:00:00.030000
    Should Contain                ${snapshots_info}   00:00:00.040000
    Should Contain                ${snapshots_info}   00:00:00.050000

Should Resume Taking Snapshots After Load
    Execute Script                ${SCRIPT}
    Run Emulation With Auto Save  emulation_time=0.01  auto_save_period=0.01

    ${snap_path}=                 Execute Command  emulation SnapshotTracker GetLastSnapshotBeforeOrAtTimeStamp "0.01"
    Execute Command               Load @${snap_path}
    Execute Command               mach set 0

    ${snapshots_count1}=          Execute Command  emulation SnapshotTracker Count
    ${snapshots_info1}=           Execute Command  emulation SnapshotTracker PrintDetailedSnapshotsInfo

    Should Be Equal As Integers   ${snapshots_count1}  2
    Should Contain                ${snapshots_info1}   00:00:00.000000
    Should Contain                ${snapshots_info1}   00:00:00.010000

    Execute Command               emulation RunFor "0.01"

    ${snapshots_count2}=          Execute Command  emulation SnapshotTracker Count
    ${snapshots_info2}=           Execute Command  emulation SnapshotTracker PrintDetailedSnapshotsInfo

    Should Be Equal As Integers   ${snapshots_count2}  3
    Should Contain                ${snapshots_info2}   00:00:00.000000
    Should Contain                ${snapshots_info2}   00:00:00.010000
    Should Contain                ${snapshots_info2}   00:00:00.020000

Should Stop Taking Snapshots
    Execute Script                ${SCRIPT}
    Run Emulation With Auto Save  emulation_time=0.015  auto_save_period=0.01

    Execute Command               autoSave false
    Execute Command               emulation RunFor "0.01"

    ${snapshots_info}=            Execute Command  emulation SnapshotTracker PrintDetailedSnapshotsInfo
    Should Not Contain            ${snapshots_info}  00:00:00.020000

Should Reenable Auto Save Properly
    Execute Script                ${SCRIPT}
    Run Emulation With Auto Save  emulation_time=0.011  auto_save_period=0.01
    Execute Command               autoSave false

    # before reenabling auto-save, registered snapshot should be cancelled, the code below checks it
    Execute Command               autoSave true 0.02
    ${snapshots_count1}=          Execute Command  emulation SnapshotTracker Count
    Execute Command               emulation RunFor "0.02"

    ${snapshots_count2}=          Execute Command  emulation SnapshotTracker Count

    Should Be Equal As Integers   ${snapshots_count1}  3
    Should Be Equal As Integers   ${snapshots_count2}  4

Should Forget Later Snapshots After Load
    Execute Script                ${SCRIPT}
    Run Emulation With Auto Save  emulation_time=0.021  auto_save_period=0.01

    ${snapshots_count1}=          Execute Command  emulation SnapshotTracker Count
    ${snapshots_info1}=           Execute Command  emulation SnapshotTracker PrintDetailedSnapshotsInfo

    Should Be Equal As Integers   ${snapshots_count1}  3
    Should Contain                ${snapshots_info1}   00:00:00.000000
    Should Contain                ${snapshots_info1}   00:00:00.010000
    Should Contain                ${snapshots_info1}   00:00:00.020000

    ${snap_path}=                 Execute Command  emulation SnapshotTracker GetLastSnapshotBeforeOrAtTimeStamp "0.01"
    Execute Command               Load @${snap_path}
    Execute Command               mach set 0

    ${snapshots_count2}=          Execute Command  emulation SnapshotTracker Count
    ${snapshots_info2}=           Execute Command  emulation SnapshotTracker PrintDetailedSnapshotsInfo

    Should Be Equal As Integers   ${snapshots_count2}  2
    Should Contain                ${snapshots_info2}   00:00:00.000000
    Should Contain                ${snapshots_info2}   00:00:00.010000

    Execute Command               emulation RunFor "0.00"
