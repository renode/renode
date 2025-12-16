*** Variables ***
${ZEPHYR_GPIO_BASIC_API}            @https://dl.antmicro.com/projects/renode/zephyr-egis_et171-gpio_basic_api.elf-s_770540-61ca41b5bc34583da1f480143d3d6186712f9d24

${GPIO_TEST_PLATFORM}               SEPARATOR=\n
...                                 """
...                                 using "platforms/cpus/egis_et171.repl"
...                                 gpio0:
...                                 ${SPACE*4}4 -> gpio0@5
...                                 """


*** Test Cases ***
Should Pass Zephyr GPIO Basic API test
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${GPIO_TEST_PLATFORM}
    Create Terminal Tester          sysbus.uart0  defaultPauseEmulation=True  timeout=25

    Execute Command                 sysbus LoadELF ${ZEPHYR_GPIO_BASIC_API}

    Wait For Line On Uart           SUITE PASS - 100.00% [after_flash_gpio_config_trigger]
    Wait For Line On Uart           SUITE PASS - 100.00% [gpio_port]
    Wait For Line On Uart           SUITE PASS - 100.00% [gpio_port_cb_mgmt]
    Wait For Line On Uart           SUITE PASS - 100.00% [gpio_port_cb_vari]
