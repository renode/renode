*** Settings ***
Suite Setup                   Get Test Cases

*** Variables ***
${platforms_path}=            ${CURDIR}${/}..${/}..${/}platforms
@{pattern}=                   *.repl
${invalid_using_error}=       REGEXP: (?s:.)* Using 'invalid' does not exist(?s:.)*
${eq}=                        ==
# Some repls are not standalone and need to be included by other repls with "using" syntax
# or added dynamically to the existing platform with "machine LoadPlatformDescription" command.
# We maintain the known list of such repls to exclude from a standalone testing.
# These repls are either tested indirectly as the part of other repls or by dedicated scripts.
@{blacklist}=                 ${platforms_path}${/}boards${/}stm32f4_discovery-additional_gpios.repl
...                           ${platforms_path}${/}boards${/}mars_zx3-externals.repl
...                           ${platforms_path}${/}boards${/}leon3-externals.repl
...                           ${platforms_path}${/}boards${/}tegra_externals.repl
...                           ${platforms_path}${/}boards${/}stm32f4_discovery-bb.repl
...                           ${platforms_path}${/}boards${/}zedboard-externals.repl
...                           ${platforms_path}${/}boards${/}vexpress-externals.repl

*** Keywords ***
Get Test Cases
    Setup

    &{conditional_blacklist}=          Create Dictionary
    ...  ${platforms_path}${/}cpus${/}x86-kvm.repl                   '{system}' ${eq} 'Linux' and '{arch}' ${eq} 'x64'
    ...  ${platforms_path}${/}cpus${/}x86_64-kvm.repl                '{system}' ${eq} 'Linux' and '{arch}' ${eq} 'x64'

    ${system}=                Evaluate    platform.system()    modules=platform
    ${arch}=                  Evaluate    'arm' if platform.machine() in ['aarch64', 'arm64'] else 'x64'    modules=platform
    # This line must use the "path" notation to handle paths with spaces
    @{platforms}=             List Files In Directory Recursively  ${platforms_path}  @{pattern}
    Remove Values From List   ${platforms}  @{blacklist}

    FOR  ${platform}  ${condition}  IN  &{conditional_blacklist}
        ${condition}=                   Replace String  ${condition}  {system}  ${system}
        ${condition}=                   Replace String  ${condition}  {arch}  ${arch}
        IF  not (${condition})
            Remove Values From List     ${platforms}  ${platform}
        END
    END

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

Should Gracefully Fail At Invalid Using
  Execute Command               mach create
  Run Keyword And Expect Error  ${invalid_using_error}  Execute Command  machine LoadPlatformDescriptionFromString "using \\"invalid\\""

