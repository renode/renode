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

*** Test Cases ***
Should Output Voice Data
    Setup Machine           quick_feather--pdm_ssi_ai_app.elf-s_937812-050bf0cc75919a2268bd91497b4c893945c96df5

    Execute Command         sysbus.voice SetInputFile ${URI}/audio_yes_1s.s16le.pcm-s_32000-b69f5518615516f80ae0082fe9b5a5d29ffebce8

    Start Emulation
    Wait For Line On Uart   sample_rate
    Write To Uart           connect
    Wait For Line On Uart   f9 ff f4 ff ee ff ec ff ec ff
    Wait For Line On Uart   ae ff a9 ff a8 ff a4 ff a2 ff
    Wait For Line On Uart   e3 ff dd ff d6 ff cc ff be ff

Should Run Zephyr posix.common Test
    [Tags]                  zephyr
    Setup Machine           quick_feather--zephyr-posix_common-test.elf-s_747648-0aab8537f58c0086780e382109b44a594f21555c

    Start Emulation
    Wait For Line On Uart   PROJECT EXECUTION SUCCESSFUL  120

Should Run Zephyr portability.cmsis_rtos_v1 Test
    [Tags]                  zephyr
    Setup Machine           quick_feather--zephyr-portability_cmsis_rtos_v1-test.elf-s_806480-48711ea8a593346c71435de4db3d595aee334ab8

    Start Emulation
    Wait For Line On Uart   PROJECT EXECUTION SUCCESSFUL  120

Should Run Zephyr portability.cmsis_rtos_v2 Test
    [Tags]                  zephyr
    Setup Machine           quick_feather--zephyr-portability_cmsis_rtos_v2-test.elf-s_877448-f34ad2f8bc7ae4712fa6a66523267c5f573fdcf1

    Start Emulation
    Wait For Line On Uart   PROJECT EXECUTION SUCCESSFUL  30

Should Run Zephyr subsys.shell.shell Test
    [Tags]                  zephyr
    Setup Machine           quick_feather--zephyr-subsys_shell_shell-test.elf-s_782956-27557acc2e53a2225a74ac070f54c4a0fb5dac29

    Start Emulation
    Wait For Line On Uart   PROJECT EXECUTION SUCCESSFUL  10
