*** Settings ***
Suite Setup                     Setup
Suite Teardown                  Teardown
Test Setup                      Reset Emulation
Test Teardown                   Test Teardown
Resource                        ${RENODEKEYWORDS}

*** Variables ***
${UART}                         sysbus.uart0
${URL}                          @https://dl.antmicro.com/projects/renode
${AES_BIN}                      ${URL}/open_titan-earlgrey--aes_smoketest_nexysvideo.elf-s_207660-1fb62c51b483c11563ef2796e11e3d03e9382ee6
${UART_BIN}                     ${URL}/open_titan-earlgrey--uart_smoketest_nexysvideo.elf-s_121984-63522893fc29a7f1ff84c46eddaa0f6d7113b492
${HMAC_BIN}                     ${URL}/open_titan-earlgrey--hmac_smoketest_nexysvideo.elf-s_171588-dcdba7d2a7d94596eda5ede6d63985a2893678c9
${KMAC_BIN}                     ${URL}/open_titan-earlgrey--kmac_smoketest_fpga_nexysvideo.elf-s_171004-89e9cbda1b8747a33b3b9063c2796c39d544d84d
${KMAC_CSHAKE_BIN}              ${URL}/open_titan-earlgrey--kmac_mode_cshake_test_fpga_nexysvideo.elf-s_172064-53522273c3ba99942ffa8314f27f3441fed4a6bb
${KMAC_KMAC_BIN}                ${URL}/open_titan-earlgrey--kmac_mode_kmac_test_fpga_nexysvideo.elf-s_170660-1885b754ffe20df3bb5fd4421a0169a4ec08c1b2
${FLASH_CTRL_BIN}               ${URL}/open_titan-earlgrey--flash_ctrl_test_nexysvideo.elf-s_158084-30b89ad8c33a73c5e1b169f3a5681a1447fe9210
${BOOT_ROM_SCR_VMEM}            ${URL}/open_titan-earlgrey--boot_rom_fpga_nexysvideo.scr.39.vmem-s_103772-a1083d2181af6fd00fe8a7fd45e918420d54e9a4
${TIMER_BIN}                    ${URL}/open_titan-earlgrey--rv_timer_smoketest_fpga_nexysvideo.elf-s_168792-0dc77e4f0beab190acd0660e6fe32e8193b0fa79
${RESET_BIN}                    ${URL}/open_titan-earlgrey--rstmgr_smoketest_fpga_nexysvideo.elf-s_130232-622f82a8b22083c29c38abed25985e427bbaf83a
${SW_RESET_BIN}                 ${URL}/open_titan-earlgrey--rstmgr_sw_req_test_fpga_nexysvideo.elf-s_133012-6ce97eafa18abb7c81e1c0a1c552938435daf2ab
# To be added from: https://dev.antmicro.com/git/repositories/shodan--opentitan-renode/-/jobs/222852/artifacts/browse/upload/
${OTP_VMEM}                     ${URL}/open_titan-earlgrey--otp-img.vmem-s_44772-4e36b9e345c26e52ab8bf9095cf361c1e458d2d5
${LC_TRANSITION}                ${URL}/open_titan-earlgrey--lc_ctrl_transition_test_fpga_nexysvideo.elf-s_133300-11da0308c7b4a356043cbef482245612e0c8e0c9
${LC_OTP_CFG}                   ${URL}/open_titan-earlgrey--lc_ctrl_otp_hw_cfg_test_fpga_nexysvideo.elf-s_175696-13ae2bce6f776ea36cef183b4387e0f3ed728560

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
    Execute Command             sysbus.otp_ctrl LoadVMem ${OTP_VMEM}

    Set Default Uart Timeout    1
    Create Terminal Tester      ${UART}

Setup Machine Without Boot ROM
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescription @platforms/cpus/opentitan-earlgrey.repl
    Execute Command             machine LoadPlatformDescriptionFromString ${LEDS}
    Execute Command             sysbus LoadELF $bin

    Create Terminal Tester      ${UART}
    Set Default Uart Timeout    1

Load Scrambled Boot ROM Vmem
    Execute Command             rom_ctrl LoadVmem ${BOOT_ROM_SCR_VMEM}
    Execute Command             cpu0 PC 0x00008084

Run Smoketest
    [Arguments]                 ${bin}
    Execute Command             $bin=${bin}
    Setup Machine
    Start Emulation

    Wait For Line On UART       PASS

Run Smoketest With Scrambled Boot ROM Binary
    [Arguments]                 ${bin}
    Execute Command             $bin=${bin}
    Setup Machine Without Boot ROM
    Load Scrambled Boot ROM Binary
    Start Emulation

    Wait For Line On UART       PASS

Run Smoketest With Scrambled Boot ROM Vmem
    [Arguments]                 ${bin}
    Execute Command             $bin=${bin}
    Setup Machine Without Boot ROM
    Load Scrambled Boot ROM Vmem
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

Should Display Output on GPIO
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
    Run Smoketest               ${AES_BIN}

Should Pass UART Smoketest
    Run Smoketest               ${UART_BIN}

Should Pass HMAC Smoketest
    Run Smoketest               ${HMAC_BIN}

Should Pass Flash Smoketest
    Run Smoketest               ${FLASH_CTRL_BIN}

Should Pass Timer Smoketest
    Run Smoketest               ${TIMER_BIN}

Should Pass KMAC Smoketest
    Run Smoketest               ${KMAC_BIN}

Should Pass KMAC CSHAKE Mode
    Run Smoketest               ${KMAC_CSHAKE_BIN}

Should Pass KMAC KMAC Mode
    Run Smoketest               ${KMAC_KMAC_BIN}

Should Pass Reset Smoketest
    Run Smoketest               ${RESET_BIN}

Should Pass Software Reset Test
    Run Smoketest               ${SW_RESET_BIN}

Should Pass Life Cycle Transition Test
    Run Smoketest               ${LC_TRANSITION}

Should Pass Life Cycle Otp Config Test
    Run Smoketest               ${LC_OTP_CFG}

Should Pass AES Smoketest With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${AES_BIN}

Should Pass UART Smoketest With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${UART_BIN}

Should Pass HMAC Smoketest With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${HMAC_BIN}

Should Pass Flash Smoketest With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${FLASH_CTRL_BIN}

Should Pass KMAC Smoketest With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${KMAC_BIN}

Should Pass KMAC CSHAKE Mode With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${KMAC_CSHAKE_BIN}

Should Pass KMAC KMAC Mode With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${KMAC_KMAC_BIN}

Should Pass Reset Smoketest With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${RESET_BIN}

Should Pass Software Reset Test With Scrambled Boot ROM Vmem
    Run Smoketest With Scrambled Boot ROM Vmem      ${SW_RESET_BIN}
