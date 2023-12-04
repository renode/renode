*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/andes_ae350_zephyr.resc
${UART}                       sysbus.uart1
${PROMPT}                     uart:~$

*** Keywords ***
Prepare Machine
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Boot Zephyr
    [Tags]                    zephyr  uart
    Prepare Machine

    Start Emulation
    Wait For Prompt On Uart   ${PROMPT}

    Provides                  booted-zephyr

Should Print Version
    [Tags]                    zephyr  uart
    Requires                  booted-zephyr

    Write Line To Uart        version
    Wait For Line On Uart     Zephyr version 3.5.99
