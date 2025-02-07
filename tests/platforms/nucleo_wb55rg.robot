*** Variables ***
${UART}                       sysbus.usart1

*** Test Cases ***
Run Zephyr Boot
    Execute Command           include @scripts/single-node/nucleo_wb55rg.resc

    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Booting Zephyr OS

Run Blink Uart Status
    Execute Command           include @scripts/single-node/nucleo_wb55rg.resc

    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     LED state: OFF
    ${timeInfo}=              Execute Command   emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}       Elapsed Virtual Time: 00:00:00

    Wait For Line On Uart     LED state: ON
    ${timeInfo}=              Execute Command   emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}       Elapsed Virtual Time: 00:00:01

    Wait For Line On Uart     LED state: OFF
    ${timeInfo}=              Execute Command   emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}       Elapsed Virtual Time: 00:00:02

Run Blink Led Status
    Execute Command           include @scripts/single-node/nucleo_wb55rg.resc
    Create Terminal Tester    ${UART}
    Create Led Tester         sysbus.gpioPortB.BlueLED

    Wait For Line On Uart     Booting Zephyr OS

    # durations are in microseconds
    Assert Led Is Blinking    testDuration=8  onDuration=1  offDuration=1  tolerance=0.001
