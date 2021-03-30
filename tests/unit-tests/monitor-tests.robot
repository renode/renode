*** Settings ***
Library                       Process
Library                       DateTime
Suite Setup                   Setup
Suite Teardown                Teardown
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Test Cases ***
Should Pause Renode
    ${pauselimit}=            Convert Time                 1
    Execute Command           i @scripts/single-node/miv.resc
    Execute Command           cpu PerformanceInMips 1
    Execute Command           emulation SetGlobalQuantum "10"
    Execute Command           s
    ${date} =                 Get Current Date	
    Execute Command           p
    ${date2} =                Get Current Date	
    ${elapsed_time}=          Subtract Date From Date      ${date2}     ${date}
    Should Be True            ${elapsed_time} < ${pauselimit}

Should Print Last Logs
    Execute Command           i @scripts/single-node/miv.resc        
    ${logs} =                 Execute Command  lastLog
    Should Contain            ${logs}  [INFO] cpu: Setting PC value to 0x80000000.

Should Overflow Buffer
    FOR    ${i}    IN RANGE    1000
        Execute Command  log "Test-${i}-Log"
    END
    ${logs} =                 Execute Command  lastLog 1000
    Should Contain            ${logs}  Test-0-Log
    Should Contain            ${logs}  Test-999-Log
    Should Not Contain        ${logs}  Test-1000-Log
    Execute Command           log "Test-1000-Log"
    ${logs} =                 Execute Command  lastLog 1000
    Should Not Contain        ${logs}  Test-0-Log
    Should Contain            ${logs}  Test-1-Log
    Should Contain            ${logs}  Test-1000-Log

Should Load Python Standard Library
    ${result} =               Execute Command  python "import SimpleHTTPServer"
    Should Not Contain        ${result}  No module named
