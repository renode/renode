*** Keywords ***
Battery LED Toggling From Engine Key
    [Arguments]     ${LEDHoldingTimeout}    ${LEDName}

    CreateLEDTester         sysbus.spi2.ledController.${LEDName}  machine=ECUD

    # Wait 5 seconds for the LEDs to turn off after the startup sequence
    Execute Command         emulation RunFor "5s"
    AssertAndHoldLedState   false   timeoutAssert=0     timeoutHold=${LEDHoldingTimeout}

    Execute Command         SetEngineKey 'middle'
    AssertAndHoldLedState   true    timeoutAssert=1     timeoutHold=${LEDHoldingTimeout}

    Execute Command         SetEngineKey 'left'
    AssertAndHoldLedState   false   timeoutAssert=1     timeoutHold=${LEDHoldingTimeout}

Trigger Watchdog Reset
    Create Log Tester       timeout=10  defaultPauseEmulation=true

    Execute Command         iwdg WriteDoubleWord 0x0 0x5555
    Execute Command         iwdg WriteDoubleWord 0x8 0x1
    Execute Command         iwdg WriteDoubleWord 0x0 0xCCCC
    Wait For Log Entry      Watchdog reset triggered!

    # The machine reset does not occur right after the watchdog requested it. Let's simulate it to
    # ensure it occurred when returning from this function. Furthermore, waiting for a reset log
    # (non existent right now) would not work because the machine would be briefly resumed between
    # the reset and the log tester founding the string because Machine.Reset released an obtained
    # paused state.
    #
    # If the caller restarts the simulation, the reset from the watchdog might happen.
    Execute Command         machine Reset


*** Test Cases ***
Should Produce CAN Traffic
    [Documentation]          Test data path ECU{B,C,D}'s CAN controller -> CAN hub

    Execute Command          include @scripts/multi-node/ramn.resc
    Create Log Tester        timeout=1
    Execute Command          logLevel 0 canHub
    # Check that the 3 ECUs that are active (B,C,D) send traffic
    Wait For Log Entry       canHub: Received from ECUB
    Wait For Log Entry       canHub: Received from ECUC
    Wait For Log Entry       canHub: Received from ECUD

Engine Key Should Affect Battery LED
    [Documentation]         Test on ECUD that the data paths ADC -> DMA -> Memory and STM32 SPI ->
    ...                     Led controller are working

    Execute Command         include @scripts/multi-node/ramn.resc

    Battery LED Toggling From Engine Key   2    batteryWarning

Engine Key Should Affect Battery LED After Reset
    [Documentation]         Test that after a watchdog reset, the ADC, DMA and SPI work

    Execute Command         include @scripts/multi-node/ramn.resc

    # Wait 5 seconds to ensure the system is fully started before resetting it
    Execute Command         emulation RunFor "5s"
    Trigger Watchdog Reset
    Battery LED Toggling From Engine Key   2    batteryWarning

Should Init Screen on ECUA
    [Documentation]         Test on ECUA that the data path Memory -> DMA -> SPI TX is working

    # Commands and data bytes sent by RAMN_SPI_InitScreen
    ${RAMN_SPI_InitScreen_bytes}    Set Variable  0x1  0x11  0x21  0x36  0x0  0x3A  0x55  0x2A  0x0
    ...                                           0xF0  0x0  0x0  0x2B  0x0  0xF0  0x0  0x0  0x13
    ...                                           0x29  0xB0  0x0  0xF8  0x33  0x0  0x20  0x1  0x20
    ...                                           0x0  0x0  0x37  0x0  0x20  0x2C

    Execute Command         include @scripts/multi-node/ramn.resc
    Execute Command         mach set "ECUA"
    Create Log Tester       timeout=5   defaultPauseEmulation=True
    Execute Command         logLevel 0 spi2.dummySpi

    FOR     ${byte}     IN  @{RAMN_SPI_InitScreen_bytes}
        Wait For Log Entry  spi2.dummySpi: Data received: ${byte}
    END
