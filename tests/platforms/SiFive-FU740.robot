*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/hifive_unmatched_sdcard.resc
${UART}                       sysbus.uart0

*** Test Cases ***
Should List Directory Entries
    [Documentation]           Boots Zephyr fs sample on SiFive Freedom U740 platform.

    Execute Script            ${SCRIPT}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     Listing dir /ext ...
    Wait For Line On Uart     [DIR ] lost+found
    Wait For Line On Uart     [FILE] hello (size = 4)
    Wait For Line On Uart     [DIR ] world
