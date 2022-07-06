*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/gr716_zephyr.resc
${UART}                       sysbus.uart
${PROMPT}                     uart:~$

*** Keywords ***
Prepare Machine
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Boot Zephyr
    [Documentation]           Boots Zephyr on the GR716 platform.
    [Tags]                    zephyr  uart
    Prepare Machine

    Start Emulation

    Wait For Prompt On Uart   ${PROMPT}

    Provides                  booted-zephyr

Should Print Version
    [Documentation]           Tests shell responsiveness in Zephyr on the GR716 platform.
    [Tags]                    zephyr  uart
    Requires                  booted-zephyr

    Write Line To Uart        version
    Wait For Line On Uart     Zephyr version 2.6.99
