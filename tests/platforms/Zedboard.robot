*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/zedboard.resc
${UART}                       sysbus.uart1
${PROMPT}                     zynq>
${GPIO_PERIPHERAL}            gpio.led0
${GPIO_FILE}                  /sys/class/gpio/gpio61/value

*** Keywords ***
Prepare Machine
    Execute Script            ${SCRIPT}

    Execute Command           emulation CreateLEDTester "led0" ${GPIO_PERIPHERAL}
    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Boot Linux
    [Documentation]           Boots Linux on the Zynq 7000-based Zedboard platform.
    [Tags]                    linux  uart
    Prepare Machine

    Start Emulation

    Wait For Prompt On Uart   ${PROMPT}

    Provides                  booted-linux

Should Ls
    [Documentation]           Tests shell responsiveness in Linux on the Zedboard platform.
    [Tags]                    linux  uart
    Requires                  booted-linux

    Write Line To Uart        ls /
    Wait For Line On Uart     proc

Should Persist GPIO State
    [Documentation]           Tests whether the GPIO state persists after a change from userspace.
    [Tags]                    linux  uart  gpio
    Requires                  booted-linux

    Write Line To Uart        echo 1 > ${GPIO_FILE}
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        cat ${GPIO_FILE}
    Wait For Line On Uart     1

    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        echo 0 > ${GPIO_FILE}
    Wait For Prompt On Uart   ${PROMPT}
    Write Line To Uart        cat ${GPIO_FILE}
    Wait For Line On Uart     0

Should Expose GPIO State
    [Documentation]           Tests whether the GPIO seen by the simulator matches Linux's view.
    [Tags]                    linux  uart  gpio
    Requires                  booted-linux

    Write Line To Uart        echo 1 > ${GPIO_FILE}
    Wait For Prompt On Uart   ${PROMPT}
    Execute Command           led0 AssertState true 0

    Write Line To Uart        echo 0 > ${GPIO_FILE}
    Wait For Prompt On Uart   ${PROMPT}
    Execute Command           led0 AssertState false 0
