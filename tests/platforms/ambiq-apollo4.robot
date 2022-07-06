*** Variables ***
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    Execute Command           using sysbus
    Execute Command           mach create "Ambiq Apollo4"

    Execute Command           machine LoadPlatformDescription @platforms/cpus/ambiq-apollo4.repl
    Create Terminal Tester    sysbus.uart2  10

Load Example
    [Arguments]    ${axf_filename}
    Execute Command           sysbus LoadELF ${URI}/${axf_filename}

Start Example
    [Arguments]    ${axf_filename}
    Load Example              ${axf_filename}
    Start Emulation

Load Bytes To Memory
    [Arguments]    ${address}    @{bytes}
    FOR    ${byte}    IN    @{bytes}
        Execute Command       sysbus WriteByte ${address} ${byte}
        ${address} =          Evaluate    ${address} + 1
    END

*** Test Cases ***
Should Successfully Run hello_world_uart Example
    Create Machine
    Start Example             hello_world_uart.axf-s_307536-899c2682fa35d4bf27992bba5a0b5845ae331ba3

    Wait For Line On Uart     Hello World!
    Wait For Line On Uart     Vendor Name:

Should Successfully Run stimer Example
    Create Machine
    Start Example             stimer.axf-s_252512-bd594169c2dce5d6771bb426a479fc622b1c6182

    Wait For Line On Uart     SUCCESS!
    Execute Command           pause

    Execute Command           emulation RunFor '00:00:02.5000'
    # A single "SUCCESS!" line should be printed each second (approximately) so check if there are two such lines.
    Wait For Line On Uart     SUCCESS!  0
    Wait For Line On Uart     SUCCESS!  0

    # There shouldn't be any more SUCCESS! lines on UART.
    Run Keyword And Expect Error    *Line containing >>SUCCESS!<< event: failure*    Wait For Line On Uart  SUCCESS!  0

Should Successfully Run rtc_print Example
    Create Machine
    Start Example             rtc_print.axf-s_259852-abb4ec53fd71107857a6b0a60994e81cda77d4d5

    # A fixed time set in the test instead of the compilation time.
    Wait For Line On Uart     It is now 9 : 00 : 00.00 Tuesday April 26, 2022    includeUnfinishedLine=true

    # Check RTC setting and progress.
    Execute Command           pause
    Execute Command           rtc SetDateTime 2022 12 31 23 59 59 15
    ${res}=  Execute Command  rtc PrintPreciseCurrentDateTime
    Should Contain            ${res}  2022-12-31T23:59:59.1500000
    ${res}=  Execute Command  emulation RunFor '00:00:00.12'; rtc PrintPreciseCurrentDateTime
    Should Contain            ${res}  2022-12-31T23:59:59.2700000

    # Set the alarm to every second.
    Execute Command           rtc WriteDoubleWord 0x0 0xE
    # Alarm whenever millisecond value equals 310.
    Execute Command           rtc WriteDoubleWord 0x30 0x31
    # Make sure alarm is properly set.
    ${res}=  Execute Command  rtc PrintNextAlarmDateTime
    Should Contain            ${res}  2022-12-31T23:59:59.3100000
    # Make sure the interrupt status is off.
    ${res}=  Execute Command  rtc ReadDoubleWord 0x204
    Should Contain            ${res}  0x00000000

    # Progress the timer and stop before the event
    ${res}=  Execute Command  emulation RunFor '00:00:00.03'; rtc PrintPreciseCurrentDateTime
    Should Contain            ${res}  2022-12-31T23:59:59.3000000
    # Check the interrupt status.
    ${res}=  Execute Command  rtc ReadDoubleWord 0x204
    Should Contain            ${res}  0x00000000

    # Progress the timer - this time the event should trigger
    ${res}=  Execute Command  emulation RunFor '00:00:00.01'; rtc PrintPreciseCurrentDateTime
    Should Contain            ${res}  2022-12-31T23:59:59.3100000
    # Check the interrupt status.
    ${res}=  Execute Command  rtc ReadDoubleWord 0x204
    Should Contain            ${res}  0x00000001
    # Make sure the next alarm is properly scheduled.
    ${res}=  Execute Command  rtc PrintNextAlarmDateTime
    Should Contain            ${res}  2023-01-01T00:00:00.3100000
    # Clear the interrupt status and check if it's reset.
    ${res}=  Execute Command  rtc WriteDoubleWord 0x208 0x1; rtc ReadDoubleWord 0x204
    Should Contain            ${res}  0x00000000
    # Progress the timer to the next year.
    ${res}=  Execute Command  emulation RunFor '00:00:01.00'; rtc PrintPreciseCurrentDateTime
    Should Contain            ${res}  2023-01-01T00:00:00.3100000
    # Check the interrupt status.
    ${res}=  Execute Command  rtc ReadDoubleWord 0x204
    Should Contain            ${res}  0x00000001

    # Set the alarm interval to every week.
    Execute Command           rtc WriteDoubleWord 0x0 0x6
    # The alarm will be set to the next Sunday at 00:00:00.31 because only the alarm's milliseconds are set (Sunday is weekday=0).
    ${res}=  Execute Command  rtc PrintNextAlarmDateTime
    Should Contain            ${res}  2023-01-08T00:00:00.3100000
    # Set the alarm's weekday to Friday.
    Execute Command           rtc WriteDoubleWord 0x34 0x50000
    # Trigger the alarm exactly at 12:34:56.78.
    Execute Command           rtc WriteDoubleWord 0x30 0x12345678
    # Check if the alarm is set properly.
    ${res}=  Execute Command  rtc PrintNextAlarmDateTime
    Should Contain            ${res}  2023-01-06T12:34:56.7800000

    # Test if the alarm is properly adjusted after setting new date.
    Execute Command           rtc SetDateTime 2022 05 06 20 48 20 15
    ${res}=  Execute Command  rtc PrintNextAlarmDateTime
    Should Contain            ${res}  2022-05-13T12:34:56.7800000

    # Test setting the alarm to once a year on 23rd of February.
    Execute Command           rtc WriteDoubleWord 0x34 0x0223
    Execute Command           rtc WriteDoubleWord 0x0 0x2
    ${res}=  Execute Command  rtc PrintNextAlarmDateTime
    Should Contain            ${res}  2023-02-23T12:34:56.7800000

    # Test disabling the alarm.
    Execute Command           rtc WriteDoubleWord 0x0 0x0
    ${res}=  Execute Command  rtc PrintNextAlarmDateTime
    Should Contain            ${res}  Alarm not set.

Should Successfully Run ios_fifo_host Example
    Create Machine
    Execute Command           machine LoadPlatformDescriptionFromString "dummySpi: Mocks.DummySPISlave @ iom1 0"
    Create Log Tester         10
    Execute Command           logLevel 0 iom1.dummySpi
    Start Example             ios_fifo_host.axf-s_253032-865941e8c49057c68d2d866e9c9308febe684644

    Wait For Line On Uart     IOS Test Host: Waiting for at least 10000 bytes from the slave.    includeUnfinishedLine=true

    # Currently only writes to the slave peripheral are tested.
    Wait For Log Entry        iom1.dummySpi: Data received: 0xF8
    Wait For Log Entry        iom1.dummySpi: Data received: 0x1
    Wait For Log Entry        iom1.dummySpi: Data received: 0x80
    Wait For Log Entry        iom1.dummySpi: Data received: 0x0

Should Successfully Run binary_counter Example
    Create Machine
    Execute Command           machine LoadPlatformDescriptionFromString 'gpio: { 30 -> led30@0; 90 -> led90@0; 91 -> led91@0 }; led30: Miscellaneous.LED @ gpio 30; led90: Miscellaneous.LED @ gpio 90; led91: Miscellaneous.LED @ gpio 91'
    Load Example              binary_counter.axf-s_264304-49508d8e17aeaaa88845426e007dde2ce4416892

    Execute Command           emulation CreateLEDTester "led30_tester" sysbus.gpio.led30
    Execute Command           emulation CreateLEDTester "led90_tester" sysbus.gpio.led90
    Execute Command           emulation CreateLEDTester "led91_tester" sysbus.gpio.led91

    Execute Command           emulation RunFor "1"

    Execute Command           led30_tester AssertState false 0
    Execute Command           led90_tester AssertState false 0
    Execute Command           led91_tester AssertState false 0

    # this simulates an IRQ from the timer
    Execute Command           nvic OnGPIO 14 true; nvic OnGPIO 14 false

    Execute Command           emulation RunFor "1"

    Execute Command           led30_tester AssertState true 0
    Execute Command           led90_tester AssertState true 0
    Execute Command           led91_tester AssertState true 0

Test Calling Unimplemented Bootrom Function
    Create Machine
    Create Log Tester         1

    ${FUNCTION_ADDRESS} =     Set Variable  0x08000098
    ${FUNCTION_NAME} =        Set Variable  Recovery

    Execute Command           cpu PC ${FUNCTION_ADDRESS}
    Start Emulation
    Wait For Log Entry        bootrom_logger: Unimplemented BOOTROM function called: ${FUNCTION_NAME} (${FUNCTION_ADDRESS})

Should Successfully Run adc_measure Example
    Create Machine
    Start Example             adc_measure.axf-s_258564-3c473c4e7c59b73cdbf00b22b633e3301923ed61

    Wait For Line On Uart     ADC correction offset = 0.0
    Wait For Line On Uart     ADC correction gain * = 0.0  treatAsRegex=true  # Regex handles the output's triple space.

    # Make sure slot channels are correct
    Wait For Line On Uart     ADC SLOT0 = 0x.....1..    treatAsRegex=true
    Wait For Line On Uart     ADC SLOT1 = 0x.....2..    treatAsRegex=true
    Wait For Line On Uart     ADC SLOT2 = 0x.....4..    treatAsRegex=true
    Wait For Line On Uart     ADC SLOT3 = 0x.....6..    treatAsRegex=true

    # A single software trigger is sent by the example so a single read from each slot should be printed.
    # These values are the example defaults set in the REPL file.
    Wait For Line On Uart     ADC#0 sample read=681, measured voltage=197.0 mV
    Wait For Line On Uart     ADC#1 sample read=1363, measured voltage=395.0 mV
    Wait For Line On Uart     ADC#2 sample read=2729, measured voltage=792.0 mV
    Wait For Line On Uart     ADC#3 sample read=4092, measured voltage=1188.0 mV

    # Change some values and manually trigger a scan.
    Execute Command           adc Channel2Data 0x00040
    Execute Command           adc Channel4Data 0x35E00
    Execute Command           adc ScanAllSlots
    Wait For Line On Uart     ADC#0 sample read=681, measured voltage=197.0 mV
    Wait For Line On Uart     ADC#1 sample read=0, measured voltage=0.0 mV
    Wait For Line On Uart     ADC#2 sample read=3445, measured voltage=1000.0 mV
    Wait For Line On Uart     ADC#3 sample read=4092, measured voltage=1188.0 mV

Test Calculating CRC32 Value
    Create Machine
    Create Log Tester         1
    Execute Command           logLevel -1 security

    # The data and its CRC come from SDK's 'em9304_patches.c'.
    ${address} =              Set Variable  0x0
    ${crc} =                  Set Variable  0xF9FC5EF5
    Load Bytes To Memory      ${address}
    ...                           0x33  0x39  0x6D  0x65  0x20  0x00  0x00  0x00
    ...                           0x01  0x0B  0x18  0x14  0x11  0x0C  0x02  0x00
    ...                           0x75  0xDE  0xC7  0x98  0x81  0x00  0x00  0x00
    ...                           0x01  0x00  0x00  0x00  0x01  0x00  0x00  0x00
    ${length} =               Set Variable  0x20

    # Check if the SDK's 'am_hal_crc32' steps work.
    Execute Command           security WriteDoubleWord 0x30 0xFFFFFFFF  # Seed initial value.
    Execute Command           security WriteDoubleWord 0x10 ${address}  # Set source address.
    Execute Command           security WriteDoubleWord 0x20 ${length}   # Set length.
    Execute Command           security WriteDoubleWord 0x0 0x0          # Set FUNCTION field to CRC32.

    # Start the calculation by setting the ENABLE bit and wait for the result log.
    Execute Command           security WriteDoubleWord 0x0 0x1
    Wait For Log Entry        security: CRC32 calculation result: ${crc}

    # Check if the ENABLE bit has been cleared.
    ${control_register} =     Execute Command  security ReadDoubleWord 0x0
    Should Contain            ${control_register}  0x0

    # Check the result register's value.
    ${result_register} =      Execute Command  security ReadDoubleWord 0x30
    Should Contain            ${result_register}  ${crc}
