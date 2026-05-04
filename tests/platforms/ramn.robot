*** Test Cases ***
Should Produce CAN Traffic
    Execute Command          include @scripts/multi-node/ramn.resc
    Create Log Tester        timeout=1
    Execute Command          logLevel 0 canHub
    # Check that the 3 ECUs that are active (B,C,D) send traffic
    Wait For Log Entry       canHub: Received from ECUB
    Wait For Log Entry       canHub: Received from ECUC
    Wait For Log Entry       canHub: Received from ECUD

Engine Key Should Affect Battery LED
    ${LEDHoldingTimeout}    Set Variable    2

    Execute Command         include @scripts/multi-node/ramn.resc
    Create Log Tester       timeout=1
    CreateLEDTester         sysbus.spi2.ledController.batteryWarning  machine=ECUD
    # Wait 5 seconds for the LEDs to turn off after the startup sequence
    Execute Command         emulation RunFor "5s"
    AssertAndHoldLedState   false   timeoutAssert=0     timeoutHold=${LEDHoldingTimeout}

    Execute Command         SetEngineKey 'middle'
    AssertAndHoldLedState   true    timeoutAssert=1     timeoutHold=${LEDHoldingTimeout}

    Execute Command         SetEngineKey 'left'
    AssertAndHoldLedState   false   timeoutAssert=1     timeoutHold=${LEDHoldingTimeout}

Should Init Screen on ECUA
    # Commands and data bytes sent by RAMN_SPI_InitScreen
    ${RAMN_SPI_InitScreen_bytes}    Set Variable  0x1  0x11  0x21  0x36  0x0  0x3A  0x55  0x2A  0x0
...                                               0xF0  0x0  0x0  0x2B  0x0  0xF0  0x0  0x0  0x13
...                                               0x29  0xB0  0x0  0xF8  0x33  0x0  0x20  0x1  0x20
...                                               0x0  0x0  0x37  0x0  0x20  0x2C

    Execute Command         include @scripts/multi-node/ramn.resc
    Execute Command         mach set "ECUA"
    Create Log Tester       timeout=5   defaultPauseEmulation=True
    Execute Command         logLevel 0 spi2.dummySpi

    FOR     ${byte}     IN  @{RAMN_SPI_InitScreen_bytes}
        Wait For Log Entry  spi2.dummySpi: Data received: ${byte}
    END
