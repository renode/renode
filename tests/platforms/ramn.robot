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
    Execute Command         logLevel 0 spi2.dummySpi
    Wait For Log Entry      spi2.dummySpi: Data received: 0x0

    Execute Command         SetEngineKey 'middle'
    Wait For Log Entry      spi2.dummySpi: Data received: 0x1

    Execute Command         SetEngineKey 'left'
    Wait For Log Entry      spi2.dummySpi: Data received: 0x0
