*** Variables ***
${SCRIPT}                     @scripts/single-node/beaglev_starlight.resc
${MACHINE0}                   machine0
${MACHINE1}                   machine1
${UART}                       sysbus.uart3


*** Keywords ***
Create Machine
    [Arguments]              ${machine}
    Execute Command          $name="${machine}"
    Execute Command          include @${SCRIPT}
    ${tester} =              Create Terminal Tester   ${UART}   40   ${machine}   defaultPauseEmulation=True
    [Return]                 ${tester}

Verify U-Boot
    [Arguments]              ${tester}
    Wait For Line On Uart    OpenSBI v0.9                  testerId=${tester}
    Wait For Line On Uart    Platform Name\\s+: StarFive   testerId=${tester}   treatAsRegex=true
    Wait For Line On Uart    U-Boot 2021.01                testerId=${tester}
    Wait For Prompt On Uart  dwmac.10020000                testerId=${tester}



*** Test Cases ***
Should Boot U-Boot
    ${tester0} =         Create Machine           ${MACHINE0}
    ${tester1} =         Create Machine           ${MACHINE1}

    Verify U-Boot  ${tester0}
    Verify U-Boot  ${tester1}

    Provides                 booted-uboot   Reexecution




