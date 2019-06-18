*** Settings ***
Library                       Process
Library                       DateTime
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Run Keywords
Test Teardown                 Reset Emulation
Resource                      ${CURDIR}/../../src/Renode/RobotFrameworkEngine/renode-keywords.robot

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