*** Settings ***
Suite Setup                   Get Test Cases

*** Variables ***
${scripts_path}=              ${CURDIR}${/}..${/}..${/}scripts
@{pattern}=                   *.resc
@{excludes}=                  complex
${eq}=                        ==

*** Keywords ***
Get Test Cases
    Setup

    &{conditional_blacklist}=           Create Dictionary
    ...  ${scripts_path}${/}single-node${/}x86-kvm-linux.resc           '{system}' ${eq} 'Linux' and '{arch}' ${eq} 'x64'
    ...  ${scripts_path}${/}single-node${/}x86-kvm-bios.resc            '{system}' ${eq} 'Linux' and '{arch}' ${eq} 'x64'
    ...  ${scripts_path}${/}single-node${/}x86_64-kvm-linux.resc        '{system}' ${eq} 'Linux' and '{arch}' ${eq} 'x64'
    ...  ${scripts_path}${/}single-node${/}x86_64-kvm-bios.resc         '{system}' ${eq} 'Linux' and '{arch}' ${eq} 'x64'

    ${system}=                Evaluate    platform.system()    modules=platform
    ${arch}=                  Evaluate    'arm' if platform.machine() in ['aarch64', 'arm64'] else 'x64'    modules=platform

    @{scripts}=  List Files In Directory Recursively  ${scripts_path}  @{pattern}  @{excludes}

    FOR  ${script}  ${condition}  IN  &{conditional_blacklist}
        ${condition}=                   Replace String  ${condition}  {system}  ${system}
        ${condition}=                   Replace String  ${condition}  {arch}  ${arch}
        IF  not (${condition})
            Remove Values From List     ${scripts}  ${script}
        END
    END

    Set Suite Variable  @{scripts}

Load Script
    [Arguments]               ${path}
    Execute Script            ${path}

*** Test Cases ***
Should Load Demos
    [Tags]                          skip_host_arm
    FOR  ${script}  IN  @{scripts}
        Load Script  ${script}
        Reset Emulation
    END
