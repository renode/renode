*** Variables ***
${URL}                              https://dl.antmicro.com/projects/renode
${HELLO_WORLD_ELF}                  ${URL}/renesas-da1459x-hello_world.elf-s_1266192-ec30b009ff7f1c806e6905030626dce2374817db
${WATCHDOG_ELF}                     ${URL}/renesas_da14592--watchdog.elf-s_1602660-74e8c2cde25d190d225185e9567b6fce4baeeac0
${ADC_ELF}                          ${URL}/renesas_da14592--adc.elf-s_1617224-06ae23b3a2f10598dbec9febef19b9cbee219121
${FREERTOS_RETARGET_ELF}            ${URL}/renesas_da1459x--freertos_retarget.elf-s_1269044-d15f0d09d3c156507ce8b054feeb1293713f864e
${DMA_ELF}                          ${URL}/renesas_da14592--dma_mem_to_mem.elf-s_1265040-95f747c5ab0f99da1ac4b342ff3bb156c77f7e06

*** Keywords ***
Create Machine
    [Arguments]                     ${elf}
    Execute Command                 set bin @${elf}
    Execute Command                 include @scripts/single-node/renesas-da14592.resc

*** Test Cases ***
UART Should Work
    Create Machine                  ${HELLO_WORLD_ELF}
    Create Terminal Tester          sysbus.uart1

    Wait For Line On Uart           Hello, world!

Test Watchdog
    Create Machine          ${WATCHDOG_ELF}

    Execute Command         sysbus.wdog Enabled false

    Create Log Tester       10
    Execute Command         logLevel -1 sysbus.wdog

    Wait For Log Entry      wdog: Ticker value set to: 0x1FFF
    Execute Command         sysbus.wdog Enabled true

    # The application initializes the wdog and then loops to refresh the watchdog 100 times.
    FOR  ${i}  IN RANGE  100
        Wait For Log Entry      wdog: Ticker value set to: 0x1FFF
    END

    # After NMI exception, binary falls into while(true) loop while waiting for the watchdog to reset the machine.
    # We set the quantum and advance immediately to speed up the test.
    Execute Command         emulation SetGlobalQuantum "0.001"
    Execute Command         emulation SetAdvanceImmediately true
    # The application loops waiting for the watchdog to reset the machine.
    Wait For Log Entry      wdog: Limit reached     timeout=85
    Wait For Log Entry      wdog: Triggering IRQ
    Execute Command         pause
    # It should take about 160ms of virtual time after NMI to reset the machine.
    Execute Command         emulation RunFor "0.17"
    Wait For Log Entry      wdog: Limit reached
    Wait For Log Entry      wdog: Reseting machine

Test GPADC
    Create Machine                  ${ADC_ELF}
    Execute Command                 sysbus Tag <0x50000028 +4> "SYS_STAT_REG" 0xE0D
    Execute Command                 sysbus Tag <0x50010024 +4> "CLOCK_GENERATION_CONTROLLER2_1" 0x1
    Create Terminal Tester          sysbus.uart1
    Execute Command                 sysbus.gpadc FeedSamplesFromRESD @https://dl.antmicro.com/projects/renode/renesas_da14_gpadc.resd-s_49-d7ebebfafe5c44561381ab5c3ffe65266f0a8ad3 6 6

    Wait For Line On Uart           ADC read completed
    Wait For Line On Uart           Number of samples: 21, ADC result value: 18900

GPIO Should Work
    Create Machine                  https://dl.antmicro.com/projects/renode/da1459x-gpio-sample.elf-s_1272236-e9ad9a46463f2b65117790c2c712c72b4174206d
    Create Terminal Tester          sysbus.uart1

    FOR  ${i}  IN RANGE  2
        FOR  ${j}  IN RANGE  2
            Wait For Line On Uart           Initial GPIO port: ${i} pin: ${j} val: 0
            Wait For Line On Uart           Updated GPIO port: ${i} pin: ${j} val: 1
        END
    END

Timer Should Work
    Create Machine                  ${FREERTOS_RETARGET_ELF}
    # Sample code doesn't reload the watchdog
    Execute Command                 sysbus.wdog Enabled false
    Create Terminal Tester          sysbus.uart1  defaultPauseEmulation=true

    Wait For Line On Uart           Hello, world!
    # Timer is configured to fire approx. once per second
    Wait For Line On Uart           Timer tick!  timeout=1.1
    Wait For Line On Uart           Timer tick!  timeout=1.1
    Wait For Line On Uart           Timer tick!  timeout=1.1

DMA Should Work
    Create Machine                  ${DMA_ELF}
    # Sample code doesn't reload the watchdog
    Execute Command                 sysbus.wdog Enabled false
    # This register contains memory remapping information.
    # It is necessary for the DMA to calculate the physical address.
    # At this point we don't support it  hw_sys_get_memory_remapping.
    Execute Command                 sysbus Tag <0x50000024 +4> "SYS_CTRL_REG" 0x3
    Create Terminal Tester          sysbus.uart1

    Wait For Line On Uart           SRC: { 0 1 2 3 4 5 6 7 8 9 }
    Wait For Line On Uart           DEST: { 0 0 0 0 0 0 0 0 0 0 }
    Wait For Line On Uart           Transfer completed
    Wait For Line On Uart           DEST: { 0 1 2 3 4 5 6 7 8 9 }
