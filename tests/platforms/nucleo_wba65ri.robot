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
    Execute Command                 sysbus.usart3
    Execute Command                 sysbus.spi2
    Execute Command                 sysbus.i2c2
    Execute Command                 sysbus.i2c4
    Execute Command                 sysbus.timer4
    Execute Command                 sysbus.crc
    Execute Command                 sysbus.rng
    Execute Command                 sysbus.gpioPortD
    Execute Command                 sysbus.gpioPortE
    Execute Command                 sysbus.gpioPortG

    # Verify DBGMCU IDCODE (STM32WBA6x = 0x492)
    ${idcode}=                      Execute Command                 sysbus ReadDoubleWord 0xE0044000
    Should Be Equal As Integers     ${idcode}                       0x10006492

    # Verify System Information factory calibration memory
    ${flash_kb}=                    Execute Command                 sysbus.systemInformation ReadWord 0x500
    Should Be Equal As Integers     ${flash_kb}                     0x0800

    ${uid0}=                        Execute Command                 sysbus.systemInformation ReadDoubleWord 0x700
    Should Be Equal As Integers     ${uid0}                         0x12345678

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
