*** Comments ***
Tests for OpenTitan at commit 1e86ba2a238dc26c2111d325ee7645b0e65058e5

*** Variables ***
${UART}                         sysbus.uart0
${URL}                          @https://dl.antmicro.com/projects/renode
${AES_BIN}                      ${URL}/open_titan-earlgrey--aes_smoketest_prog_fpga_cw310-s_239912-3506f84053745f5f37f35209531866ad9fa16228
${CSRNG_BIN}                    ${URL}/open_titan-earlgrey--csrng_smoketest_prog_fpga_cw310-s_232820-b81d41f67bebe52fba2042742eaf4e81c576ac22
${FLASH_CTRL_BIN}               ${URL}/open_titan-earlgrey--flash_ctrl_test_prog_fpga_cw310-s_328552-1354f2e7304a48b3ed84c270d301211cd32df71d
${GPIO_BIN}                     ${URL}/open_titan-earlgrey--gpio_smoketest_prog_fpga_cw310-s_214060-09246e86755f6f3e49e5210fc57cbce51f1789af
${HMAC_BIN}                     ${URL}/open_titan-earlgrey--hmac_smoketest_prog_fpga_cw310-s_248932-0243e4d66a15c6931b578bd4a81b862071bbe4c8
${KMAC_BIN}                     ${URL}/open_titan-earlgrey--kmac_smoketest_prog_fpga_cw310-s_257184-ae5908214fd1438d8b8ec5ad3e0cfe9c602a1a26
${KMAC_CSHAKE_BIN}              ${URL}/open_titan-earlgrey--kmac_mode_cshake_test_prog_fpga_cw310-s_243804-f61a86af163541e5bfc54ca81333691d6b08df70
${KMAC_KMAC_BIN}                ${URL}/open_titan-earlgrey--kmac_mode_kmac_test_prog_fpga_cw310-s_241792-8366dde2c380e0fe7636aa650e0396028a7d2c55
${LC_OTP_CFG}                   ${URL}/open_titan-earlgrey--lc_ctrl_otp_hw_cfg_test_prog_fpga_cw310-s_258160-70f63dede541716e44a1f7a55129c389c6cd4da3
${OTP_VMEM}                     ${URL}/open_titan-earlgrey--otp-img.24.vmem-s_44628-e17dede45d7e0509540343e52fe6fce1454c5339
${RESET_BIN}                    ${URL}/open_titan-earlgrey--rstmgr_smoketest_prog_fpga_cw310-s_204336-fc60c0258f0295d4357a3ee0c4031a49f846663b
${SW_RESET_BIN}                 ${URL}/open_titan-earlgrey--rstmgr_sw_req_test_prog_fpga_cw310-s_217432-d32e3a98fe09f6779787543c86d2d96ac08111cd
${TEST_ROM}                     ${URL}/open_titan-earlgrey--test_rom_fpga_cw310-s_388132-dab4120064720bf159b577e3cc416c460f6acac4
${TEST_ROM_SCR_VMEM}            ${URL}/open_titan-earlgrey--test_rom_fpga_cw310.scr.39.vmem-s_103772-f29ed3b389d4867ff6f8b6fb8d0d2dba9e505585
${TIMER_BIN}                    ${URL}/open_titan-earlgrey--rv_timer_smoketest_prog_fpga_cw310-s_223716-30dd409c881d36937e11280cdd08fc69beb805b6
${UART_BIN}                     ${URL}/open_titan-earlgrey--uart_smoketest_prog_fpga_cw310-s_191756-0189d97d3cb70d8b3fce74becf77f359a028f807
${ALERT_HANDLER}                ${URL}/open_titan-earlgrey--alert_test_prog_fpga_cw310-s_374976-f05e93d928220c226dbedf137f0da8b879ce023c
${ALERT_HANDLER_PING}           ${URL}/open_titan-earlgrey--alert_handler_ping_timeout_test_prog_fpga_cw310-s_378000-e43931d2c469fe986331931ad6abbe20bf10900a
${SPI_HOST}                     ${URL}/open_titan-earlgrey--spi_host_smoketest_prog_fpga_cw310-s_230244-b03d7d09dc842797261f0e790a68644b84bb8e35
${AON_TIMER_IRQ_BIN}            ${URL}/open_titan-earlgrey--aon_timer_irq_test_prog_fpga_cw310-s_305976-926ff9f281003a1f1460f6bc061419fb107cbbfb
${AON_TIMER_WDOG_SLEEP_BIN}     ${URL}/open_titan-earlgrey--aon_timer_sleep_wdog_sleep_pause_test_prog_fpga_cw310-s_279904-95929d5df5ba4fa6ea9a23d485c0b5d8679f488f
${AON_TIMER_BIN}                ${URL}/open_titan-earlgrey--aon_timer_smoketest_prog_fpga_cw310-s_227460-d7bc8e5a474bdee575ecb7b678cc9e2a76ad2382
${AON_TIMER_WDOG_BITE_BIN}      ${URL}/open_titan-earlgrey--aon_timer_wdog_bite_reset_test_prog_fpga_cw310-s_278528-6590a9d265d83137fb1821fa3d3c8d0444fa7cb6
${ENTROPY_SRC_AST_REQ_BIN}      ${URL}/open_titan-earlgrey--entropy_src_ast_rng_req_test_prog_fpga_cw310-s_223760-41abb796785237e76a0114d76d578d34fbeed0b4
${ENTROPY_SRC_FW_OVR_BIN}       ${URL}/open_titan-earlgrey--entropy_src_fw_ovr_test_prog_fpga_cw310-s_228724-297058e2f646201161ab762ffb3c789c9fe318f3
${ENTROPY_SRC_KAT_BIN}          ${URL}/open_titan-earlgrey--entropy_src_kat_test_prog_fpga_cw310-s_227200-5d1e4dc69a9991f4dd106249d599c8f0c59f5198
${SRAM_CTRL_BIN}                ${URL}/open_titan-earlgrey--sram_ctrl_smoketest_prog_fpga_cw310-s_201048-b0d2ad0e519756861521926f26f7aca0ba088470
${OTBN_ECDSA_BIN}               ${URL}/open_titan-earlgrey--otbn_ecdsa_op_irq_test_prog_fpga_cw310-s_375840-210c2433647cc21bf96477cf2eabc2cab76ebbff
${OTBN_IRQ_BIN}                 ${URL}/open_titan-earlgrey--otbn_irq_test_prog_fpga_cw310-s_348100-30dceef18bf2ac2cd9793e6b833ed9e66b305338
${OTBN_SCRAMBLE_BIN}            ${URL}/open_titan-earlgrey--otbn_mem_scramble_test_prog_fpga_cw310-s_245136-7caf31999f17c5ccf5f69c7023b639cbda1b0acd
${OTBN_RAND_BIN}                ${URL}/open_titan-earlgrey--otbn_randomness_test_prog_fpga_cw310-s_382412-af2e53e5aa15fcdbccdbd02e7743b9b9a7e6c4ed
${OTBN_SMOKETEST_BIN}           ${URL}/open_titan-earlgrey--otbn_smoketest_prog_fpga_cw310-s_324520-4bab1e9ac4a35a6ab9c27df407aad8e9a68ace94
${OTBN_RSA_BIN}                 ${URL}/open_titan-earlgrey--otbn_rsa_test_prog_fpga_cw310-s_329844-075a4b23640dba0a2e34c030b65c79b553a70942
# this binary is built from https://github.com/lowRISC/opentitan/blob/1e86ba2a238dc26c2111d325ee7645/hw/ip/otbn/dv/smoke/smoke_test.s
${OTBN_SIMPLE_SMOKETEST_BIN}    ${URL}/open_titan-earlgrey--otbn_simple_smoketest.elf-s_9180-eafc18be3506e30cc6c255942156b35e4cbda0d9

${LEDS}=    SEPARATOR=
...  """                                     ${\n}
...  gpio:                                   ${\n}
...  ${SPACE*4}8 -> led0@0                   ${\n}
...  ${SPACE*4}9 -> led1@0                   ${\n}
...  ${SPACE*4}10 -> led2@0                  ${\n}
...  ${SPACE*4}11 -> led3@0                  ${\n}
...  ${SPACE*4}12 -> led4@0                  ${\n}
...  ${SPACE*4}13 -> led5@0                  ${\n}
...  ${SPACE*4}14 -> led6@0                  ${\n}
...  ${SPACE*4}15 -> led7@0                  ${\n}
...                                          ${\n}
...  led0: Miscellaneous.LED @ gpio 8        ${\n}
...  led1: Miscellaneous.LED @ gpio 9        ${\n}
...  led2: Miscellaneous.LED @ gpio 10       ${\n}
...  led3: Miscellaneous.LED @ gpio 11       ${\n}
...  led4: Miscellaneous.LED @ gpio 12       ${\n}
...  led5: Miscellaneous.LED @ gpio 13       ${\n}
...  led6: Miscellaneous.LED @ gpio 14       ${\n}
...  led7: Miscellaneous.LED @ gpio 15       ${\n}
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
    Execute Command             $bool=${TEST_ROM}
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

    Wait For Line On Uart       The LEDs show the ASCII code of the last character.

    Provides                    initialization

Should Echo On Uart
    Requires                    initialization

    Write Line To Uart          Testing testing 1-2-3

    Provides                    working-uart

# This test is currently broken as the GPIO is misconfigured.
# Output pins are configured to 0x00FF: https://github.com/lowRISC/opentitan/blob/1e86ba2a238dc26c2111d325ee7645b0e65058e5/sw/device/examples/hello_world/hello_world.c#L66 ,
# while chars are outputed to 0xFF00: https://github.com/lowRISC/opentitan/blob/1e86ba2a238dc26c2111d325ee7645b0e65058e5/sw/device/examples/demos.c#L88
Should Display Output on GPIO
    [Tags]                      skipped
    Requires                    working-uart

    Execute Command             emulation CreateLEDTester "led0" sysbus.gpio.led0
    Execute Command             emulation CreateLEDTester "led1" sysbus.gpio.led1
    Execute Command             emulation CreateLEDTester "led2" sysbus.gpio.led2
    Execute Command             emulation CreateLEDTester "led3" sysbus.gpio.led3

    Execute Command             emulation CreateLEDTester "led4" sysbus.gpio.led4
    Execute Command             emulation CreateLEDTester "led5" sysbus.gpio.led5
    Execute Command             emulation CreateLEDTester "led6" sysbus.gpio.led6
    Execute Command             emulation CreateLEDTester "led7" sysbus.gpio.led7

    Send Key To Uart            0x0

    Execute Command             led0 AssertState false 0.2
    Execute Command             led1 AssertState false 0.2
    Execute Command             led2 AssertState false 0.2
    Execute Command             led3 AssertState false 0.2

    Execute Command             led4 AssertState false 0.2
    Execute Command             led5 AssertState false 0.2
    Execute Command             led6 AssertState false 0.2
    Execute Command             led7 AssertState false 0.2

    Write Char On Uart          B
    # B is 0100 0010

    Execute Command             led0 AssertState false 0.2
    Execute Command             led1 AssertState true 0.2
    Execute Command             led2 AssertState false 0.2
    Execute Command             led3 AssertState false 0.2

    Execute Command             led4 AssertState false 0.2
    Execute Command             led5 AssertState false 0.2
    Execute Command             led6 AssertState true 0.2
    Execute Command             led7 AssertState false 0.2

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
    Wait For Log Entry     Couldn't find the cpu requesting reset.

Should Pass Entropy Source Analog Sensor Top Request Smoketest
    Run Test               ${ENTROPY_SRC_AST_REQ_BIN}

Should Pass Entropy Source Firmware Override Smoketest
    Run Test               ${ENTROPY_SRC_FW_OVR_BIN}

Should Pass Entropy Source Known Answer Test Smoketest
    Run Test               ${ENTROPY_SRC_KAT_BIN}

Should Pass SRAM Controller Smoketest
    Run Test               ${SRAM_CTRL_BIN}

Should Pass OTBN ECDSA Test
    Prepare Test            ${OTBN_ECDSA_BIN}
    Execute Test

Should Pass OTBN IRQ Test
    Run Test              ${OTBN_IRQ_BIN}

Should Pass OTBN Memory Scramble Test
    Prepare Test          ${OTBN_SCRAMBLE_BIN}
    Execute Command       cpu0 MaximumBlockSize 1
    Execute Test

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

