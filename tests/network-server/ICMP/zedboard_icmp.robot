*** Settings ***
Library                           Process
Suite Setup                       Setup
Suite Teardown                    Teardown
Test Setup                        Reset Emulation
Test Teardown                     Test Teardown
Resource                          ${RENODEKEYWORDS}

*** Variables ***
${SCRIPT}                     scripts/single-node/zedboard.resc

*** Test Cases ***
Ping Network Server with Zedboard
    Execute Script              ${SCRIPT}
    Execute Command             emulation CreateNetworkServer "server" "192.168.1.11"
    Execute Command             connector Connect server switch
    Create Terminal Tester      sysbus.uart1
    Start Emulation

    Wait For Line On Uart       xemacps e000b000.ps7-ethernet: link up (100/FULL)
    Send Key To Uart            0xd
    Wait For Prompt On Uart     zynq> 
    Write Line To Uart          ping 192.168.1.11 -w 1
    Wait For Line On Uart       1 packets transmitted, 1 packets received, 0% packet loss
    