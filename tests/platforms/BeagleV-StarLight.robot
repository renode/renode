*** Variables ***
${SCRIPT}                     @scripts/single-node/beaglev_starlight.resc
${MACHINE0}                   machine0
${MACHINE1}                   machine1
${MAC_ADDR0}                  66:34:B0:6C:DE:A0
${MAC_ADDR1}                  66:34:B0:6C:DE:A1
${IP_ADDR0}                   192.168.0.5
${IP_ADDR1}                   192.168.0.6
${UART}                       sysbus.uart3


*** Keywords ***
Create Machine
    [Arguments]              ${machine}
    Execute Command          $name="${machine}"
    Execute Command          include @${SCRIPT}
    # We enable serial execution to ensure a deterministic result as this test uses 2 machines, each with 2 CPUs
    Execute Command          emulation SetGlobalSerialExecution True
    ${tester} =              Create Terminal Tester   ${UART}   40   ${machine}   defaultPauseEmulation=True
    RETURN                   ${tester}

Connect Machines To Switch
    Execute Command          emulation CreateSwitch "switch"
    Execute Command          connector Connect sysbus.ethernet switch   machine=${MACHINE0}
    Execute Command          connector Connect sysbus.ethernet switch   machine=${MACHINE1}

Verify U-Boot
    [Arguments]              ${tester}
    Wait For Line On Uart    OpenSBI v0.9                  testerId=${tester}
    Wait For Line On Uart    Platform Name\\s+: StarFive   testerId=${tester}   treatAsRegex=true
    Wait For Line On Uart    U-Boot 2021.01                testerId=${tester}
    Wait For Prompt On Uart  dwmac.10020000                testerId=${tester}

Login
    [Arguments]              ${tester}
    Wait For Prompt On Uart  buildroot login:     testerId=${tester}
    Write Line To Uart       root                 testerId=${tester}

    Wait For Prompt On Uart  Password:            testerId=${tester} 
    Write Line To Uart       starfive             testerId=${tester}     waitForEcho=false

Test Ping
    [Arguments]              ${packet_size}=56
    ${tester} =              Create Terminal Tester   ${UART}   machine=${MACHINE0}   defaultPauseEmulation=True
    Write Line To Uart       ping -As ${packet_size} -c 10 ${IP_ADDR0}   testerId=${tester}   waitForEcho=false
    Wait For Line On Uart    10 packets transmitted, 10 packets received, 0% packet loss  testerId=${tester}


*** Test Cases ***
Should Boot U-Boot
    ${tester0} =         Create Machine           ${MACHINE0}
    ${tester1} =         Create Machine           ${MACHINE1}

    Verify U-Boot  ${tester0}
    Verify U-Boot  ${tester1}

    Provides                 booted-uboot

Should Provide Two Linux Machines With Ethernet Connection
    Requires                 booted-uboot

    Connect Machines To Switch

    ${tester0} =             Create Terminal Tester   ${UART}   machine=${MACHINE0}   defaultPauseEmulation=True
    ${tester1} =             Create Terminal Tester   ${UART}   machine=${MACHINE1}   defaultPauseEmulation=True

    Login  ${tester0}
    Login  ${tester1}

    Wait For Prompt On Uart  \#                                             testerId=${tester0}
    Write Line To Uart       ifconfig eth0 down                             testerId=${tester0}
    Wait For Prompt On Uart  \#                                             testerId=${tester1}
    Write Line To Uart       ifconfig eth0 down                             testerId=${tester1}

    Wait For Prompt On Uart  \#                                             testerId=${tester0}
    Write Line To Uart       ifconfig eth0 hw ether ${MAC_ADDR0}            testerId=${tester0}
    Wait For Prompt On Uart  \#                                             testerId=${tester1}
    Write Line To Uart       ifconfig eth0 hw ether ${MAC_ADDR1}            testerId=${tester1}

    # MTU size must be decreased due to limiations of the driver
    Wait For Prompt On Uart  \#                                             testerId=${tester0}                                    
    Write Line To Uart       ifconfig eth0 mtu 440 up ${IP_ADDR0}           testerId=${tester0}  waitForEcho=false
    Wait For Prompt On Uart  \#                                             testerId=${tester1}                                    
    Write Line To Uart       ifconfig eth0 mtu 440 up ${IP_ADDR1}           testerId=${tester1}  waitForEcho=false

    Provides                 booted-linux

Should Ping
    Requires                 booted-linux
    Test Ping

Should Ping Large Payload
    Requires                 booted-linux
    Test Ping                packet_size=3200
