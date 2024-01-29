*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/gr712rc.resc
${UART}                       sysbus.uart0

*** Keywords ***
Prepare Machine
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Run RTEMS Hello World with LEON3 PROM
    Prepare Machine

    Start Emulation

    Wait For Line On Uart     MKPROM2 boot loader v2.0.69
    Wait For Line On Uart     starting rtems-hello
    Wait For Line On Uart     Hello World over printk() on Debug console
