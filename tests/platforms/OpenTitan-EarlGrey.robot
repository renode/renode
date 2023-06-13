*** Comments ***
Tests for OpenTitan at commit f243e6802143374741739d2c164c4f2f61697669

*** Variables ***
${UART}                         sysbus.uart0
${AES_BIN}                      @https://dl.antmicro.com/projects/renode/aes_smoketest_prog_fpga_cw310.elf-s_325384-ef59f6e8ac7f56e8f3ee0f151652464a95023ad7
${CSRNG_BIN}                    @https://dl.antmicro.com/projects/renode/csrng_smoketest_prog_fpga_cw310.elf-s_336108-1a49396335efc0975ac5d4d99241028bb4711419
${FLASH_CTRL_BIN}               @https://dl.antmicro.com/projects/renode/flash_ctrl_test_prog_fpga_cw310.elf-s_424784-c8fa392bab21661e29224b2ee8678076502aa242
${GPIO_BIN}                     @https://dl.antmicro.com/projects/renode/gpio_smoketest_prog_fpga_cw310.elf-s_362872-de8f5853a07e44dd8ba55651d5293bd33f9b66d6
${HMAC_BIN}                     @https://dl.antmicro.com/projects/renode/hmac_smoketest_prog_fpga_cw310.elf-s_323008-274f6dd2f28ca66f6baa1be5304497c0ce7b6201
${KMAC_BIN}                     @https://dl.antmicro.com/projects/renode/kmac_smoketest_prog_fpga_cw310.elf-s_347412-b12dd1cc85f45d1e3256613441c41afe2ed127f0
${KMAC_CSHAKE_BIN}              @https://dl.antmicro.com/projects/renode/kmac_mode_cshake_test_prog_fpga_cw310.elf-s_334036-371c0b874622b5468d391bf76c2d4494a2621020
${KMAC_KMAC_BIN}                @https://dl.antmicro.com/projects/renode/kmac_mode_kmac_test_prog_fpga_cw310.elf-s_336072-7200324f9eb2f9feba7b3c9d0a99e8faaf0b118c
${LC_OTP_CFG}                   @https://dl.antmicro.com/projects/renode/lc_ctrl_otp_hw_cfg_test_prog_fpga_cw310.elf-s_351476-97168d00236be711f39cd24ec343b8ee593852ef
${OTP_VMEM}                     @https://dl.antmicro.com/projects/renode/otp_img_fpga_cw310.vmem-s_49520-971ccda1d11a9f0c690f4f32b72f1b5f3b458059
${RESET_BIN}                    @https://dl.antmicro.com/projects/renode/rstmgr_smoketest_prog_fpga_cw310.elf-s_288244-c3d023ac96dc447e626ead042e1d8337d5ceaee6
${SW_RESET_BIN}                 @https://dl.antmicro.com/projects/renode/rstmgr_sw_req_test_prog_fpga_cw310.elf-s_306308-2cc96fe5320d0c1b54153ddc6506e09d90133917
${TEST_ROM}                     @https://dl.antmicro.com/projects/renode/test_rom_fpga_cw310.elf-s_447072-1cdfd7b2a98b0c09f158d8267c5e9fbbf34dd33b
${TEST_ROM_SCR_VMEM}            @https://dl.antmicro.com/projects/renode/test_rom_fpga_cw310.39.scr.vmem-s_103772-d3a8f17879eedbcbf18e554bfd7871ccd992414e
${TIMER_BIN}                    @https://dl.antmicro.com/projects/renode/rv_timer_smoketest_prog_fpga_cw310.elf-s_310476-ace649750b26ef6ae36c099bf777fe280212ef21
${UART_BIN}                     @https://dl.antmicro.com/projects/renode/uart_smoketest_prog_fpga_cw310.elf-s_282560-87570a6fcb3684b126ef3c0ca9bfd53a0dc68936
${ALERT_HANDLER}                @https://dl.antmicro.com/projects/renode/alert_test_prog_fpga_cw310.elf-s_681764-d7203f6da5d986ce9a57d641ff1261a450a4c63d
${ALERT_HANDLER_PING}           @https://dl.antmicro.com/projects/renode/alert_handler_ping_timeout_test_prog_fpga_cw310.elf-s_484472-9abdc0b5e973cde8b9746d2e8ec8a997dbc8d0ba
${SPI_HOST}                     @https://dl.antmicro.com/projects/renode/spi_host_smoketest_prog_fpga_cw310.elf-s_321216-41ad0ca0446549371d07b4d8209ddfbc08c8be33
${AON_TIMER_IRQ_BIN}            @https://dl.antmicro.com/projects/renode/aon_timer_irq_test_prog_fpga_cw310.elf-s_388756-3411f90c38a58858140ae754bc06d7b6c2c2eff5
${AON_TIMER_WDOG_SLEEP_BIN}     @https://dl.antmicro.com/projects/renode/aon_timer_sleep_wdog_sleep_pause_test_prog_fpga_cw310.elf-s_373448-c0d65458130e457165e7575712a0ccb66ad27f80
${AON_TIMER_BIN}                @https://dl.antmicro.com/projects/renode/aon_timer_smoketest_prog_fpga_cw310.elf-s_317844-46f92ea7a8772be2afcf695e7fdb9df44216c852
${AON_TIMER_WDOG_BITE_BIN}      @https://dl.antmicro.com/projects/renode/aon_timer_wdog_bite_reset_test_prog_fpga_cw310.elf-s_371232-16ea5f84891ef4973add5fcf42b3e7fb9eb236d2
${ENTROPY_SRC_AST_REQ_BIN}      @https://dl.antmicro.com/projects/renode/entropy_src_ast_rng_req_test_prog_fpga_cw310.elf-s_322228-5d384e67d50472d80b8d66cf180ceb3b71e5ab15
${ENTROPY_SRC_FW_OVR_BIN}       @https://dl.antmicro.com/projects/renode/entropy_src_fw_ovr_test_prog_fpga_cw310.elf-s_347200-0e9636ca3c57e66a7a471143a0c48012d2c3753f
${ENTROPY_SRC_KAT_BIN}          @https://dl.antmicro.com/projects/renode/entropy_src_kat_test_prog_fpga_cw310.elf-s_391260-76d830cb1746909c033f1f8930cae428855b4b24
${SRAM_CTRL_BIN}                @https://dl.antmicro.com/projects/renode/sram_ctrl_smoketest_prog_fpga_cw310.elf-s_291188-63360ab9786db3a84da77b8766e458d119227dd5
${OTBN_ECDSA_BIN}               @https://dl.antmicro.com/projects/renode/otbn_ecdsa_op_irq_test_prog_fpga_cw310.elf-s_460328-d9b26904a2e79a6df89bda0d74c267351d839a2d
${OTBN_IRQ_BIN}                 @https://dl.antmicro.com/projects/renode/otbn_irq_test_prog_fpga_cw310.elf-s_445860-54133c6721deb5c0ac8713a06da7f93253276f7e
${OTBN_SCRAMBLE_BIN}            @https://dl.antmicro.com/projects/renode/otbn_mem_scramble_test_prog_fpga_cw310.elf-s_357976-17001e15e1ccc12075ff0bb108b0bc8fa0a96427
${OTBN_RAND_BIN}                @https://dl.antmicro.com/projects/renode/otbn_randomness_test_prog_fpga_cw310.elf-s_481904-c61657cd5db42f70c7814644b436405610850e33
${OTBN_SMOKETEST_BIN}           @https://dl.antmicro.com/projects/renode/otbn_smoketest_prog_fpga_cw310.elf-s_444776-8169ee20540f64f867206d17a18e8de5e6270f8e
${OTBN_RSA_BIN}                 @https://dl.antmicro.com/projects/renode/otbn_rsa_test_prog_fpga_cw310.elf-s_446140-6d6a4c0197d9fcc54c44cbe68db0003d7cb44783
${OTBN_SIMPLE_SMOKETEST_BIN}    @https://dl.antmicro.com/projects/renode/open_titan-earlgrey--otbn_simple_smoketest.elf-s_9164-5362a0be6d650280b2f732460e786a8d7263126b


${LEDS}=    SEPARATOR=
...  """                                     ${\n}
...  gpio:                                   ${\n}
...  ${SPACE*4}0 -> led0@0                   ${\n}
...  ${SPACE*4}1 -> led1@0                   ${\n}
...  ${SPACE*4}2 -> led2@0                   ${\n}
...  ${SPACE*4}3 -> led3@0                   ${\n}
...                                          ${\n}
...  led0: Miscellaneous.LED @ gpio 0        ${\n}
...  led1: Miscellaneous.LED @ gpio 1        ${\n}
...  led2: Miscellaneous.LED @ gpio 2        ${\n}
...  led3: Miscellaneous.LED @ gpio 3        ${\n}
...  """

${SPI_FLASH}=    SEPARATOR=
...  """                                     ${\n}
...  spi_flash: Memory.MappedMemory          ${\n}
...  ${SPACE*4}size: 0x1000000               ${\n}
...                                          ${\n}
...  mt25q: SPI.Micron_MT25Q @ spi_host0 0   ${\n}
...  ${SPACE*4}underlyingMemory: spi_flash   ${\n}
...  """

*** Keywords ***
Setup Machine
    Execute Command             include @scripts/single-node/opentitan-earlgrey.resc
    Execute Command             machine LoadPlatformDescriptionFromString ${LEDS}
    Execute Command             machine LoadPlatformDescriptionFromString ${SPI_FLASH}
    Execute Command             sysbus.otp_ctrl LoadVmem ${OTP_VMEM}
    Execute Command             rom_ctrl LoadVmem ${TEST_ROM_SCR_VMEM}
    Execute Command             cpu0 PC 0x00008084

    Set Default Uart Timeout    1
    Create Terminal Tester      ${UART}

Prepare Test
    [Arguments]                 ${bin}
    Execute Command             $bin=${bin}
    Execute Command             $boot=${TEST_ROM}
    Setup Machine

Execute Test
    Start Emulation
    Wait For Line On UART       PASS

Run Test
    [Arguments]                 ${bin}
    Prepare Test                ${bin}
    Execute Test

Core Register Should Be Equal
    [Arguments]                     ${idx}  ${expected_value}

    ${val}=  Execute Command        otbn GetCoreRegister ${idx}
    Should Be Equal As Numbers      ${val}  ${expected_value}   Register x${idx} value mismatch (actual != expected)

Wide Register Should Be Equal
    [Arguments]                     ${idx}  ${expected_value}

    ${val}=  Execute Command        otbn GetWideRegister ${idx} False
    Should Be Equal                 ${val.strip()}  ${expected_value}   Register w${idx} value mismatch (actual != expected)

*** Test Cases ***
Should Print To Uart
    Setup Machine
    Start Emulation

    Wait For Line On Uart       The LEDs show the lower nibble of the ASCII code of the last character.

    Provides                    initialization

Should Echo On Uart
    Requires                    initialization

    Write Line To Uart          Testing testing 1-2-3

    Provides                    working-uart

Should Display Output on GPIO
    Requires                    working-uart

    ${led0}=                    Create LED Tester  sysbus.gpio.led0  defaultTimeout=0.2
    ${led1}=                    Create LED Tester  sysbus.gpio.led1  defaultTimeout=0.2
    ${led2}=                    Create LED Tester  sysbus.gpio.led2  defaultTimeout=0.2
    ${led3}=                    Create LED Tester  sysbus.gpio.led3  defaultTimeout=0.2

    Send Key To Uart            0x0

    Assert LED State            false  testerId=${led0}
    Assert LED State            false  testerId=${led1}
    Assert LED State            false  testerId=${led2}
    Assert LED State            false  testerId=${led3}

    Write Char On Uart          B
    # B is 0100 0010. Take the lower 4 bits.

    Assert LED State            false  testerId=${led0}
    Assert LED State            true  testerId=${led1}
    Assert LED State            false  testerId=${led2}
    Assert LED State            false  testerId=${led3}

Should Pass AES Smoketest
    Run Test               ${AES_BIN}

Should Pass UART Smoketest
    Run Test               ${UART_BIN}

Should Pass HMAC Smoketest
    Run Test               ${HMAC_BIN}

Should Pass Flash Smoketest
    Run Test               ${FLASH_CTRL_BIN}

Should Pass Timer Smoketest
    Run Test               ${TIMER_BIN}

Should Pass KMAC Smoketest
    Run Test               ${KMAC_BIN}

Should Pass KMAC CSHAKE Mode
    Run Test               ${KMAC_CSHAKE_BIN}

Should Pass KMAC KMAC Mode
    Run Test               ${KMAC_KMAC_BIN}

Should Pass Reset Smoketest
    Run Test               ${RESET_BIN}

Should Pass Software Reset Test
    Run Test               ${SW_RESET_BIN}

Should Pass Life Cycle Smoketest
    Run Test               ${LC_OTP_CFG}

Should Pass CSRNG Smoketest
    Run Test               ${CSRNG_BIN}

Should Pass GPIO Smoketest
    Run Test               ${GPIO_BIN}

Should Pass Alert Handler Smoketest
    Run Test              ${ALERT_HANDLER}

Should Pass Alert Handler Ping Smoketest
    Run Test              ${ALERT_HANDLER_PING}

Should Pass SPI Host Smoketest
    Run Test              ${SPI_HOST}

Should Pass Aon Timer Interrupt Smoketest
    Run Test               ${AON_TIMER_IRQ_BIN}

Should Pass Aon Timer Watchdog Sleep Pause Smoketest
    Run Test               ${AON_TIMER_WDOG_SLEEP_BIN}

Should Pass Aon Timer Smoketest
    Run Test               ${AON_TIMER_BIN}

Should Pass Aon Timer Watchdog Bite Reset Smoketest
    Run Test               ${AON_TIMER_WDOG_BITE_BIN}

Should Try To Reset On The System Reset Control Combo
    Setup Machine
    Create Log Tester      0
    Execute Command        sysbus.sysrst_ctrl WriteDoubleWord 0x54 0x8   # Set combo0 to just pwrButton
    Execute Command        sysbus.sysrst_ctrl WriteDoubleWord 0x74 0x8   # Set combo0 action to rstReq
    Execute Command        sysbus.sysrst_ctrl WriteDoubleWord 0x30 0x40  # Invert the pwrButton input
    # Expect error as this should work only when done by CPU
    Wait For Log Entry     Couldn't find the CPU requesting translation block restart.
    Wait For Log Entry     Software reset failed.

Should Pass Entropy Source Analog Sensor Top Request Smoketest
    Run Test               ${ENTROPY_SRC_AST_REQ_BIN}

Should Pass Entropy Source Firmware Override Smoketest
    Run Test               ${ENTROPY_SRC_FW_OVR_BIN}

Should Pass Entropy Source Known Answer Test Smoketest
    Run Test               ${ENTROPY_SRC_KAT_BIN}

Should Pass SRAM Controller Smoketest
    Run Test               ${SRAM_CTRL_BIN}

Should Pass OTBN ECDSA Test
    Run Test            ${OTBN_ECDSA_BIN}

Should Pass OTBN IRQ Test
    Run Test              ${OTBN_IRQ_BIN}

Should Pass OTBN Memory Scramble Test
    Run Test              ${OTBN_SCRAMBLE_BIN}

Should Pass OTBN Randomness Test
    Run Test              ${OTBN_RAND_BIN}

Should Pass OTBN RSA Test
    Run Test              ${OTBN_RSA_BIN}

Should Pass OTBN Smoketest Test
    Run Test              ${OTBN_SMOKETEST_BIN}

Should Pass OTBN Simple Smoketest Test
    Create Log Tester               3
    Execute Command                 include @scripts/single-node/opentitan-earlgrey.resc
    Execute Command                 sysbus.otbn FixedRandomPattern "0xAAAAAAAA99999999AAAAAAAA99999999AAAAAAAA99999999AAAAAAAA99999999"

    Execute Command                 sysbus.otbn KeyShare0 "0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF"
    Execute Command                 sysbus.otbn KeyShare1 "0xBAADF00DBAADF00DBAADF00DBAADF00DBAADF00DBAADF00DBAADF00DBAADF00DBAADF00DBAADF00DBAADF00DBAADF00D"

    Execute Command                 logLevel -1 sysbus.otbn

    # load program directly to OTBN
    Execute Command                 sysbus.otbn LoadELF ${OTBN_SIMPLE_SMOKETEST_BIN}

    # trigger execution of the program
    Execute Command                 allowPrivates true
    Execute Command                 sysbus.otbn HandleCommand 0xd8

    # wait for the program to end
    Wait For Log Entry              Execution finished

    # verify final state of registers
    Core Register Should Be Equal   2   0xd0beb513
    Core Register Should Be Equal   3   0xa0be911a
    Core Register Should Be Equal   4   0x717d462d
    Core Register Should Be Equal   5   0xcfffdc07
    Core Register Should Be Equal   6   0xf0beb51b
    Core Register Should Be Equal   7   0x80be9112
    Core Register Should Be Equal   8   0x70002409
    Core Register Should Be Equal   9   0xd0beb533
    Core Register Should Be Equal   10  0x00000510
    Core Register Should Be Equal   11  0xd0beb169
    Core Register Should Be Equal   12  0xfad44c00
    Core Register Should Be Equal   13  0x000685f5
    Core Register Should Be Equal   14  0xffa17d6a
    Core Register Should Be Equal   15  0x4c000000
    Core Register Should Be Equal   16  0x00000034
    Core Register Should Be Equal   17  0xfffffff4
    Core Register Should Be Equal   18  0xfacefeed
    Core Register Should Be Equal   19  0xd0beb533
    Core Register Should Be Equal   20  0x00000123
    Core Register Should Be Equal   21  0x00000123
    Core Register Should Be Equal   22  0xcafef010
    Core Register Should Be Equal   23  0x89c9b54f
    Core Register Should Be Equal   24  0x00000052
    Core Register Should Be Equal   25  0x00000020
    Core Register Should Be Equal   26  0x00000016
    Core Register Should Be Equal   27  0x0000001a
    Core Register Should Be Equal   28  0x00400000
    Core Register Should Be Equal   29  0x00018000
    Core Register Should Be Equal   30  0x00000000
    Core Register Should Be Equal   31  0x00000804

    Wide Register Should Be Equal   0   0x37adadaef9dbff5e738800755466a52c67a8c2216978ad1b257694340f09b7c8
    Wide Register Should Be Equal   1   0x00000000000000000000000000000000baadf00dbaadf00dbaadf00dbaadf00d
    Wide Register Should Be Equal   2   0x440659a832f54897440659a832f54898dd6208a5cc50f794dd6208a5cc50f791
    Wide Register Should Be Equal   3   0x23a776b0bbc2837034745ffa22168ae87245a2d00357f208431165e5ed103473
    Wide Register Should Be Equal   4   0xce52215b888f503cdf1f0aa4eee357b51cf04d7ad024bed4edbc1090b9dd0141
    Wide Register Should Be Equal   5   0xfafeeeaebbb9f9dfabebbfef99fdf9dfefbafaaff9bfd9ffbaeebbbbdbff9bdb
    Wide Register Should Be Equal   6   0x28a88802000889908888a00a88189108828aa820099818088822aa2a11109898
    Wide Register Should Be Equal   7   0xd25666acbbb1704f23631fe511e568d76d30528ff027c1f732cc1191caef0343
    Wide Register Should Be Equal   8   0x870333f9ddd7162976364ab077830eb1386507da9641a791679944c4ac896525
    Wide Register Should Be Equal   9   0xd7c12b4df2c374c335d9da9bb4d6d555555554cccccccd55555554cccccccd55
    Wide Register Should Be Equal   10  0x050111511112d2ed5414401032ced2ed1045054fd30cf2cd45114443f0cd30f0
    Wide Register Should Be Equal   11  0xd75777fdccc4433c77775ff544b43bc47d7557dfc334b4c477dd55d5bbbc3433
    Wide Register Should Be Equal   12  0x2caccd53332aa9a2ccccb54aab1aa22ad2caad35299b1b2acd32ab2b22229a9a
    Wide Register Should Be Equal   13  0xa1a554085564a69a1252555a43c8b58a4a25a045a689a3aa2089656597ba66a7
    Wide Register Should Be Equal   14  0x5ec45f47d09a8aecac10254c2c59e4068dba5ca7630e74e6bcee99917956327a
    Wide Register Should Be Equal   15  0xdc58894eddd71629cb8ba00577830eb18dba5d2f9641a791bcee9a19ac896524
    Wide Register Should Be Equal   16  0xce52215b888f503cdf1f0aa4eee357b51cf04d7ad024bed4edbc1090b9dd0141
    Wide Register Should Be Equal   17  0x5555555533333333555555553333333355555555333333335555555533333331
    Wide Register Should Be Equal   18  0x23a7769fbbc2838134745fe922168a4ec79af82569be586e9866bb3b53769ada
    Wide Register Should Be Equal   19  0x28a88800000889828888a0098818910a828aa801099818000000000000000000
    Wide Register Should Be Equal   20  0x78fccc062228e9d689c9b54f887cf14ec79af82569be57c3edbc10a1b9dd0130
    Wide Register Should Be Equal   21  0x78fccc062228e9d689c9b54f887cf1eeefbafabdf9bfd9eebaeebbbbdbff9bfa
    Wide Register Should Be Equal   22  0x78fccc062228e9d689c9b54f887cf1eeefbafabdf9bfd9eebaeebbbbdbff9db7
    Wide Register Should Be Equal   23  0x78fccc062228e9d689c9b54f887cf1eeefbafabdf9bfd9eebaeebbbbdbff99f3
    Wide Register Should Be Equal   24  0xccccccccbbbbbbbbaaaaaaaafacefeeddeadbeefcafed00dd0beb5331234abcd
    Wide Register Should Be Equal   25  0xccccccccbbbbbbbbaaaaaaaafacefeeddeadbeefcafed00dd0beb5331234abcd
    Wide Register Should Be Equal   26  0x78fccc062228e9d689c9b54f887cf1eeefbafabdf9bfd9eebaeebbbbdbff9bfa
    Wide Register Should Be Equal   27  0x28a88802000889908888a00a88189108828aa820099818088822aa2a11109898
    Wide Register Should Be Equal   28  0xd25666acbbb1704f23631fe511e568d76d30528ff027c1f732cc1191caef0343
    Wide Register Should Be Equal   29  0x4f0d4b819f24f0c164341d3c26628bdb5763bcdf63388709e0654fefeb0953c2
    Wide Register Should Be Equal   30  0x2167f87de9ee7ac7ffa3d88bab123192aee492924efa2ec9b55098e068ba2fa1
    Wide Register Should Be Equal   31  0x37adadaef9dbff5e738800755466a52c67a8c2216978ad1b257694340f09b7c8

