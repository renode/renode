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
${AES_BIN}                      ${URL}/open_titan-earlgrey--aes_smoketest_prog_fpga_cw310.elf-s_233880-672047d2d70823d371047235e5cb583ff085dd25
${CSRNG_BIN}                    ${URL}/open_titan-earlgrey--csrng_smoketest_prog_fpga_cw310.elf-s_228852-021bfba38094e461409eaa49712a7bcfbb2afb3a
${FLASH_CTRL_BIN}               ${URL}/open_titan-earlgrey--flash_ctrl_test_prog_fpga_cw310.elf-s_322896-9035eb9fb3c7d9481ce9eea1f1cb135cfe42d664
${GPIO_BIN}                     ${URL}/open_titan-earlgrey--gpio_smoketest_prog_fpga_cw310.elf-s_208428-be957af5f6649b9b669f464972f3bcb43c31c39d
${HMAC_BIN}                     ${URL}/open_titan-earlgrey--hmac_smoketest_prog_fpga_cw310.elf-s_242548-ddc819c8d575de209826fdfdcb9f3264288df870
${KMAC_BIN}                     ${URL}/open_titan-earlgrey--kmac_smoketest_prog_fpga_cw310.elf-s_249568-ab3eaf65a6399d112bd2ea3e8bed330102879bc5
${KMAC_CSHAKE_BIN}              ${URL}/open_titan-earlgrey--kmac_mode_cshake_test_prog_fpga_cw310.elf-s_236788-6a524618d49a81e5739457b87e6b443c99e11ced
${KMAC_KMAC_BIN}                ${URL}/open_titan-earlgrey--kmac_mode_kmac_test_prog_fpga_cw310.elf-s_237320-4e70346ed8860d934d426721271c94363c076a24
${LC_OTP_CFG}                   ${URL}/open_titan-earlgrey--lc_ctrl_otp_hw_cfg_test_prog_fpga_cw310.elf-s_254312-6613af5fc5ed9e8be5f38d1446d11bacb99e8b4f
${OTP_VMEM}                     ${URL}/open_titan-earlgrey--otp-img.24.vmem-s_44628-e17dede45d7e0509540343e52fe6fce1454c5339
${RESET_BIN}                    ${URL}/open_titan-earlgrey--rstmgr_smoketest_prog_fpga_cw310.elf-s_198176-3c438b9e1c074bb08afe188db29e8beac1fd72af
${SW_RESET_BIN}                 ${URL}/open_titan-earlgrey--rstmgr_sw_req_test_prog_fpga_cw310.elf-s_211576-c6e862c60f11b2f121d4f9396f79c65d7320028b
${TEST_ROM}                     ${URL}/open_titan-earlgrey--test_rom_fpga_cw310.elf-s_377516-685e95a3d1b9e190f6538a3f60d99f95cce5aa70
${TEST_ROM_SCR_VMEM}            ${URL}/open_titan-earlgrey--test_rom_fpga_cw310.scr.39.vmem-s_103772-d4cc5690aaf9072e5e1df0ac8f656947ce82064b
${TIMER_BIN}                    ${URL}/open_titan-earlgrey--rv_timer_smoketest_prog_fpga_cw310.elf-s_216444-a25e86fd436ce2f31e4db677400f3a933f09624d
${UART_BIN}                     ${URL}/open_titan-earlgrey--uart_smoketest_prog_fpga_cw310.elf-s_186516-b5f11e2b9112f9857fe47518c2a812c2cedc1f8b
${ALERT_HANDLER}                ${URL}/open_titan-earlgrey--alert_test_prog_fpga_cw310.elf-s_369840-399ce38d67f780df3e7624b01c217dfac1641c0e
${ALERT_HANDLER_PING}           ${URL}/open_titan-earlgrey--alert_handler_ping_timeout_test_prog_fpga_cw310.elf-s_372064-5e6b4ee5a3f8f10656d18970bde37aad6f494732

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
