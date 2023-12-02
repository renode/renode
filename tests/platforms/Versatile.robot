*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/versatile.resc
${UART}                       sysbus.uart0
${PROMPT}                     \#${SPACE}

*** Keywords ***
Prepare Machine
    [Arguments]               ${name}=Versatile

    Execute Command           $name="${name}"
    Execute Script            ${SCRIPT}

*** Test Cases ***
Should Boot Linux
    [Documentation]           Boots Linux on the Versatile platform.
    [Tags]                    linux  uart

    Prepare Machine
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Booting Linux on physical CPU 0x0
    Wait For Line On Uart     Welcome to the Renode Versatile demo!
    Wait For Prompt On Uart   master login:

    Write Line To Uart        root
    Wait For Prompt On Uart   ${PROMPT}

    Provides                  booted-linux

Should Ls
    [Documentation]           Tests shell responsiveness in Linux on the Versatile platform.
    [Tags]                    linux  uart
    Requires                  booted-linux

    # wait for the psmouse line to avoid serial output cluttering
    Wait For Line On Uart     psmouse serio1: Failed to enable mouse on fpga:07
    Write Line To Uart        ls /
    Wait For Line On Uart     proc

