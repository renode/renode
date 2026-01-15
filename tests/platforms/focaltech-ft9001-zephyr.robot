*** Variables ***
${SCRIPT_PATH}                      @scripts/single-node/focaltech_ft9001_zephyr.resc
${UART}                             sysbus.usart2

*** Keywords ***
Create Machine 
    Execute Command                 include ${SCRIPT_PATH}

    Create Terminal Tester          ${UART}  timeout=0.1  defaultPauseEmulation=true

*** Test Cases ***
Should Print Board Name In Shell
    Create Machine 

    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              demo board

    Wait For Line On Uart           ft9001_eval

