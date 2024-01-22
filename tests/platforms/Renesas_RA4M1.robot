*** Variables ***
${URL}                  https://dl.antmicro.com/projects/renode
${SHELL_ELF}            arduino_uno_r4_minima-zephyr-shell_module.elf-s_1068728-aab68bf55c34638d1ba641464a8456a04bfff1df
${GPT_ELF}              gpt_ek_ra4m1_ep.elf-s_765644-1d962f940be6f73024384883e7d6322a2a269ce0

*** Keywords ***
Prepare Machine
    [Arguments]                 ${bin}
    Execute Command             set bin @${URL}/${bin}
    Execute Command             include @scripts/single-node/arduino_uno_r4_minima.resc

Prepare UART Tester
    Create Terminal Tester      sysbus.sci2

Prepare Segger RTT
    Execute Command             machine CreateVirtualConsole "segger_rtt"
    Execute Command             include @scripts/single-node/renesas-segger-rtt.py
    Execute Command             setup_segger_rtt sysbus.segger_rtt
    Create Terminal Tester      sysbus.segger_rtt

*** Test Cases ***
Run ZephyrRTOS Shell
    Prepare Machine             ${SHELL_ELF}
    Prepare UART Tester

    Start Emulation
    Wait For Prompt On Uart     uart:~$
    Write Line To Uart          demo ping
    Wait For Line On Uart       pong

Should Run The Timer In One Shot Mode
    Prepare Machine              ${GPT_ELF}
    Prepare Segger RTT

    Wait For Prompt On Uart      User Input:
    Write Line To Uart           3    waitForEcho=false

    Wait For Line On Uart        Timer Expired in One-Shot Mode
