*** Settings ***
Library                             String

*** Variables ***
${URL}                              https://dl.antmicro.com/projects/renode
${GPT_ELF}                          ${URL}/renesas-rzg2l_evk--fsp-gpt_rzg2l_evk_ep.elf-s_450148-fec1da811a52fa94d39db555d0dccc28e246d28e
${GTM_ELF}                          ${URL}/renesas-rzg2l_evk--fsp-gtm_rzg2l_evk_ep.elf-s_415532-a907c69248cf6f695c717ee7dd83cc29d6fff3b4
${SCIF_UART_ELF}                    ${URL}/renesas-rzg2l_evk--fsp-scif_uart_rzg2l_evk_ep.elf-s_494948-c7ab4fdc0f2f8e62b8d99f194aab234ab1a50a32
${RSPI_ELF}                         ${URL}/renesas-rzg2l_evk--fsp-rspi_rzg2l_evk_ep.elf-s_431540-f07dc0ce78537eda672af3a028c50dcb3f21f3a5
${FREERTOS_BLINKY_ELF}              ${URL}/renesas-rz_g2l--fsp-blinky_freertos.elf-s_612428-2a79e42c3efdbc19207a7c1b2b3b3824e450b2ef
${IIC_MASTER_ELF}                   ${URL}/renesas-rzg2l_evk--fsp-riic_master_rzg2l_evk_ep.elf-s_522620-d57490521dd2e4dfcd4ca4a6cade57ce58228375
${UBOOT_ELF}                        ${URL}/uboot.elf-s_4151104-c5de311d27f0823c3d888309795fdc0a5b31473b
${MHU_ELF}                          ${URL}/renesas-rz_g2l--fsp-mhu_sample.elf-s_381944-3550734db5aa723c25c77142de4b7ebdeca0f1ba
${INTC_IRQ_ELF}                     ${URL}/renesas-rzg2l_evk--fsp-intc_irq_rzg2l_evk_ep.elf-s_413044-05d74d1def85e983f80165ae13f125cf302507d0
${LED_REPL}                         SEPARATOR=\n
...                                 """
...                                 led: Miscellaneous.LED @ gpio 0
...
...                                 gpio:
...                                 ${SPACE*4}100 -> led@0
...                                 """
${BUTTON_REPL}                      SEPARATOR=\n
...                                 """
...                                 button: Miscellaneous.Button @ gpio 1
...                                 ${SPACE*4}-> gpio@7
...                                 """

*** Keywords ***
Prepare Machine
    [Arguments]                     ${elf}
    Execute Command                 mach create "Renesas RZ/G2L"
    Execute Command                 using sysbus.cluster
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/renesas_rz_g2l.repl
    Execute Command                 macro reset "cpu0 IsHalted true; cpu1 IsHalted true; sysbus LoadELF @${elf} cpu=cpu_m33"
    Execute Command                 runMacro $reset

Prepare Segger RTT
    [Arguments]                     ${pauseEmulation}=true
    Execute Command                 machine CreateVirtualConsole "segger_rtt"
    Execute Command                 include @scripts/single-node/segger-rtt.py
    Execute Command                 setup_segger_rtt sysbus.segger_rtt
    Create Terminal Tester          sysbus.segger_rtt  defaultPauseEmulation=${pauseEmulation}

Elapsed Time Equals
    [Arguments]                     ${start}  ${end}  ${value}  ${margin}=0.8
    ${diff}=                        Evaluate  ${end} - ${start}
    Should Be True                  ${diff} >= ${value} - ${margin}
    Should Be True                  ${diff} <= ${value} + ${margin}

Prepare LED Tester
    Execute Command                 machine LoadPlatformDescriptionFromString ${LED_REPL}
    Create Led Tester               sysbus.gpio.led

Execute Linux Command
    [Arguments]                     ${command}
    Write Line To Uart              ${command}  waitForEcho=false
    Wait For Prompt On Uart         root@smarc-rzg2l:~#  timeout=600

*** Test Cases ***
Should Run The Timer In One Shot Mode
    Prepare Machine                 ${GPT_ELF}
    Prepare Segger RTT

    Wait For Prompt On Uart         User Input:
    Write Line To Uart              3  waitForEcho=false

    Wait For Line On Uart           Opened Timer in ONE-SHOT Mode
    Wait For Line On Uart           Started Timer in ONE-SHOT Mode
    Wait For Line On Uart           Timer Expired in One-Shot Mode

Should Run GTM Sample
    Prepare Machine                 ${GTM_ELF}
    Prepare Segger RTT
    Prepare LED Tester

    Wait For Prompt On Uart         One-shot mode:
    Write Line To Uart              10  waitForEcho=false
    Wait For Prompt On Uart         Periodic mode:
    Write Line To Uart              5  waitForEcho=false

    Wait For Prompt On Uart         Enter any key to start or stop the timers
    ${one_shot_start}=              Write Line To Uart  waitForEcho=false
    ${one_shot_end}=                Wait For Line On Uart  One-shot mode GTM timer elapsed
    Elapsed Time Equals             ${one_shot_start.Timestamp}  ${one_shot_end.Timestamp}  10

    Wait For Line On Uart           GTM1 is Enabled in Periodic mode
    FOR  ${i}  IN RANGE  0  3
        ${periodic_start}=              Wait For Line On Uart  Leds are: Off
        Assert Led State                False  timeout=0.01

        ${periodic_end}=                Wait For Line On Uart  Leds are: On
        Assert Led State                True  timeout=0.01
        Elapsed Time Equals             ${periodic_start.Timestamp}  ${periodic_end.Timestamp}  5  0.3
    END

Should Run SCIF UART Sample
    Prepare Machine                 ${SCIF_UART_ELF}
    Create Terminal Tester          sysbus.scif2
    Execute Command                 showAnalyzer sysbus.scif2

    # Let software initialize SCIF before we write to it
    Execute Command                 emulation RunFor "0.01s"
    Start Emulation

    Write Line To Uart              10  waitForEcho=false
    Wait For Line On Uart           Accepted value, the led is blinking with that value
    Wait For Line On Uart           Please set the next value

    Write Line To Uart              -1  waitForEcho=false
    Wait For Line On Uart           Invalid input. Input range is from 1 - 2000

    Write Line To Uart              2001  waitForEcho=false
    Wait For Line On Uart           Invalid input. Input range is from 1 - 2000

Should Run SPI WriteRead Sample
    Prepare Machine                 ${RSPI_ELF}
    Execute Command                 spi0 Register spi1 0
    Prepare Segger RTT

    Wait For Line On Uart           ** RSPI INIT SUCCESSFUL **
    Wait For Line On Uart           Press 1 for Write() and Read()
    Wait For Line On Uart           Press 2 for WriteRead()
    Wait For Line On Uart           Press 3 to Exit
    Write Line To Uart              2

    Wait For Line On Uart           Enter text input for Master buffer. Data size should not exceed 64 bytes.
    Write Line To Uart              0123456789

    Wait For Line On Uart           Enter text input for Slave buffer. Data size should not exceed 64 bytes.
    Write Line To Uart              abcdefghij

    Wait For Line On Uart           Master received data: abcdefghij
    Wait For Line On Uart           Slave received data: 0123456789
    Wait For Line On Uart           ** RSPI WRITE_READ Demo Successful**

Should Run FreeRTOS Blinky Sample
    Prepare Machine                 ${FREERTOS_BLINKY_ELF}
    Prepare LED Tester

    Assert LED Is Blinking          testDuration=5  onDuration=1  offDuration=1  pauseEmulation=true

Should Communicate Over IIC
    Prepare Machine                 ${IIC_MASTER_ELF}
    Execute Command                 machine LoadPlatformDescriptionFromString "adxl345: Sensors.ADXL345 @ riic3 0x1D"
    Prepare Segger RTT

    # Sample displays raw data from the sensor, so printed values are different from loaded samples
    Execute Command                 riic3.adxl345 FeedSample 1000 1000 1000
    Wait For Line On Uart           X-axis = 250.00, Y-axis = 250.00, Z-axis = 250.00

    Execute Command                 riic3.adxl345 FeedSample 2000 3000 4000
    Wait For Line On Uart           X-axis = 500.00, Y-axis = 750.00, Z-axis = 1000.00

    Execute Command                 riic3.adxl345 FeedSample 1468 745 8921
    Wait For Line On Uart           X-axis = 367.00, Y-axis = 186.00, Z-axis = 2230.00

    Execute Command                 riic3.adxl345 FeedSample 3912 8888 5456
    Wait For Line On Uart           X-axis = 978.00, Y-axis = 2222.00, Z-axis = 1364.00

    Execute Command                 riic3.adxl345 FeedSample 0 5000 0
    Wait For Line On Uart           X-axis = 0.00, Y-axis = 1250.00, Z-axis = 0.00

    Wait For Line On Uart           X-axis = 0.00, Y-axis = 0.00, Z-axis = 0.00

Should Copy Memory With DMA
    ${source}=                      Set Variable  0x60000100
    ${destination}=                 Set Variable  0x60000200
    ${expected_value}=              Set Variable  0xAABBCCDD
    ${channel_base}=                Set Variable  0x41800000
    ${channel_status}=              Evaluate  ${channel_base} + 0x24
    ${prog}=                        Catenate  SEPARATOR=\n
    ...                             str r1, [r0, #0xC]  # N1SA register offset
    ...                             str r2, [r0, #0x10]  # N1DA register offset
    ...                             str r3, [r0, #0x14]  # N1TB register offset
    ...                             str r4, [r0, #0x2C]  # CHCFG register offset
    ...                             str r5, [r0, #0x28]  # CHCTRL register offset
    ...                             str r6, [r0, #0x28]  # CHCTRL register offset

    Execute Command                 mach create "Renesas RZ/G2L"
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/renesas_rz_g2l.repl
    Execute Command                 cluster ForEach IsHalted true

    Execute Command                 sysbus WriteDoubleWord ${source} ${expected_value} cpu_m33
    Execute Command                 cpu_m33 SetRegister 0 ${channel_base}  # DMA Channel address
    Execute Command                 cpu_m33 SetRegister 1 ${source}  # Source address
    Execute Command                 cpu_m33 SetRegister 2 ${destination}  # Destination address
    Execute Command                 cpu_m33 SetRegister 3 0x4  # Transfer 4 bytes
    Execute Command                 cpu_m33 SetRegister 4 0x10403000  # Read access: double word, full transfer, select register bank 1
    Execute Command                 cpu_m33 SetRegister 5 0x8  # Reset DMA
    Execute Command                 cpu_m33 SetRegister 6 0x5  # Perform transaction

    Execute Command                 cpu_m33 AssembleBlock 0x60000000 "${prog}"
    Execute Command                 cpu_m33 PC 0x60000000
    Execute Command                 cpu_m33 Step 6
    ${flags}=                       Execute Command  sysbus ReadDoubleWord ${channel_status} cpu_m33
    Should Be Equal As Integers     ${flags}  0xE0  # Terminal count, DMA interrupt and register select are set
    ${result}=                      Execute Command  sysbus ReadDoubleWord ${destination} cpu_m33
    Should Be Equal As Integers     ${expected_value}  ${result}

Should Run U-Boot
    Execute Command                 set bin @${UBOOT_ELF}
    Execute Command                 include @scripts/single-node/rzg2l_uboot.resc
    Create Terminal Tester          sysbus.scif0  5  defaultPauseEmulation=true

    Wait For Prompt On Uart         Hit any key to stop autoboot
    Send Key To Uart                0x10

    Wait For Prompt On Uart         >
    Write Line To Uart              version

    Wait For Line On Uart           U-Boot
    Wait For Prompt On Uart         >

Should Communicate Between Cores Using MHU
    Prepare Machine                 ${MHU_ELF}
    Prepare Segger RTT

    ${mhu_channel}=                 Set Variable  1
    ${expected_data}=               Set Variable  0xAABBCCDD
    ${shared_mem_base}=             Execute Command  sysbus GetSymbolAddress "__mhu_shmem_start" cpu_m33
    ${shared_mem_base}=             Strip String  ${shared_mem_base}
    ${receive_data}=                Evaluate  ${shared_mem_base} + ${mhu_channel} * 0x8 + 0x4  # Each channel has 8 bytes available 4 for transmission and 4 for reception
    ${irq_trigger_register}=        Evaluate  0x010400000 + ${mhu_channel} * 0x20 + 0x4  # MSG_INT_SETn register visible from Cortex-A55

    Wait For Line On Uart           MHU initialized correctly
    Execute Command                 sysbus WriteDoubleWord ${receive_data} ${expected_data} cpu_m33
    Execute Command                 sysbus WriteDoubleWord ${irq_trigger_register} 0x1 cpu0  # Trigger MHU interrupt
    Wait For Line On Uart           MHU message received! (Channel: ${mhu_channel}, Data: ${expected_data})

Should Detect External Interrupt
    Prepare Machine                 ${INTC_IRQ_ELF}
    Execute Command                 machine LoadPlatformDescriptionFromString ${BUTTON_REPL}
    Prepare LED Tester
    Prepare Segger RTT

    Wait For Line On Uart           On pressing the user push button, an external IRQ is triggered, which toggles on-board LED.

    Execute Command                 sysbus.gpio.button PressAndRelease
    Wait For Line On Uart           LED State: High{ON}
    Assert Led State                True  timeout=0.01

    Execute Command                 sysbus.gpio.button PressAndRelease
    Wait For Line On Uart           LED State: Low{OFF}
    Assert Led State                False  timeout=0.01

Should Boot Linux
    Execute Command                 include @scripts/single-node/rzg2l_linux.resc
    Create Terminal Tester          sysbus.scif0  defaultPauseEmulation=true

    # Boot with ATF
    Wait For Line On Uart           NOTICE:${SPACE*2}BL31: v2.9(release):v2.9

    # Boot with U-Boot
    Wait For Line On Uart           U-Boot 2024.10
    # Manually trigger boot to speed up test
    Wait For Prompt On Uart         Hit any key to stop autoboot:${SPACE*2}2
    Write Line To Uart              ${EMPTY}
    Write Line To Uart              boot
    Wait For Line On Uart           Starting kernel ...

    # Boot Linux
    Wait For Line On Uart           Booting Linux on physical CPU 0x0000000000 [0x411fd050]
    Wait For Prompt On Uart         buildroot login:  timeout=140
    Write Line To Uart              root

    # Run command in userspace
    Wait For Prompt On Uart         \#${SPACE}
    Write Line To Uart              uname
    Wait For Line On Uart           Linux

Should Run Zephyr Shell Module Sample
    Execute Command                 include @scripts/single-node/rzg2l_zephyr.resc
    Create Terminal Tester          sysbus.scif2  defaultPauseEmulation=true

    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              demo board
    Wait For Line On Uart           rzg2l_smarc

Should Run OpenAMP Echo Sample
    Execute Command                 include @scripts/single-node/rzg2l_openamp.resc

    #Can set defaultPauseEmulation=true when #84075 is fixed (but it will cost around a minute in test duration)
    Create Terminal Tester          sysbus.scif0  defaultPauseEmulation=false
    Execute Command                 showAnalyzer sysbus.scif0

    Wait For Prompt On Uart         smarc-rzg2l login:  timeout=900
    Execute Linux Command           root
    Execute Linux Command           echo rzg2l_cm33_rpmsg_linux-rtos_demo.elf > /sys/class/remoteproc/remoteproc0/firmware
    Execute Linux Command           echo start > /sys/class/remoteproc/remoteproc0/state
    Write Line To Uart              rpmsg_sample_client
    Wait For Line On Uart           please input
    Wait For Line On Uart           >  includeUnfinishedLine=true
    Write Line To Uart              1

    FOR  ${i}  IN RANGE  0  471
        Wait For Line On Uart           sending payload number ${i} of size ${i + 17}
        Wait For Line On Uart           echo test: sent : ${i + 17}
        Wait For Line On Uart           received payload number ${i} of size ${i + 17}
    END
    Wait For Line On Uart           Test Results: Error count = 0

