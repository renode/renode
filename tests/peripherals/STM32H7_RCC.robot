*** Variables ***
${PROJECT_URL}                      https://dl.antmicro.com/projects/renode
${CSI_4}                            ${PROJECT_URL}/nucleo_h753zi--zephyr-tests_clock_configuration_sysclksrc_csi_4.elf-s_918288-6cbb2424c3ccc8d9c6bc61aa00428cd140202e65
${HSE_8}                            ${PROJECT_URL}/nucleo_h753zi--zephyr-tests_clock_configuration_sysclksrc_hse_8.elf-s_920112-ea1713ae733875464cd9904efa928e1b51a95771
${HSE_8_CSS}                        ${PROJECT_URL}/nucleo_h753zi--zephyr-tests_clock_configuration_sysclksrc_hse_8_css.elf-s_921784-01cf613349a4e4b6bcb40e145ce396017b4bb2d0
${HSI_64}                           ${PROJECT_URL}/nucleo_h753zi--zephyr-tests_clock_configuration_sysclksrc_hsi_64.elf-s_920708-6c956bc33a8101943b2b32484b29cd0502e3120e
${PLL_CSI_96}                       ${PROJECT_URL}/nucleo_h753zi--zephyr-tests_clock_configuration_sysclksrc_pll_csi_96.elf-s_922884-cfefb1c0aa8bdce3289891d6ec216ef1d082b3ff
${PLL_HSE_96}                       ${PROJECT_URL}/nucleo_h753zi--zephyr-tests_clock_configuration_sysclksrc_pll_hse_96.elf-s_924744-603d48ba2b5856903d77d16ef39b8af64130ba22
${PLL_HSI_96}                       ${PROJECT_URL}/nucleo_h753zi--zephyr-tests_clock_configuration_sysclksrc_pll_hsi_96.elf-s_923636-36f26b10dfdb6d566ebf3d8a53344397c5eb3e1e
${PLATFORM}                         platforms/boards/nucleo_h753zi.repl
${UART}                             sysbus.usart3

*** Keywords ***
Create Machine
    [Arguments]                     ${binary}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/stm32h743.repl
    Execute Command                 sysbus LoadELF @${binary}

Create Simple Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/stm32h743.repl

*** Test Cases ***
Should Pass Zephyr stm32_clock_configuration/stm32h7_core Test Suite With CSI 4
    Create Machine                  ${CSI_4}
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr stm32_clock_configuration/stm32h7_core Test Suite With HSE 8
    Create Machine                  ${HSE_8}
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr stm32_clock_configuration/stm32h7_core Test Suite With HSE 8 CSS
    Create Machine                  ${HSE_8_CSS}
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr stm32_clock_configuration/stm32h7_core Test Suite With HSI 64
    Create Machine                  ${HSI_64}
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr stm32_clock_configuration/stm32h7_core Test Suite With PLL CSI 96
    Create Machine                  ${PLL_CSI_96}
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr stm32_clock_configuration/stm32h7_core Test Suite With PLL HSE 96
    Create Machine                  ${PLL_HSE_96}
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr stm32_clock_configuration/stm32h7_core Test Suite With PLL HSI 96
    Create Machine                  ${PLL_HSI_96}
    Create Terminal Tester          ${UART}
    Wait For Line On Uart           PROJECT EXECUTION SUCCESSFUL

Should Reset Peripheral
    Create Simple Machine
    Create Log Tester               1
    Execute Command                 logLevel 0
    Execute Command                 sysbus LogPeripheralAccess rcc
    Execute Command                 rcc WriteDoubleWord 0x98 0x1
    Wait For Log Entry              Resetting TIM1     timeout=2

Should Enable And Disable Peripheral
    Create Simple Machine
    ${is_enabled}=                  Execute Command  sysbus IsPeripheralEnabled timer1
    Should Be True                  ${is_enabled}

    Execute Command                 rcc WriteDoubleWord 0xF0 0xFFFFFFFE
    ${is_enabled}=                  Execute Command  sysbus IsPeripheralEnabled timer1
    Should Be True                  (${is_enabled}) == 0

    Execute Command                 rcc WriteDoubleWord 0xF0 0x1
    ${is_enabled}=                  Execute Command  sysbus IsPeripheralEnabled timer1
    Should Be True                  ${is_enabled}
