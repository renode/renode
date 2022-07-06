*** Variables ***
${PROMPT}                      H2U

*** Keywords ***
Create Platform
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @platforms/boards/arty_litex_vexriscv.repl
    Execute Command            sysbus LoadELF @https://dl.antmicro.com/projects/renode/arty_litex_vexriscv--firmware.elf-s_438376-e20651f6e9625812f6588ce2b79c978f2c4d7eab

*** Test Cases ***
Should Boot
    Create Platform
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Wait For Prompt On Uart    ${PROMPT}

    Provides                   booted-image

Should Control LEDs
    Requires                   booted-image

    Execute Command            emulation CreateLEDTester "led0_tester" cas.led0
    Execute Command            emulation CreateLEDTester "led1_tester" cas.led1
    Execute Command            emulation CreateLEDTester "led2_tester" cas.led2
    Execute Command            emulation CreateLEDTester "led3_tester" cas.led3

    Execute Command            led0_tester AssertState false
    Execute Command            led1_tester AssertState false
    Execute Command            led2_tester AssertState false
    Execute Command            led3_tester AssertState false

    Write Line To Uart         debug cas leds 1
    Wait For Prompt On Uart    ${PROMPT}
    Execute Command            led0_tester AssertState true
    Execute Command            led1_tester AssertState false
    Execute Command            led2_tester AssertState false
    Execute Command            led3_tester AssertState false

    Write Line To Uart         debug cas leds 3
    Wait For Prompt On Uart    ${PROMPT}
    Execute Command            led0_tester AssertState true
    Execute Command            led1_tester AssertState true
    Execute Command            led2_tester AssertState false
    Execute Command            led3_tester AssertState false

    Write Line To Uart         debug cas leds 7
    Wait For Prompt On Uart    ${PROMPT}
    Execute Command            led0_tester AssertState true
    Execute Command            led1_tester AssertState true
    Execute Command            led2_tester AssertState true
    Execute Command            led3_tester AssertState false

    Write Line To Uart         debug cas leds 15
    Wait For Prompt On Uart    ${PROMPT}
    Execute Command            led0_tester AssertState true
    Execute Command            led1_tester AssertState true
    Execute Command            led2_tester AssertState true
    Execute Command            led3_tester AssertState true

    Write Line To Uart         debug cas leds 0
    Wait For Prompt On Uart    ${PROMPT}
    Execute Command            led0_tester AssertState false
    Execute Command            led1_tester AssertState false
    Execute Command            led2_tester AssertState false
    Execute Command            led3_tester AssertState false

Should Read Switches
    Requires                   booted-image

    Write Line To Uart         debug cas switches
    Wait For Line On Uart      0

    Execute Command            cas.switch0 Toggle
    Write Line To Uart         debug cas switches
    Wait For Line On Uart      1

    Execute Command            cas.switch1 Toggle
    Write Line To Uart         debug cas switches
    Wait For Line On Uart      3

    Execute Command            cas.switch2 Toggle
    Write Line To Uart         debug cas switches
    Wait For Line On Uart      7

    Execute Command            cas.switch3 Toggle
    Write Line To Uart         debug cas switches
    Wait For Line On Uart      F

    Execute Command            cas.switch0 Toggle
    Execute Command            cas.switch1 Toggle
    Execute Command            cas.switch2 Toggle
    Execute Command            cas.switch3 Toggle
    Write Line To Uart         debug cas switches
    Wait For Line On Uart      0

Should Read Buttons
    Requires                   booted-image

    Write Line To Uart         debug cas buttons read
    Wait For Line On Uart      0 0

    Execute Command            cas.button0 Toggle
    Write Line To Uart         debug cas buttons read
    Wait For Line On Uart      1 1

    Execute Command            cas.button1 Toggle
    Write Line To Uart         debug cas buttons read
    Wait For Line On Uart      3 3

    Execute Command            cas.button2 Toggle
    Write Line To Uart         debug cas buttons read
    Wait For Line On Uart      7 7

    Execute Command            cas.button3 Toggle
    Write Line To Uart         debug cas buttons read
    Wait For Line On Uart      F F

    Execute Command            cas.button0 Toggle
    Execute Command            cas.button1 Toggle
    Execute Command            cas.button2 Toggle
    Execute Command            cas.button3 Toggle
    Write Line To Uart         debug cas buttons read
    Wait For Line On Uart      0 F

    Write Line To Uart         debug cas buttons clear
    Write Line To Uart         debug cas buttons read
    Wait For Line On Uart      0 0

Should Read Ethernet PHY Status
    [Documentation]         Reads the status of LiteX Ethernet PHY.
    Create Platform
    Create Terminal Tester  sysbus.uart

    # MDIO status: 10Mbps + link down
    Execute Command         eth.phy VendorSpecific1 0x0
    Start Emulation

    Wait For Line On Uart   MDIO mode: 10Mbps / link: down

    # MDIO status: 100Mbps + link up
    Execute Command         eth.phy VendorSpecific1 0x4400
    Write Line To Uart      mdio_status
    Wait For Line On Uart   MDIO mode: 100Mbps / link: up
