*** Variables ***
${UART}                             sysbus.lpuart0
${SCRIPT}                           scripts/single-node/vegaboard_ri5cy.resc

*** Test Cases ***
Should Run Zephyr Shell Module Sample
    Execute Script                  ${SCRIPT}
    Create Terminal Tester          ${UART}  timeout=5  defaultPauseEmulation=true

    Create Log Tester               1
    Execute Command                 logLevel -1 intmux0

    # Verify if INTMUX InterruptEnableRegister (CHn_IER) is working properly
    Wait For Log Entry              intmux0: Channel 0, changed interrupt 7 enable: False -> True  pauseEmulation=True
    Wait For Log Entry              intmux0: Channel 1, changed interrupt 27 enable: False -> True  pauseEmulation=True
    Wait For Log Entry              intmux0: Channel 1, changed interrupt 17 enable: False -> True  pauseEmulation=True
    Wait For Log Entry              intmux0: Channel 1, changed interrupt 16 enable: False -> True  pauseEmulation=True
    Wait For Log Entry              intmux0: Channel 1, changed interrupt 15 enable: False -> True  pauseEmulation=True

    Wait For Line On Uart           uart:~$  includeUnfinishedLine=true
    Write Line To Uart              demo ping
    Wait For Line On Uart           pong  includeUnfinishedLine=true
