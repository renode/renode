*** Variables ***
${SCRIPT_PATH}                      @scripts/single-node/egis_et171_zephyr.resc
${UART}                             sysbus.uart0
${SHELL_MODULE_BIN}                 @https://dl.antmicro.com/projects/renode/zephyr-egis_et171-shell_module.elf-s_1482184-28d8276402948a403d1037214b76a2115d1b2882

*** Keywords ***
Create Machine With Binary ${binary}
    Execute Command                 $bin=${binary}
    Execute Command                 include ${SCRIPT_PATH}

    Create Terminal Tester          ${UART}  timeout=0.1  defaultPauseEmulation=true

*** Test Cases ***
Should Print Board Name In Shell
    Create Machine With Binary ${SHELL_MODULE_BIN}

    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              demo board

    Wait For Line On Uart           egis_et171
