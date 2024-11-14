*** Variables ***
${URL}                              https://dl.antmicro.com/projects/renode
${GPT_ELF}                          ${URL}/renesas-rzg2l_evk--fsp-gpt_rzg2l_evk_ep.elf-s_450148-fec1da811a52fa94d39db555d0dccc28e246d28e
${GTM_ELF}                          ${URL}/renesas-rzg2l_evk--fsp-gtm_rzg2l_evk_ep.elf-s_415532-a907c69248cf6f695c717ee7dd83cc29d6fff3b4

*** Keywords ***
Prepare Machine
    [Arguments]                     ${elf}
    Execute Command                 mach create "Renesas RZ/G2L"
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/renesas_rz_g2l.repl
    Execute Command                 macro reset "cpu0 IsHalted true; cpu1 IsHalted true; sysbus LoadELF @${elf} cpu=cpu_m33"
    Execute Command                 runMacro $reset

Prepare Segger RTT
    [Arguments]                     ${pauseEmulation}=true
    Execute Command                 machine CreateVirtualConsole "segger_rtt"
    Execute Command                 include @scripts/single-node/renesas-segger-rtt.py
    Execute Command                 setup_segger_rtt sysbus.segger_rtt
    Create Terminal Tester          sysbus.segger_rtt  defaultPauseEmulation=${pauseEmulation}

Elapsed Time Equals
    [Arguments]                     ${start}  ${end}  ${value}  ${margin}=0.8
    ${diff}=                        Evaluate  ${end} - ${start}
    Should Be True                  ${diff} >= ${value} - ${margin}
    Should Be True                  ${diff} <= ${value} + ${margin}

*** Test Cases ***
Should Run The Timer In One Shot Mode
    Prepare Machine                 ${GPT_ELF}
    Prepare Segger RTT

    Wait For Prompt On Uart         User Input:
    Write Line To Uart              3  waitForEcho=false

    Wait For Line On Uart           Opened Timer in ONE-SHOT Mode
    Wait For Line On Uart           Started Timer in ONE-SHOT Mode
    Wait For Line On Uart           Timer Expired in One-Shot Mode

Should Run GTM Sample
    Prepare Machine                 ${GTM_ELF}
    Prepare Segger RTT

    Wait For Prompt On Uart         One-shot mode:
    Write Line To Uart              10  waitForEcho=false
    Wait For Prompt On Uart         Periodic mode:
    Write Line To Uart              5  waitForEcho=false

    Wait For Prompt On Uart         Enter any key to start or stop the timers
    ${one_shot_start}=              Write Line To Uart  waitForEcho=false
    ${one_shot_end}=                Wait For Line On Uart  One-shot mode GTM timer elapsed
    Elapsed Time Equals             ${one_shot_start.timestamp}  ${one_shot_end.timestamp}  10

    Wait For Line On Uart           GTM1 is Enabled in Periodic mode
    FOR  ${i}  IN RANGE  0  3
        ${periodic_start}=              Wait For Line On Uart  Leds are: Off
        ${periodic_end}=                Wait For Line On Uart  Leds are: On
        Elapsed Time Equals             ${periodic_start.timestamp}  ${periodic_end.timestamp}  5  0.3
    END
