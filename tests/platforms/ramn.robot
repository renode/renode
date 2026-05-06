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
