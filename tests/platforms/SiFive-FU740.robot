*** Variables ***
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/hifive_unmatched.resc
${SCRIPT_SD_CARD}             ${CURDIR}/../../scripts/single-node/hifive_unmatched_sdcard.resc
${UART}                       sysbus.uart0
${TEST_BIN}                   @https://dl.antmicro.com/projects/renode/hifive_unmatched--zephyr-tests_subsys_fs_ext2_sdcard.elf-s_1780608-7de521cb3ea27c869f0359cd6ef4a84138a16a9b

*** Test Cases ***
Should List Directory Entries
    [Documentation]           Boots Zephyr fs sample on SiFive Freedom U740 platform.

    Execute Script            ${SCRIPT_SD_CARD}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     Listing dir /ext ...
    Wait For Line On Uart     [DIR ] lost+found
    Wait For Line On Uart     [FILE] hello (size = 4)
    Wait For Line On Uart     [DIR ] world

Should Run Zephyr Fs Test
    [Documentation]           Runs Zephyr fs tests on SiFive Freedom U740 platform.

    Execute Command           $bin=${TEST_BIN}
    Execute Script            ${SCRIPT}
    Execute Command           machine EmptySdCard sysbus.qspi2 0 0x20000 "sd" 
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     TESTSUITE ext2tests succeeded

