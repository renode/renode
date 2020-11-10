*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

${NO_DMA}=  SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...  uart0:                                  ${\n}
...  ${SPACE*4}easyDMA: false                ${\n}
...  uart1:                                  ${\n}
...  ${SPACE*4}easyDMA: false                ${\n}
...  """

${DMA}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...  uart0:                                  ${\n}
...  ${SPACE*4}easyDMA: true                 ${\n}
...  uart1:                                  ${\n}
...  ${SPACE*4}easyDMA: true                 ${\n}
...  """

*** Keywords ***
Create Machine
    [Arguments]              ${platform}  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString ${platform}

    Execute Command          sysbus LoadELF ${URI}/${elf}

Run ZephyrRTOS Shell
    [Arguments]               ${platform}  ${elf}

    Create Machine            ${platform}  ${elf}
    Create Terminal Tester    ${UART}

    Execute Command           showAnalyzer ${UART}

    Start Emulation
    Wait For Prompt On Uart   uart:~$
    Write Line To Uart        demo ping
    Wait For Line On Uart     pong

*** Test Cases ***
Should Run ZephyrRTOS Shell On UART
    Run ZephyrRTOS Shell      ${NO_DMA}  zephyr_shell_nrf52840.elf-s_1110556-9653ab7fffe1427c50fa6b837e55edab38925681

Should Run ZephyrRTOS Shell On UARTE
    Run ZephyrRTOS Shell      ${DMA}     renode-nrf52840-zephyr_shell_module.elf-gf8d05cf-s_1310072-c00fbffd6b65c6238877c4fe52e8228c2a38bf1f


Should Run Alarm Sample
    Create Machine            ${NO_DMA}  zephyr_alarm_nRF52840.elf-s_489392-49a2ec3fda2f0337fe72521f08e51ecb0fd8d616
    Create Terminal Tester    ${UART}

    Execute Command           showAnalyzer ${UART}

    Start Emulation

    Wait For Line On Uart     !!! Alarm !!!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:02

    Wait For Line On Uart     !!! Alarm !!!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:06

