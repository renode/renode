*** Variables ***
${URL}                              https://dl.antmicro.com/projects/renode
${GPT_ELF}                          ${URL}/renesas-rzg2l_evk--fsp-gpt_rzg2l_evk_ep.elf-s_450148-fec1da811a52fa94d39db555d0dccc28e246d28e

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

*** Test Cases ***
Should Run The Timer In One Shot Mode
    Prepare Machine                 ${GPT_ELF}
    Prepare Segger RTT

    Wait For Prompt On Uart         User Input:
    Write Line To Uart              3  waitForEcho=false

    Wait For Line On Uart           Opened Timer in ONE-SHOT Mode
    Wait For Line On Uart           Started Timer in ONE-SHOT Mode
    Wait For Line On Uart           Timer Expired in One-Shot Mode
