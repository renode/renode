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
    Execute Command         include @scripts/multi-node/ramn.resc
    Create Log Tester       timeout=1
    # Wait 5 seconds for the LEDs to turn off after the startup sequence
    Execute Command         emulation RunFor "5s"
    Execute Command         logLevel 0 spi2.dummySpi
    Wait For Log Entry      spi2.dummySpi: Data received: 0x38  pauseEmulation=True

    Execute Command         SetEngineKey 'middle'
    Wait For Log Entry      spi2.dummySpi: Data received: 0x39  pauseEmulation=True

    Execute Command         SetEngineKey 'left'
    Wait For Log Entry      spi2.dummySpi: Data received: 0x38
