*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/zedboard.resc
${UART}                       sysbus.uart1
${PROMPT}                     zynq>
${GPIO_PERIPHERAL}            gpio.led0
${GPIO_FILE}                  /sys/class/gpio/gpio967/value
${UART_TIMEOUT}               20

*** Keywords ***
Prepare Machine
    [Arguments]               ${name}=Zedboard

    Execute Command           $name="${name}"
    Execute Script            ${SCRIPT}

*** Test Cases ***
Should Boot Linux
    [Documentation]           Boots Linux on the Zynq 7000-based Zedboard platform.
    [Tags]                    linux  uart

    Prepare Machine
    Create Terminal Tester    ${UART}  timeout=${UART_TIMEOUT}

    Start Emulation

    Wait For Line On Uart     Booting Linux on physical CPU 0x0
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
    Execute Command           emulation CreateLEDTester "led0" ${GPIO_PERIPHERAL}

    Write Line To Uart        echo 1 > ${GPIO_FILE}
    Wait For Prompt On Uart   ${PROMPT}
    Execute Command           led0 AssertState true 0

    Write Line To Uart        echo 0 > ${GPIO_FILE}
    Wait For Prompt On Uart   ${PROMPT}
    Execute Command           led0 AssertState false 0

Should Ping
    [Documentation]           Tests whether Ethernet works on the Zedboard platform.
    [Tags]                    linux  uart  ethernet

    Prepare Machine           Zedboard1
    Prepare Machine           Zedboard2

    ${tester1}=               Create Terminal Tester  ${UART}  machine=Zedboard1  timeout=${UART_TIMEOUT}
    ${tester2}=               Create Terminal Tester  ${UART}  machine=Zedboard2  timeout=${UART_TIMEOUT}

    Execute Command           emulation CreateSwitch "switch"  machine=Zedboard1

    Execute Command           connector Connect gem0 switch    machine=Zedboard1
    Execute Command           connector Connect gem0 switch    machine=Zedboard2

    Start Emulation

    Wait For Prompt On Uart   ${PROMPT}  testerId=${tester1}
    Write Line To Uart        ifconfig eth0 up 192.168.1.1  testerId=${tester1}
    Wait For Line On Uart     eth0: link becomes ready  testerId=${tester1}

    Wait For Prompt On Uart   ${PROMPT}  testerId=${tester2}
    Write Line To Uart        ifconfig eth0 up 192.168.1.2  testerId=${tester2}
    Wait For Line On Uart     eth0: link becomes ready  testerId=${tester2}

    # press enter to force printing of the prompt
    Send Key To Uart          10         testerId=${tester1}
    Wait For Prompt On Uart   ${PROMPT}  testerId=${tester1}

    # press enter to force printing of the prompt
    Send Key To Uart          10         testerId=${tester2}
    Wait For Prompt On Uart   ${PROMPT}  testerId=${tester2}

    Write Line To Uart        ping -c 5 192.168.1.2  testerId=${tester1}
    Wait For Line On Uart     5 packets transmitted, 5 packets received, 0% packet loss  testerId=${tester1}
    Wait For Prompt On Uart   ${PROMPT}  testerId=${tester1}
