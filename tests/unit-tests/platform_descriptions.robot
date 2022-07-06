*** Settings ***
Suite Setup                   Get Test Cases

*** Variables ***
${cpus_path}=                 ${CURDIR}${/}..${/}..${/}platforms${/}cpus
@{pattern}=                   *.repl

*** Keywords ***
Get Test Cases
    Setup
    # This line must use the "path" notation to handle paths with spaces
    @{platforms}=             List Files In Directory Recursively  ${cpus_path}  @{pattern}
    ${list_length}=           Get Length  ${platforms}
    Should Not Be True        ${list_length} == 0
    Set Suite Variable        ${platforms}

Try Load Platform
    [Arguments]               ${repl}
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription "${repl}"
    Reset Emulation

*** Test Cases ***
Should Load Repls
    # This tests uses templates as it tests every item on the list, even if a prior one failed, and produces aggregated fails summary
    [Template]  Try Load Platform
    FOR  ${test}  IN  @{platforms}
        ${test}
    END
