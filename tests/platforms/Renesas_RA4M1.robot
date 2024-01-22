*** Variables ***
${URL}                  https://dl.antmicro.com/projects/renode
${SHELL_ELF}            arduino_uno_r4_minima-zephyr-shell_module.elf-s_1068728-aab68bf55c34638d1ba641464a8456a04bfff1df

*** Keywords ***
Prepare Machine
    [Arguments]                 ${bin}
    Execute Command             set bin @${URL}/${bin}
    Execute Command             include @scripts/single-node/arduino_uno_r4_minima.resc

Prepare UART Tester
    Create Terminal Tester      sysbus.sci2

*** Test Cases ***
Run ZephyrRTOS Shell
    Prepare Machine             ${SHELL_ELF}
    Prepare UART Tester

    Start Emulation
    Wait For Prompt On Uart     uart:~$
    Write Line To Uart          demo ping
    Wait For Line On Uart       pong
