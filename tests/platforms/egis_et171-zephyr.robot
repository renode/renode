*** Variables ***
${SCRIPT_PATH}                      @scripts/single-node/egis_et171_zephyr.resc
${UART}                             sysbus.uart0
${SHELL_MODULE_BIN}                 @https://dl.antmicro.com/projects/renode/zephyr-egis_et171-shell_module.elf-s_1482184-28d8276402948a403d1037214b76a2115d1b2882
${WATCHDOG_TEST_BIN}                @https://dl.antmicro.com/projects/renode/zephyr-egis_et171-test-wdt_basic_api.elf-s_701188-8b2b1a4e8ddf538d9a3af87b089aea4ab0c0a01f
${SPI_LOOP_TEST_BIN}                @https://dl.antmicro.com/projects/renode/zephyr-egis_et171-test-spi_loopback.elf-s_930548-d640a4991793e6db6bce125681567fe1dc6bb0ba

${SPI_LOOP_REPL}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/egis_et171.repl"  ${\n}
...                                          ${\n}
...  spiLoopback: SPI.SPILoopback @ spi1     ${\n}
...  """

*** Keywords ***
Create Machine With Binary ${binary}
    Execute Command                 $bin=${binary}
    Execute Command                 include ${SCRIPT_PATH}

    Create Terminal Tester          ${UART}  timeout=0.3  defaultPauseEmulation=true

    Execute Command                 logLevel 0 watchdog

Create Custom Machine ${binary} ${description}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${description}
    Execute Command                 sysbus LoadELF ${binary}

    Create Terminal Tester          ${UART}  timeout=0.3  defaultPauseEmulation=true

*** Test Cases ***
Should Print Board Name In Shell
    Create Machine With Binary ${SHELL_MODULE_BIN}

    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              demo board

    Wait For Line On Uart           egis_et171

Should Pass Watchdog Test
    Create Machine With Binary ${WATCHDOG_TEST_BIN}

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass SPI Loopback Test
    Create Custom Machine ${SPI_LOOP_TEST_BIN} ${SPI_LOOP_REPL}

    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL
