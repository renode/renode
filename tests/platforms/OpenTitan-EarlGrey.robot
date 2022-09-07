*** Comments ***
Tests for OpenTitan at commit 1e86ba2a238dc26c2111d325ee7645b0e65058e5
*** Settings ***
Suite Setup                     Setup
Suite Teardown                  Teardown
Test Setup                      Reset Emulation
Test Teardown                   Test Teardown
Resource                        ${RENODEKEYWORDS}

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

*** Keywords ***
Setup Machine
    Execute Command             include @scripts/single-node/opentitan-earlgrey.resc
    Execute Command             machine LoadPlatformDescriptionFromString ${LEDS}
    Execute Command             sysbus.otp_ctrl LoadVmem ${OTP_VMEM}
    Execute Command             rom_ctrl LoadVmem ${TEST_ROM_SCR_VMEM}
    Execute Command             cpu0 PC 0x00008084

    Set Default Uart Timeout    1
    Create Terminal Tester      ${UART}

Run Test
    [Arguments]                 ${bin}
    Execute Command             $bin=${bin}
    Execute Command             $bool=${TEST_ROM}
    Setup Machine
    Start Emulation

    Wait For Line On UART       PASS

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
