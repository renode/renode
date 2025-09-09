*** Variables ***
${UART}                       sysbus.uart
${SCRIPT_UBOOT}               @scripts/single-node/x86.resc
${SCRIPT_ZEPHYR}              @scripts/single-node/x86-zephyr.resc

*** Test Cases ***
Should Run U-Boot
    Execute Command           include ${SCRIPT_UBOOT}
    Create Terminal Tester    sysbus.uart
    Wait For Prompt On Uart   boot >

Should Run Zephyr hello_world Sample
    Execute Command           include ${SCRIPT_ZEPHYR}
    Create Terminal Tester    sysbus.uart
    Wait For Line On Uart     Hello World! qemu_x86

