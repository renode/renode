*** Variables ***
${URL}                              https://dl.antmicro.com/projects/renode
${GPT_ELF}                          ${URL}/renesas-rzg2l_evk--fsp-gpt_rzg2l_evk_ep.elf-s_450148-fec1da811a52fa94d39db555d0dccc28e246d28e
${GTM_ELF}                          ${URL}/renesas-rzg2l_evk--fsp-gtm_rzg2l_evk_ep.elf-s_415532-a907c69248cf6f695c717ee7dd83cc29d6fff3b4
${SCIF_UART_ELF}                    ${URL}/renesas-rzg2l_evk--fsp-scif_uart_rzg2l_evk_ep.elf-s_494948-c7ab4fdc0f2f8e62b8d99f194aab234ab1a50a32
${RSPI_ELF}                         ${URL}/renesas-rzg2l_evk--fsp-rspi_rzg2l_evk_ep.elf-s_431540-f07dc0ce78537eda672af3a028c50dcb3f21f3a5
${FREERTOS_BLINKY_ELF}              ${URL}/renesas-rz_g2l--fsp-blinky_freertos.elf-s_612428-2a79e42c3efdbc19207a7c1b2b3b3824e450b2ef
${IIC_MASTER_ELF}                   ${URL}/renesas-rzg2l_evk--fsp-riic_master_rzg2l_evk_ep.elf-s_522620-d57490521dd2e4dfcd4ca4a6cade57ce58228375
${LED_REPL}                         SEPARATOR=\n
...                                 """
...                                 led: Miscellaneous.LED @ gpio 0
...
...                                 gpio:
...                                 ${SPACE*4}100 -> led@0
...                                 """

*** Keywords ***
Prepare Machine
    [Arguments]                     ${elf}
    Execute Command                 mach create "Renesas RZ/G2L"
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/renesas_rz_g2l.repl
    Execute Command                 macro reset "cpu0 IsHalted true; cpu1 IsHalted true; sysbus LoadELF @${elf} cpu=cpu_m33"
    Execute Command                 runMacro $reset

Prepare Segger RTT
    [Arguments]                     ${pauseEmulation}=true
    Execute Command                 machine CreateVirtualConsole "segger_rtt"
    Execute Command                 include @scripts/single-node/renesas-segger-rtt.py
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
    Elapsed Time Equals             ${one_shot_start.timestamp}  ${one_shot_end.timestamp}  10

    Wait For Line On Uart           GTM1 is Enabled in Periodic mode
    FOR  ${i}  IN RANGE  0  3
        ${periodic_start}=              Wait For Line On Uart  Leds are: Off
        Assert Led State                False  timeout=0.01

        ${periodic_end}=                Wait For Line On Uart  Leds are: On
        Assert Led State                True  timeout=0.01
        Elapsed Time Equals             ${periodic_start.timestamp}  ${periodic_end.timestamp}  5  0.3
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
