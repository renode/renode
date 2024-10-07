*** Variables ***
${UART}                       sysbus.uart0
${SCRIPT_UBOOT}               @scripts/single-node/fsl_lx2160ardb_uboot.resc

*** Test Cases ***
Should Run U-Boot
    Execute Command           include ${SCRIPT_UBOOT}
    Create Terminal Tester    ${UART}
    Wait For Line On Uart     Hit any key to stop autoboot:${SPACE}${SPACE}2
