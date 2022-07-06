*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/mpc5567.resc
${UART}                       sysbus.uart
${PROMPT}                     QR5567>

*** Keywords ***
Prepare Machine
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Boot Redboot
    [Documentation]           Boots RedBoot on the MPC5567.
    [Tags]                    uart
    Prepare Machine

    Start Emulation

    Wait For Prompt On Uart   ${PROMPT}

    Provides                  booted-redboot

Should Print Version
    [Documentation]           Tests shell responsiveness in RedBoot on the MPC5567 platform.
    [Tags]                    uart
    Requires                  booted-redboot

    Write Line To Uart        version
    Wait For Line On Uart     Non-certified release, version v3_0 - built 15:25:23, Mar 11 2010
    Wait For Prompt On Uart   ${PROMPT}
