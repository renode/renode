*** Variables ***
${UART}                       sysbus.usart2
${RTC_32KHZ}=  SEPARATOR=
...  """                                      ${\n}
...  using "platforms/cpus/stm32f4.repl"      ${\n}
...                                           ${\n}
...  rtc:                                     ${\n}
...  ${SPACE*4}wakeupTimerFrequency: 32000    ${\n}
...  """

*** Test Cases ***
Run Zephyr Hello World
    Execute Command           set bin @https://dl.antmicro.com/projects/renode/stm32f4_discovery--zephyr-hello_world.elf-s_515008-2180a4018e82fcbc8821ef4330c9b5f3caf2dcdb
    Execute Command           include @scripts/single-node/stm32f4_discovery.resc

    Execute Command           showAnalyzer ${UART}
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Booting Zephyr OS
    Wait For Line On Uart     Hello World! stm32f4_disco

Peripheral Export File Created
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription @platforms/cpus/stm32f4.repl

    ${temp_file} =             Allocate Temporary File
    Execute Command            peripherals export @${temp_file}
    File Should Exist          ${temp_file}
    File Should Not Be Empty   ${temp_file}

    ${export} =                Get File     ${temp_file}
    Should Contain             ${export}    Peripheral Map 1.0
    Should Contain             ${export}    SynopsysEthernetMAC
    Should Contain             ${export}    STM32_GPIOPort
    Should Contain             ${export}    STM32F4_RCC

Configure RTC Alarm
    Execute Command           mach create
    # Use an RTC frequency of exactly 32 kHz as expected by the test binary
    Execute Command           machine LoadPlatformDescriptionFromString ${RTC_32KHZ}
    Execute Command           sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4_discovery--riot-tests_periph_rtc.elf-s_1249644-ca2effb6a0a8bcde39496b99bcb8b160a4ed292e

    Execute Command           showAnalyzer ${UART}
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Help: Press s to start test, r to print it is ready
    Write Char On Uart        s

    Wait For Line On Uart     This is RIOT!
    Wait For Line On Uart     RIOT RTC low-level driver test
    Wait For Line On Uart     This test will display 'Alarm!' every 2 seconds for 4 times

    # "Alarm!" should be printed every 2 seconds, 4 times in total
    Wait For Line On Uart     Alarm!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:02
       
    Wait For Line On Uart     Alarm!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:04

    Wait For Line On Uart     Alarm!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:06

    Wait For Line On Uart     Alarm!
    ${timeInfo}=              Execute Command    emulation GetTimeSourceInfo
    Should Contain            ${timeInfo}        Elapsed Virtual Time: 00:00:08

    # There should be no more alarms after the expected 4
    Test If Uart Is Idle      3

Should Fire Update Event When Counting Up
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f4.repl
    Execute Command         sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4disco-timer-upcount.elf-g2d98d1b-s_1021132-961284be838516abea9db8302c9af2dcb67b482a

    Create Terminal Tester  sysbus.usart2

    Start Emulation

    Wait For Line On Uart   *** Timer2 Upcount Overflow Example ***
    Wait For Line On Uart   Tim2 IRQ enabled
    Wait For Line On Uart   Tim2 started
    Wait For Line On Uart   period elapsed callback
    Wait For Line On Uart   period elapsed callback
    Wait For Line On Uart   period elapsed callback

Should Fire Update Event When Counting Down
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f4.repl
    Execute Command         sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4disco-timer-downcount.elf-g2d98d1b-s_1021136-4995992fa219c49c38d7163da1381104c26c823a

    Create Terminal Tester  sysbus.usart2

    Start Emulation

    Wait For Line On Uart   *** Timer2 Downcount Overflow Example ***
    Wait For Line On Uart   Tim2 IRQ enabled
    Wait For Line On Uart   Tim2 started
    Wait For Line On Uart   period elapsed callback
    Wait For Line On Uart   period elapsed callback
    Wait For Line On Uart   period elapsed callback

Should Print Hello World When Built With STM32CubeMX
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f4.repl
    Execute Command         sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4--cube_mx-hello_world.elf-s_625976-606092c29de896f3bd83a4e981f2c7f3a6ed3142

    Create Terminal Tester  sysbus.usart2

    Start Emulation
    
    Wait For Line On Uart   Hello World!
    Wait For Line On Uart   Hello World!
    Wait For Line On Uart   Hello World!

Should Print Hello World With Custom Flash Latency
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f4.repl
    Execute Command         sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4--cube_mx-hello_world.elf-s_625992-119d2b1d81ef6bb85498d1024c61736bb53cee4c

    Create Terminal Tester  sysbus.usart2

    Start Emulation
    
    Wait For Line On Uart   Hello World!
    Wait For Line On Uart   Hello World!
    Wait For Line On Uart   Hello World!

Should Block Timer Interrupt When Faultmask Is Set
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f4.repl
    Execute Command         sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4disco-faultmask.elf-s_434744-080256edf201b1e2f7c67bf15000ba1ffa031990

    Create Terminal Tester  sysbus.usart2

    Start Emulation

    Wait For Line On Uart   Setting FAULTMASK to 1
    Wait For Line On Uart   Timer IRQ enabled
    Wait For Line On Uart   Sleeping
    Test If Uart Is Idle    1
    Wait For Line On Uart   Setting FAULTMASK to 0
    Wait For Line On Uart   Timer interrupt
    Wait For Line On Uart   Timer interrupt
    Wait For Line On Uart   Timer interrupt

Should Clear FAULTMASK On Exception Exit
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32f4.repl
    Execute Command         sysbus LoadELF @https://dl.antmicro.com/projects/renode/stm32f4disco-faultmask-noclearing.elf-s_433676-802f85357028150b4586bb3a54a5e44e7a3c2ec5

    Create Terminal Tester  sysbus.usart2

    Start Emulation

    # Each timer interrupt sets FAULTMASK, so if the field is not cleared by exception exit
    # then this message would be only printed once
    Wait For Line On Uart   Timer interrupt
    Wait For Line On Uart   Timer interrupt
    Wait For Line On Uart   Timer interrupt
    Wait For Line On Uart   Timer interrupt
