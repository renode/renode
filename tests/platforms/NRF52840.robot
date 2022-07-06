*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

${STANDARD}=  SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...  """

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

${ADXL_SPI}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...                                          ${\n}
...  adxl372: Sensors.ADXL372 @ spi2         ${\n}
...                                          ${\n}
...  gpio0:                                  ${\n}
...  ${SPACE*4}22 -> adxl372@0 // CS         ${\n}
...  """

${ADXL_I2C}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...                                          ${\n}
...  adxl372: Sensors.ADXL372 @ twi1 0x11    ${\n}
...  """

${BUTTON_LED}=     SEPARATOR=
...  """                                     ${\n}
...  using "platforms/cpus/nrf52840.repl"    ${\n}
...                                          ${\n}
...  gpio0:                                  ${\n}
...  ${SPACE*4}13 -> led@0                   ${\n}
...                                          ${\n}
...  button: Miscellaneous.Button @ gpio0 11 ${\n} 
...  ${SPACE*4}invert: true                  ${\n}
...  ${SPACE*4}-> gpio0@11                   ${\n}
...                                          ${\n}
...  led: Miscellaneous.LED @ gpio0 13       ${\n}
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
    [Tags]   skipped
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

Should Handle LED and Button
    Create Machine            ${BUTTON_LED}  nrf52840--zephyr_button.elf-s_660440-50c3b674193c8105624dae389420904e2036f9c0
    Create Terminal Tester    ${UART}

    Execute Command           emulation CreateLEDTester "lt" sysbus.gpio0.led

    Start Emulation
    Wait For Line On Uart     Booting Zephyr OS
    Wait For Line On Uart     Press the button

    Execute Command           lt AssertState True 0
    Execute Command           sysbus.gpio0.button Press
    Sleep           1s
    Execute Command           lt AssertState False 0
    Execute Command           sysbus.gpio0.button Release
    Sleep           1s
    # TODO: those sleeps shouldn't be necessary!
    Execute Command           lt AssertState True 0

Should Handle SPI
    Create Machine            ${ADXL_SPI}  nrf52840--zephyr_adxl372_spi.elf-s_993780-1dedb945dae92c07f1b4d955719bfb1f1e604173
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.spi2.adxl372 AccelerationX 0
    Execute Command           sysbus.spi2.adxl372 AccelerationY 0
    Execute Command           sysbus.spi2.adxl372 AccelerationZ 0 

    Start Emulation
    Wait For Line On Uart     Booting Zephyr OS
    Wait For Line On Uart     0.00 g

    Execute Command           sysbus.spi2.adxl372 AccelerationX 1
    Execute Command           sysbus.spi2.adxl372 AccelerationY 0
    Execute Command           sysbus.spi2.adxl372 AccelerationZ 0 

    Wait For Line On Uart     1.00 g

    Execute Command           sysbus.spi2.adxl372 AccelerationX 2
    Execute Command           sysbus.spi2.adxl372 AccelerationY 2
    Execute Command           sysbus.spi2.adxl372 AccelerationZ 0 

    Wait For Line On Uart     2.83 g

    Execute Command           sysbus.spi2.adxl372 AccelerationX 3
    Execute Command           sysbus.spi2.adxl372 AccelerationY 3
    Execute Command           sysbus.spi2.adxl372 AccelerationZ 3

    Wait For Line On Uart     5.20 g

Should Handle I2C
    Create Machine            ${ADXL_I2C}  nrf52840--zephyr_adxl372_i2c.elf-s_944004-aacf7d772ebcc5a26c156f78ebdef2e03f803cc3
    Create Terminal Tester    ${UART}

    Execute Command           sysbus.twi1.adxl372 AccelerationX 0
    Execute Command           sysbus.twi1.adxl372 AccelerationY 0
    Execute Command           sysbus.twi1.adxl372 AccelerationZ 0 

    Start Emulation
    Wait For Line On Uart     Booting Zephyr OS
    Wait For Line On Uart     0.00 g

    Execute Command           sysbus.twi1.adxl372 AccelerationX 1
    Execute Command           sysbus.twi1.adxl372 AccelerationY 0
    Execute Command           sysbus.twi1.adxl372 AccelerationZ 0 

    Wait For Line On Uart     1.00 g

    Execute Command           sysbus.twi1.adxl372 AccelerationX 2
    Execute Command           sysbus.twi1.adxl372 AccelerationY 2
    Execute Command           sysbus.twi1.adxl372 AccelerationZ 0 

    Wait For Line On Uart     2.83 g

    Execute Command           sysbus.twi1.adxl372 AccelerationX 3
    Execute Command           sysbus.twi1.adxl372 AccelerationY 3
    Execute Command           sysbus.twi1.adxl372 AccelerationZ 3

    Wait For Line On Uart     5.20 g

Should Echo I2S Audio
    Create Machine            ${STANDARD}   nrf52840--nordic_snippets_i2s_master.elf-s_181224-98d5e53081cf7d76d30a183978a03b3e00beaf53

    ${input_file}=            Allocate Temporary File
    ${output_file}=           Allocate Temporary File
    Create Binary File        ${input_file}  \x00\x00\x00\x00\x5a\x82\x5a\x82\x7f\xff\x7f\xff\x5a\x82\x5a\x82\x00\x00\x00\x00\xa5\x7e\xa5\x7e\x80\x00\x80\x00\xa5\x7e\xa5\x7e

    Execute Command           sysbus.i2s InputFile @${input_file}
    Execute Command           sysbus.i2s OutputFile @${output_file}

    Execute Command           emulation RunFor "0.01"
    Execute Command           Clear

    ${input_file_size}=       Get File Size  ${input_file}
    ${output_file_size}=      Get File Size  ${output_file} 

    Should Be Equal           ${input_file_size}  ${output_file_size}

    ${input_file_content}=    Get Binary File  ${input_file}
    ${output_file_content}=   Get Binary File  ${output_file}

    Should Be Equal           ${input_file_content}  ${output_file_content}

Should Detect Yes Pattern
    [Tags]                    non_critical
    Create Machine            ${STANDARD}    nrf52840--tflite-micro_speech.elf-s_7172308-9ab5781883d7af2582d7fea09b14352628da9839

    Execute Command           sysbus.pdm SetInputFile ${URI}/audio_yes_1s.s16le.pcm-s_32000-b69f5518615516f80ae0082fe9b5a5d29ffebce8

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     Heard yes

Should Run Zephyr's kernel.interrupt Test
    [Tags]                    zephyr
    Create Machine            ${STANDARD}    nrf52840-zephyr-c320bb0-kernel-interrupt-test.elf-s_737512-7802727d11c415c1859c00842063ebec6c0a6fdc
    Create Terminal Tester    ${UART}

    Start Emulation
    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Run Zephyr's cmsis_dps.transform.rq15 Test
    [Documentation]           Tests if QADD16, QSUB16, QASX and QSAX intructions are working properly
    [Tags]                    zephyr
    Create Machine            ${STANDARD}    nrf52840--zephyr-cmsis_transform_rq15.elf-s_1115276-3e1fb95c3d1283d1fe22acf4b8ef887d05455fdf
    Create Terminal Tester    ${UART}

    Start Emulation
    Wait for Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Restart After Watchdog Timeout
    [Tags]                    zephyr
    Create Machine            ${STANDARD}    nrf52840--zephyr-watchdog.elf-s_889852-75a696a301c8439400645e646a322039963d74c8
    Create Terminal Tester    ${UART}
    Execute Command           sysbus.cpu PerformanceInMips 1
    # Zephyr is busy-waiting for watchdog timeout to trigger, which causes
    # virtual-time to flow _very slowly_ with higher PerformanceInMips.
    # This workarounds this issue by changing PerformanceInMips to lower value

    Start Emulation
    Wait for Line On Uart     Watchdog sample application
    Wait for Line On Uart     Watchdog sample application

Should Run Task Watchdog Subsystem 
    [Tags]                    zephyr
    Create Machine            ${STANDARD}    nrf52840--zephyr-task_wdt.elf-s_904904-91eadd958664ba0a009403a1a64f429dce3603a3
    Create Terminal Tester    ${UART}

    Start Emulation
    # Following set of lines should be continuosly repeated on uart.
    Wait for Line On Uart     Task watchdog sample application.
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Control thread started.
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Control thread getting stuck...
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Task watchdog channel 1 callback, thread: control
    Wait for Line On Uart     Resetting device...

    Wait for Line On Uart     Task watchdog sample application.
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Control thread started.
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Control thread getting stuck...
    Wait for Line On Uart     Main thread still alive...
    Wait for Line On Uart     Task watchdog channel 1 callback, thread: control
    Wait for Line On Uart     Resetting device...

Should Run Bluetooth sample
    Execute Command           emulation CreateIEEE802_15_4Medium "wireless"

    Execute Command           mach add "central"
    Execute Command           machine LoadPlatformDescription @platforms/cpus/nrf52840.repl
    Execute Command           sysbus LoadELF ${URI}/nrf52840--zephyr-bluetooth_central_hr.elf-s_3380332-316e27f81dcda3c2b0e7f2c3516001e7b27ad051
    Execute Command           connector Connect sysbus.radio wireless

    Execute Command           showAnalyzer ${UART}
    ${cen_uart}=  Create Terminal Tester   ${UART}   machine=central

    Execute Command           mach add "peripheral"
    Execute Command           mach set "peripheral"
    Execute Command           machine LoadPlatformDescription @platforms/cpus/nrf52840.repl
    Execute Command           sysbus LoadELF ${URI}/nrf52840--zephyr-bluetooth_peripheral_hr.elf-s_3217940-7b59adc9629f8be90067b131e663a13d2d4bb711
    Execute Command           connector Connect sysbus.radio wireless

    Execute Command           showAnalyzer ${UART}
    ${per_uart}=  Create Terminal Tester   ${UART}   machine=peripheral

    Execute Command           emulation SetGlobalQuantum "0.00001"

    Start Emulation

    Wait For Line On Uart     Booting Zephyr                    testerId=${cen_uart}
    Wait For Line On Uart     Booting Zephyr                    testerId=${per_uart}

    Wait For Line On Uart     Bluetooth initialized             testerId=${cen_uart}
    Wait For Line On Uart     Bluetooth initialized             testerId=${per_uart}

    Wait For Line On Uart     Scanning successfully started     testerId=${cen_uart}
    Wait For Line On Uart     Advertising successfully started  testerId=${per_uart}

    Wait For Line On Uart     Connected: C0:00:AA:BB:CC:DD      testerId=${cen_uart}
    Wait For Line On Uart     Connected                         testerId=${per_uart}

    Wait For Line On Uart     HRS notifications enabled         testerId=${per_uart}

    Wait For Line On Uart     [SUBSCRIBED]                      testerId=${cen_uart}
    Wait For Line On Uart     [NOTIFICATION]                    testerId=${cen_uart}

