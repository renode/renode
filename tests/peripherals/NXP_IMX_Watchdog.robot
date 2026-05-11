*** Variables ***
${PLATFORM}                         @platforms/boards/nxp-frdm-imx8mplus.repl
${BIN}                              @https://dl.antmicro.com/projects/renode/imx8mp_evk_mimx8ml8_a53-zephyr-wdt_basic_api.elf-s_1165208-b5c29f2cb5cb82096783abacc03b088a5a63a79e
${UART}                             sysbus.uart4

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 using sysbus.ca53Cluster

    Execute Command                 ca53Cluster ForEach IsHalted True
    Execute Command                 sysbus LoadSymbolsFrom ${BIN}
    ${reset_addr}=                  Execute Command  sysbus GetSymbolAddress "__start"

    ${reset_macro}=                 Catenate  SEPARATOR=${\n}
    ...                             """
    ...                             cpu0 PC ${reset_addr}
    ...                             cpu0 IsHalted False
    ...                             gic DisabledSecurity true
    ...                             gic AffinityRoutingEnabledSecure true
    ...                             gic AffinityRoutingEnabledNonSecure true
    ...                             """
    Execute Command                 macro reset${\n}${reset_macro}

    Execute Command                 sysbus LoadELF ${BIN}
    Execute Command                 runMacro $reset

*** Test Cases ***
Should Boot Zephyr Watchdog Sample
    Create Machine
    Create Terminal Tester          ${UART}

    Wait For Line On Uart           START - test_wdt

    Wait For Line On Uart           Testcase: test_wdt_no_callback
    Wait For Line On Uart           Waiting to restart MCU
    Wait For Line On Uart           Running TESTSUITE wdt_basic_test_suite
    Wait For Line On Uart           Testcase: test_wdt_no_callback
    Wait For Line On Uart           Testcase passed

    Wait For Line On Uart           Testcase: test_wdt_callback_1
    Wait For Line On Uart           Waiting to restart MCU
    Wait For Line On Uart           Running TESTSUITE wdt_basic_test_suite
    Wait For Line On Uart           Testcase: test_wdt_callback_1
    Wait For Line On Uart           Testcase passed

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL
