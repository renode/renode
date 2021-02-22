*** Settings ***
Suite Setup                 Setup
Suite Teardown              Teardown
Test Setup                  Reset Emulation
Test Teardown               Test Teardown
Resource                    ${RENODEKEYWORDS}

*** Variables ***
${UART}                     sysbus.uart
${URI}                      @https://dl.antmicro.com/projects/renode

*** Keywords ***
Setup Machine
    [Arguments]             ${elf}

    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/boards/eos-s3-quickfeather.repl

    Execute Command         sysbus LoadELF ${URI}/${elf}
    Create Terminal Tester  ${UART}
    Write Char Delay        2

*** Test Cases ***
Should Output Voice Data
    [Tags]                  non_critical
    Setup Machine           quick_feather--pdm_ssi_ai_app.elf-s_937812-050bf0cc75919a2268bd91497b4c893945c96df5

    Execute Command         sysbus.voice SetInputFile ${URI}/audio_yes_1s.s16le.pcm-s_32000-b69f5518615516f80ae0082fe9b5a5d29ffebce8

    Start Emulation
    Wait For Line On Uart   sample_rate
    Write Line To Uart      connect  waitForEcho=false
    Wait For Line On Uart   f9 ff f4 ff ee ff ec ff ec ff
    Wait For Line On Uart   ae ff a9 ff a8 ff a4 ff a2 ff
    Wait For Line On Uart   e3 ff dd ff d6 ff cc ff be ff

