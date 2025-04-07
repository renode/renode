*** Variables ***
${SPI_FLASH}=    SEPARATOR=
...  """                                         ${\n}
...  spiFlashMemory: Memory.MappedMemory         ${\n}
...  ${SPACE*4}size: 0x100000                    ${\n}
...                                              ${\n}
...  spiFlash: SPI.Micron_MT25Q @ spi2           ${\n}
...  ${SPACE*4}underlyingMemory: spiFlashMemory  ${\n}
...                                              ${\n}
...  gpioPortB:                                  ${\n}
...  ${SPACE*4}12 -> spiFlash@0                  ${\n}
...  """

*** Keywords ***
Check Zephyr Version
    Wait For Prompt On Uart  $
    Write Line To Uart       version
    Wait For Line On Uart    Zephyr version 2.6.99

Should Be Equal Within Range
    [Arguments]              ${value0}  ${value1}  ${range}

    ${diff}=                 Evaluate  abs(${value0} - ${value1})

    Should Be True           ${diff} <= ${range}

Set PWM And Check Duty
    [Arguments]              ${pwm}  ${channel}  ${period}  ${pulse}  ${expected_duty}

    Write Line To Uart       pwm cycles ${pwm} ${channel} ${period} ${pulse}
    Execute Command          gpioPortB.pt Reset
    Execute Command          pause
    Execute Command          emulation RunFor "5"
    # Go back to continuous running so the next iteration can run UART commands
    Start Emulation
    ${hp}=  Execute Command  gpioPortB.pt HighPercentage
    ${hpn}=  Convert To Number  ${hp}
    Should Be Equal Within Range  ${expected_duty}  ${hpn}  10

Run Command
    [Arguments]  ${command}
    Write Line To Uart       ${command}
    Wait For Prompt On Uart  $

Flash Should Contain
    [Arguments]  ${address}  ${value}
    ${res}=  Execute Command  flash ReadDoubleWord ${address}
    Should Be Equal As Numbers  ${res}  ${value}

*** Test Cases ***
Should Handle Version Command In Zephyr Shell
    Execute Command          include @scripts/single-node/stm32l072.resc

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Check Zephyr Version

Should Handle Version Command In Zephyr Shell On Lpuart
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/bl072z_lrwan1--zephyr-shell_module_lpuart.elf-s_1197384-aea9caa07fddc35583bd09cb47563a11a2f90935

    Create Terminal Tester   sysbus.lpuart1

    Start Emulation

    Check Zephyr Version

Should Handle DMA Memory To Memory Transfer
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-chan_blen_transfer.elf-s_669628-623c4f2b14cad8e52db12d8b1b46effd1a89b644

    # The test takes 8 seconds virtual time
    Create Terminal Tester   sysbus.usart2  timeout=10

    Wait For Line On Uart    PASS - [dma_m2m.test_dma_m2m_chan0_burst16]
    Wait For Line On Uart    PASS - [dma_m2m.test_dma_m2m_chan0_burst8]
    Wait For Line On Uart    PASS - [dma_m2m.test_dma_m2m_chan1_burst16]
    Wait For Line On Uart    PASS - [dma_m2m.test_dma_m2m_chan1_burst8]


Should Handle DMA Memory To Memory Loop Transfer
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-loop_transfer.elf-s_692948-f182b72146a77daeb4b73ece0aff2498aeaa5876

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    PASS - [dma_m2m_loop.test_dma_m2m_loop]
    Wait For Line On Uart    PASS - [dma_m2m_loop.test_dma_m2m_loop_suspend_resume]

Independent Watchdog Should Trigger Reset
    # We can't use stm32l072.resc in this test because it defines a reset macro
    # that loads a Zephyr ELF which gets triggered by the watchdog reset. This
    # would obviously make the test fail because it would suddenly start running
    # a different Zephyr application, but even if it reloaded the same ELF the
    # test would still fail because `m_state` would be reset. We manually define
    # a reset macro that only resets PC and SP to their initial values.
    Execute Command          mach create
    Execute Command          using sysbus
    Execute Command          machine LoadPlatformDescription @platforms/cpus/stm32l072.repl
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/zephyr-drivers_watchdog_wdt_basic_api-test.elf-s_463344-248e7e6eb8a681a33c4bf8fdb45c6bf95bcb57fd

    ${pc}=  Execute Command      sysbus GetSymbolAddress "z_arm_reset"
    ${sp}=  Execute Command      sysbus GetSymbolAddress "z_idle_stacks"

    Execute Command          macro reset "cpu PC ${pc}; cpu SP ${sp}"

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    PROJECT EXECUTION SUCCESSFUL

PWM Should Support GPIO Output
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-custom_shell_pwm.elf-s_884872-f36f63ef9435aaf89f37922d3c78428c52be1320

    # create a PWM analyzer and connect gpiob.10 to it
    Execute Command          machine LoadPlatformDescriptionFromString "pt: PWMTester @ gpioPortB 10"
    Execute Command          machine LoadPlatformDescriptionFromString "gpioPortB: { 10 -> pt@0 }"

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    ${pwm}=  Wait For Line On Uart  pwm device: (\\w+)  treatAsRegex=true
    ${pwm}=  Set Variable    ${pwm.Groups[0]}

    # The expected percentage in each test is approximately duty/period
    #                        pwm    ch period duty expected %
    Set PWM And Check Duty   ${pwm}  3  256    5    0
    Set PWM And Check Duty   ${pwm}  3  256   85   33
    Set PWM And Check Duty   ${pwm}  3  256  127   50
    Set PWM And Check Duty   ${pwm}  3  256  250  100

Should Handle Flash Operations
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-flash_shell.elf-s_1199160-dad825e98576f82198b759a75e5d0aeafcb00443

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    # Page 1504 (0x0002f000) and the surrounding area is empty so we can use it
    Flash Should Contain     0x0002f000  0x00000000
    Run Command              flash write 0x0002f000 0x11 0x22 0x33 0x44
    Flash Should Contain     0x0002f000  0x44332211

    Run Command              flash page_erase 1504
    Flash Should Contain     0x0002f000  0x00000000

    # Pages are 128 bytes long, so this pattern will cover 3 pages
    Run Command              flash write_pattern 0x0002f000 384
    Flash Should Contain     0x0002f020  0x23222120
    Flash Should Contain     0x0002f0a0  0xa3a2a1a0
    Flash Should Contain     0x0002f120  0x23222120

    # Erasing a page should set the whole page to 0 but not affect adjacent pages
    Run Command              flash page_erase 1505
    Flash Should Contain     0x0002f020  0x23222120
    # Check the first word of the page, a word within it and the last word of the page
    Flash Should Contain     0x0002f080  0x00000000
    Flash Should Contain     0x0002f0a0  0x00000000
    Flash Should Contain     0x0002f0fc  0x00000000
    Flash Should Contain     0x0002f120  0x23222120

Should Handle EEPROM Operations
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-eeprom.elf-s_526436-c574c036e4003e7b79923c7a3076809baa645826

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    PASS - test_size
    Wait For Line On Uart    PASS - test_out_of_bounds
    Wait For Line On Uart    PASS - test_write_rewrite
    Wait For Line On Uart    PASS - test_write_at_fixed_address
    Wait For Line On Uart    PASS - test_write_byte
    Wait For Line On Uart    PASS - test_write_at_increasing_address
    Wait For Line On Uart    PASS - test_zero_length_write
    Wait For Line On Uart    PROJECT EXECUTION SUCCESSFUL

RTC Should Support Alarms
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-alarm.elf-s_457324-fab62a573e2ce5b6cad2dfccfd6931021319cadc

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    Set alarm in 2 sec (2 ticks)
    Wait For Line On Uart    !!! Alarm !!!
    # This output seems off by one but it is correct
    # See https://github.com/zephyrproject-rtos/zephyr/commit/55594306544cddb5077923758485503fd723d2ae
    # and https://github.com/zephyrproject-rtos/zephyr/commit/507ebecffc325c2234419907884b3164950056d2
    Wait For Line On Uart    Now: 3

RTC Should Support Wakeup
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-custom_rtc_wakeup.elf-s_430288-709ea60e0de053b3d693718d80fd3afb9e090221

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    # This sample configures the RTC wakeup in 4 different ways, one after another:
    # - prescaler /2, autoreload 410
    # - prescaler /16, autoreload 410
    # - prescaler /16, autoreload 10
    # - 1Hz clock, autoreload 1
    # and expects the correct time to pass before the next time the wakeup callback
    # is triggered after each configuration. The wakeup callback prints the time
    # since the previous call in milliseconds.
    # The autoreload value of 410 comes from 25 ms * (32768 Hz / 2) = 409.6
    Wait For Line On Uart    RTC configured, waiting for wakeup interrupt
    Wait For Line On Uart    RTC wakeup callback triggered, wakeup flag is set, ticks=25
    Wait For Line On Uart    RTC wakeup callback triggered, wakeup flag is set, ticks=200
    Wait For Line On Uart    RTC wakeup callback triggered, wakeup flag is set, ticks=5
    Wait For Line On Uart    RTC wakeup callback triggered, wakeup flag is set, ticks=1000

Should Run Philosophers Demo On LpTimer
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-philosophers_lptimer.elf-s_579864-a8786745129b9aa4431c85138c0dcc65bd0543e4

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    Philosopher 5.*THINKING    treatAsRegex=true
    Wait For Line On Uart    Philosopher 5.*HOLDING     treatAsRegex=true
    Wait For Line On Uart    Philosopher 5.*EATING      treatAsRegex=true

SPI Should Work In Interrupt-Driven Mode
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          machine LoadPlatformDescriptionFromString ${SPI_FLASH}
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-spi_flash.elf-s_540832-09b987ec67ea619d0330963ef9d35ab561d04430

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    Flash erase succeeded!
    Wait For Line On Uart    Data read matches data written. Good!!

PVD Should Fire Interrupt
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          sysbus LoadELF @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1-zephyr-custom_pwr_pvd.elf-s_871128-6822cb7346d2171c2b170b74701144d59b36199c

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Run Command              pvd configure 3.1 rising
    Execute Command          pwr Voltage 2.9
    Wait For Line On Uart    PVD callback triggered, PVDO is set

DMA Transfer Should Write To UART
    Execute Command          $bin = @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-custom_dma_hello_world.elf-s_591108-c4351f75c230563f429aadffb53f294fa7738406
    Execute Command          include @scripts/single-node/stm32l072.resc

    Create Terminal Tester   sysbus.usart2

    Start Emulation

    Wait For Line On Uart    Hello world from DMA!

DMA Transfer Should Write To And Read From UART
    Execute Command          $bin = @https://dl.antmicro.com/projects/renode/stm32l073--cubemx-USART_Communication_TxRx_DMA.elf-s_179016-cae1f7f14ab8ddb7db17cc1e8a8ee2826bc0da81
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          machine LoadPlatformDescriptionFromString "gpioPortA: { 5 -> led@0 }; led: Miscellaneous.LED @ gpioPortA 5"
    Execute Command          machine LoadPlatformDescriptionFromString "button: Miscellaneous.Button @ gpioPortC 13 { invert: true; -> gpioPortC@13 }"
    Execute Command          machine LoadPlatformDescriptionFromString "usart2: { ReceiveDmaRequest -> dma1@6 }"

    Create Terminal Tester   sysbus.usart2
    Create LED Tester        sysbus.gpioPortA.led  defaultTimeout=2

    Assert LED State         true  pauseEmulation=true

    Execute Command          gpioPortC.button Press
    Assert LED State         false  pauseEmulation=true
    Wait For Line On Uart    STM32L0xx USART LL API Example : TX/RX in DMA mode  pauseEmulation=true
    Wait For Line On Uart    Configuration UART 115200 bps, 8 data bit/1 stop bit/No parity/No HW flow control  pauseEmulation=true
    Wait For Line On Uart    Please enter 'END' string ...  pauseEmulation=true

    Write Line To Uart       END  waitForEcho=false
    Assert And Hold LED State  true  timeoutAssert=0.1  timeoutHold=2
