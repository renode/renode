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

    ${led0_tester}=            Create LED Tester  sysbus.cas.led0
    ${led1_tester}=            Create LED Tester  sysbus.cas.led1
    ${led2_tester}=            Create LED Tester  sysbus.cas.led2
    ${led3_tester}=            Create LED Tester  sysbus.cas.led3

    Assert LED State           false  testerId=${led0_tester}
    Assert LED State           false  testerId=${led1_tester}
    Assert LED State           false  testerId=${led2_tester}
    Assert LED State           false  testerId=${led3_tester}

    Write Line To Uart         debug cas leds 1
    Wait For Prompt On Uart    ${PROMPT}
    Assert LED State           true   testerId=${led0_tester}
    Assert LED State           false  testerId=${led1_tester}
    Assert LED State           false  testerId=${led2_tester}
    Assert LED State           false  testerId=${led3_tester}

    Write Line To Uart         debug cas leds 3
    Wait For Prompt On Uart    ${PROMPT}
    Assert LED State           true  testerId=${led0_tester}
    Assert LED State           true  testerId=${led1_tester}
    Assert LED State           false  testerId=${led2_tester}
    Assert LED State           false  testerId=${led3_tester}

    Write Line To Uart         debug cas leds 7
    Wait For Prompt On Uart    ${PROMPT}
    Assert LED State           true  testerId=${led0_tester}
    Assert LED State           true  testerId=${led1_tester}
    Assert LED State           true  testerId=${led2_tester}
    Assert LED State           false  testerId=${led3_tester}

    Write Line To Uart         debug cas leds 15
    Wait For Prompt On Uart    ${PROMPT}
    Assert LED State           true  testerId=${led0_tester}
    Assert LED State           true  testerId=${led1_tester}
    Assert LED State           true  testerId=${led2_tester}
    Assert LED State           true  testerId=${led3_tester}

    Write Line To Uart         debug cas leds 0
    Wait For Prompt On Uart    ${PROMPT}
    Assert LED State           false  testerId=${led0_tester}
    Assert LED State           false  testerId=${led1_tester}
    Assert LED State           false  testerId=${led2_tester}
    Assert LED State           false  testerId=${led3_tester}

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
