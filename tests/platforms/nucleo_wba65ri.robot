*** Variables ***
${PLATFORM}                         @platforms/boards/nucleo_wba65ri.repl
${HEARTBEAT_LED}                    sysbus.gpioPortC.HeartbeatLed
${USER_BUTTON}                      sysbus.gpioPortC.UserButton

*** Keywords ***
Create NUCLEO WBA65RI Machine
    Execute Command                 mach create "nucleo_wba65ri"
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}

*** Test Cases ***
Should Initialize Peripherals Correctly
    Create NUCLEO WBA65RI Machine

    # Verify memory sizes
    ${flash_size}=                  Execute Command                 sysbus.flash Size
    Should Contain                  ${flash_size}                   0x200000

    ${sram_size}=                   Execute Command                 sysbus.sram Size
    Should Contain                  ${sram_size}                    0x80000

    # Verify newly added peripherals exist on sysbus
    Execute Command                 sysbus.sai1
    Execute Command                 sysbus.comp
    Execute Command                 sysbus.vrefbuf
    Execute Command                 sysbus.aes
    Execute Command                 sysbus.saes
    Execute Command                 sysbus.hash
    Execute Command                 sysbus.pka
    Execute Command                 sysbus.usb
    Execute Command                 sysbus.gpdma1

Should Handle VREFBUF Enable
    Create NUCLEO WBA65RI Machine

    # Enable VREFBUF (set ENVR bit 0)
    Execute Command                 sysbus WriteDoubleWord 0x46007400 0x1

    # Read back CSR register and verify VRR (bit 3) is asserted
    ${csr}=                         Execute Command                 sysbus ReadDoubleWord 0x46007400
    Should Be Equal As Integers     ${csr}                          9

Should Test User Button and LED
    Create NUCLEO WBA65RI Machine
    Create LED Tester               ${HEARTBEAT_LED}

    # Heartbeat LED initial state should be false
    Assert LED State                false

    # Button press and release should be accepted
    Execute Command                 ${USER_BUTTON} PressAndRelease
