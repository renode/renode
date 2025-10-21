*** Settings ***
Library                             nucleo_h753zi_helpers.py

*** Variables ***
${UART}                             sysbus.usart3

${PROJECT_URL}                      https://dl.antmicro.com/projects/renode
${ECHO_SERVER}                      ${PROJECT_URL}/zephyr-nucleo_h753zi_echo_server.elf-s_3820436-2a55e73d28b438666b588d87cc9822365ee46cf6
${ECHO_CLIENT}                      ${PROJECT_URL}/zephyr-nucleo_h753zi_echo_client.elf-s_3773508-692f892b406f5a4a0aedb4afe120acd26f420d21
${BLINKY}                           ${PROJECT_URL}/zephyr--nucleo-h753zi-blinky.elf-s_586204-d9aa33947652eb18930088c06704ad6a8cdc7fa4
${BUTTON}                           ${PROJECT_URL}/zephyr--nucleo_h753zi_button_sample.elf-s_582696-3d5e6775a24c75e8fff6b812d5bc850b361e3d93
${CRYPTO_GCM}                       ${PROJECT_URL}/stm32cubeh7--stm32h753zi-CRYP_AESGCM.elf-s_2136368-45a90683e4f954667a464fc8fa9ce57d0b74ac09
${CRYPTO_GCM_IT}                    ${PROJECT_URL}/stm32cubeh7--stm32h753zi-CRYP_AESGCM_IT.elf-s_2137876-ee038aa93bf68cb91af9894e0be9584eec3057e5
${CRYPTO_AES_DMA}                   ${PROJECT_URL}/stm32cubeh7--stm32h753zi-CRYP_AESModes_DMA.elf-s_2152168-edf19388077bb230a242d2dfc7392ea881f29051
${QSPI_RW}                          ${PROJECT_URL}/stm32cubeh7--stm32h753zi-QSPI_ReadWrite_IT.elf-s_2146460-5c6870c2698fe33a9ef78ce791d9e83439328cc4
${QSPI_MemMapped}                   ${PROJECT_URL}/stm32cubeh7--stm32h753zi-QSPI_MemoryMapped.elf-s_2152312-faec8bb984c61aabb52ae9eec1598999ea906a1c
${QSPI_XIP}                         ${PROJECT_URL}/stm32cubeh7--stm32h753zi-QSPI_ExecuteInPlace.elf-s_2233412-67befe44572c483b242a95ce8e714f75f4e7dc69
${PTP}                              ${PROJECT_URL}/nucleo_h753zi--zephyr-samples_net_ptp.elf-s_4678660-79097838e7a15377e3d9ce083917220bd0705312
${FLASH_EraseProgram}               ${PROJECT_URL}/stm32cubeh7--stm32h753zi-FLASH_EraseProgram.elf-s_2098720-fdf4d20c82c0619eee844117860017b477696298

${PLATFORM}                         platforms/boards/nucleo_h753zi.repl

${EVAL_STUB}=    SEPARATOR=
...  """                                                                  ${\n}
...  led1: Miscellaneous.LED @ gpioPortF 10 { invert: true }              ${\n}
...  led3: Miscellaneous.LED @ gpioPortA 4 { invert: true }               ${\n}
...  gpioPortF:                                                           ${\n}
...  ${SPACE*4}10 -> led1@0                                               ${\n}
...                                                                       ${\n}
...  gpioPortA:                                                           ${\n}
...  ${SPACE*4}4 -> led3@0                                                ${\n}
...  """

# The address of the memory is mentioned in the MCU docs, when the QSPI is configured to operate in memory-mapped mode
# So it's added along with the external flash
${EXTERNAL_FLASH}=   SEPARATOR=
...    """
...    externalQspiFlash: SPI.Macronix_MX25R @ qspi {underlyingMemory: qspiMappedFlashMemory}   ${\n}
...    qspiMappedFlashMemory: Memory.MappedMemory @ sysbus 0x90000000 { size: 0x10000000 }  ${\n}
...    """

${PTP_PLATFORM}=    SEPARATOR=${\n}
...    using "${PLATFORM}"
...    nvic:
...    ${SPACE*4}systickFrequency: 480000000  # Set frequency to match what software expects

*** Keywords ***
Create Setup
    Execute Command                 emulation CreateSwitch "switch"

    Create Machine                  ${ECHO_SERVER}  server
    Execute Command                 connector Connect sysbus.ethernet switch
    Create Machine                  ${ECHO_CLIENT}  client
    Execute Command                 connector Connect sysbus.ethernet switch

Create Machine
    [Arguments]                     ${elf}  ${name}

    Execute Command                 mach add "${name}"
    Execute Command                 mach set "${name}"
    Execute Command                 machine LoadPlatformDescription @${PLATFORM}

    Execute Command                 sysbus LoadELF @${elf}

Create PTP Machine
    [Arguments]                     ${elf}  ${name}
    Execute Command                 mach create "${name}"
    Execute Command                 machine LoadPlatformDescriptionFromString """${PTP_PLATFORM}"""
    Execute Command                 sysbus LoadELF @${elf}

Assert PC Equals
    [Arguments]            ${expected}
    ${pc}=                 Execute Command  sysbus.cpu PC
    Should Be Equal As Integers  ${pc}  ${expected}

*** Test Cases ***
Should Talk Over Ethernet
    Create Setup
    ${server}=  Create Terminal Tester          ${UART}  machine=server  defaultPauseEmulation=True
    ${client}=  Create Terminal Tester          ${UART}  machine=client  defaultPauseEmulation=True

    Wait For Line On Uart           Initializing network                                                 testerId=${server}
    Wait For Line On Uart           Run echo server                                                      testerId=${server}
    Wait For Line On Uart           Network connected                                                    testerId=${server}
    Wait For Line On Uart           Waiting for TCP connection                                           testerId=${server}

    Wait For Line On Uart           Initializing network                                                 testerId=${client}
    Wait For Line On Uart           Run echo client                                                      testerId=${client}
    Wait For Line On Uart           Network connected                                                    testerId=${client}

    Wait For Line On Uart           Accepted connection                                                  testerId=${server}

    Wait For Line On Uart           Sent                                                                 testerId=${client}
    Wait For Line On Uart           Received and replied                                                 testerId=${server}
    Wait For Line On Uart           Received and compared \\d+ bytes, all ok                             testerId=${client}   treatAsRegex=true

    Wait For Line On Uart           Sent                                                                 testerId=${client}
    Wait For Line On Uart           Received and replied                                                 testerId=${server}
    Wait For Line On Uart           Received and compared \\d+ bytes, all ok                             testerId=${client}   treatAsRegex=true

    Wait For Line On Uart           Sent                                                                 testerId=${client}
    Wait For Line On Uart           Received and replied                                                 testerId=${server}
    Wait For Line On Uart           Received and compared \\d+ bytes, all ok                             testerId=${client}   treatAsRegex=true

    Wait For Line On Uart           Sent                                                                 testerId=${client}
    Wait For Line On Uart           Received and replied                                                 testerId=${server}
    Wait For Line On Uart           Received and compared \\d+ bytes, all ok                             testerId=${client}   treatAsRegex=true

Should Blink Led
    Create Machine                  ${BLINKY}  blinky

    Create Terminal Tester          ${UART}                                       defaultPauseEmulation=True
    Create LED Tester               sysbus.gpioPortB.GreenLED                     defaultTimeout=1

    Wait For Line On Uart           *** Booting Zephyr OS                         includeUnfinishedLine=true
    Wait For Line On Uart           LED state: (ON|OFF)                           treatAsRegex=true

    Assert LED Is Blinking          testDuration=8  onDuration=1  offDuration=1  pauseEmulation=true

Should See Button Press
    Create Machine                  ${BUTTON}  button

    Create Terminal Tester          ${UART}                                       defaultPauseEmulation=True
    Create LED Tester               sysbus.gpioPortB.GreenLED                     defaultTimeout=1

    Wait For Line On Uart           *** Booting Zephyr OS                         includeUnfinishedLine=true
    Wait For Line On Uart           Press the button
    Assert LED State                false

    Execute Command                 sysbus.gpioPortC.UserButton1 Press
    Wait For Line On Uart           Button pressed at                             includeUnfinishedLine=true
    Assert LED State                true
    Execute Command                 sysbus.gpioPortC.UserButton1 Release
    Assert LED State                false

Should Encrypt And Decrypt Data in AES GCM Mode
    Create Machine                  ${CRYPTO_GCM}  crypt-gcm
    # This sample is built for STM32 Evaluation Kit, which uses the same SoC but has a bit different HW - we only care about LEDs to signal test status
    Execute Command                 machine LoadPlatformDescriptionFromString ${EVAL_STUB}

    ${led3_tester}=                 Create LED Tester   sysbus.gpioPortA.led3     defaultTimeout=1
    ${led1_tester}=                 Create LED Tester   sysbus.gpioPortF.led1     defaultTimeout=1

    # LED3 would be set if at any point of the test a failure occurred (e.g. on invalid MAC or ciphertext not matching the expected value)
    # LED1 is set at the very end of the test, when the entire procedure is complete with no failures
    Assert LED State                false    testerId=${led3_tester}
    Assert LED State                true     testerId=${led1_tester}

Should Encrypt And Decrypt Data in AES GCM Mode With Interrupts
    Create Machine                  ${CRYPTO_GCM_IT}  crypt-gcm
    Execute Command                 machine LoadPlatformDescriptionFromString ${EVAL_STUB}

    ${led3_tester}=                 Create LED Tester   sysbus.gpioPortA.led3     defaultTimeout=1
    ${led1_tester}=                 Create LED Tester   sysbus.gpioPortF.led1     defaultTimeout=1

    # See `Should Encrypt And Decrypt Data in AES GCM Mode` for explanation
    Assert LED State                false    testerId=${led3_tester}
    Assert LED State                true     testerId=${led1_tester}

Should Program Flash With QSPI
    Create Machine                  ${QSPI_RW}  qspi
    # This sample is built for STM32 Evaluation Kit, which uses the same SoC but has a bit different HW - we only care about LEDs to signal test status
    Execute Command                 machine LoadPlatformDescriptionFromString ${EVAL_STUB}
    Execute Command                 machine LoadPlatformDescriptionFromString ${EXTERNAL_FLASH}

    ${led3_tester}=                 Create LED Tester   sysbus.gpioPortA.led3     defaultTimeout=1
    ${led1_tester}=                 Create LED Tester   sysbus.gpioPortF.led1     defaultTimeout=1

    # Wait for drivers to configure GPIO
    Assert LED State                false    testerId=${led3_tester}     pauseEmulation=true
    Assert LED State                false    testerId=${led1_tester}     pauseEmulation=true

    # LED1 means that the data was uploaded to flash, and the comparison with the base was successful
    # LED2 should inform about comparison success, but we lack the necessary peripherals to configure it
    # the sample has been modified instead to halt on first comparison error and turn LED3 on
    Assert LED State                true     testerId=${led1_tester}     pauseEmulation=true     timeout=10
    Assert LED State                false    testerId=${led3_tester}     pauseEmulation=true

    # And again - LED 1 toggles each time a transfer round completes
    Assert LED State                false    testerId=${led1_tester}     pauseEmulation=true
    Assert LED State                false    testerId=${led3_tester}     pauseEmulation=true

    Assert LED State                true     testerId=${led1_tester}     pauseEmulation=true
    Assert LED State                false    testerId=${led3_tester}     pauseEmulation=true

Should Program Flash With QSPI Memory Mapped
    Create Machine                  ${QSPI_MemMapped}  qspi
    # This sample is built for STM32 Evaluation Kit, which uses the same SoC but has a bit different HW - we only care about LEDs to signal test status
    Execute Command                 machine LoadPlatformDescriptionFromString ${EVAL_STUB}
    Execute Command                 machine LoadPlatformDescriptionFromString ${EXTERNAL_FLASH}

    ${led3_tester}=                 Create LED Tester   sysbus.gpioPortA.led3     defaultTimeout=1
    ${led1_tester}=                 Create LED Tester   sysbus.gpioPortF.led1     defaultTimeout=1

    # Wait for drivers to configure GPIO
    Assert LED State                false    testerId=${led3_tester}     pauseEmulation=true
    Assert LED State                false    testerId=${led1_tester}     pauseEmulation=true

    # LED1 means that the data was uploaded to flash, and the comparison with the base was successful
    Assert LED State                true     testerId=${led1_tester}     pauseEmulation=true    timeout=10
    Assert LED State                false    testerId=${led3_tester}     pauseEmulation=true

    # And again - LED 1 toggles each time a transfer round completes
    Assert LED State                false    testerId=${led1_tester}     pauseEmulation=true
    Assert LED State                false    testerId=${led3_tester}     pauseEmulation=true

    Assert LED State                true     testerId=${led1_tester}     pauseEmulation=true
    Assert LED State                false    testerId=${led3_tester}     pauseEmulation=true

# This sample normally would use MDMA to transfer data, but has been switched to interrupt mode instead
# Additionally, unsupported LEDs are disabled
# Instead of blinking LEDs periodically, it will spin forever after turning them on, on test success
Should Program Flash With QSPI and use XIP
    Create Machine                  ${QSPI_XIP}  qspi
    # This sample is built for STM32 Evaluation Kit, which uses the same SoC but has a bit different HW - we only care about LEDs to signal test status
    Execute Command                 machine LoadPlatformDescriptionFromString ${EVAL_STUB}
    Execute Command                 machine LoadPlatformDescriptionFromString ${EXTERNAL_FLASH}

    ${led3_tester}=                 Create LED Tester   sysbus.gpioPortA.led3     defaultTimeout=1
    ${led1_tester}=                 Create LED Tester   sysbus.gpioPortF.led1     defaultTimeout=1

    # Wait for drivers to configure GPIO
    Assert LED State                false    testerId=${led3_tester}     timeout=20  pauseEmulation=true
    Assert LED State                false    testerId=${led1_tester}                 pauseEmulation=true

    # If the LEDs turned on, it means that the code relocated to QSPI memory is being executed
    Assert LED State                true     testerId=${led1_tester}     timeout=10  pauseEmulation=true
    Assert LED State                true     testerId=${led3_tester}                 pauseEmulation=true

    # Get out of GPIO init functions, which are located in regular memory
    # and step into infinite spin-loop in the QSPI memory
    Execute Command                 emulation RunFor "00:00:00.01"
    # QSPI memory starts at:        0x90000000
    Assert PC Equals                0x90000010

Should Read Correct Time From the PTP Clock
    Create PTP Machine              ${PTP}  ptp
    Create Terminal Tester          ${UART}  defaultPauseEmulation=True
    # Use AdvanceImmediately to make the RunFor take less real time
    Execute Command                 emulation SetGlobalAdvanceImmediately true

    Wait For Line On Uart           ptp_port: ptp_port_init: Port 1 initialized
    Wait For Prompt On Uart         uart:~$
    Write Line To Uart              ptp_clock set PTP_CLOCK 25
    Write Line To Uart              ptp_clock get PTP_CLOCK
    Wait For Line On Uart           25.00
    Execute Command                 emulation RunFor "7.48s"
    Write Line To Uart              ptp_clock get PTP_CLOCK
    Wait For Line On Uart           32.48

Should Transmit PTP Frames
    Create PTP Machine              ${PTP}  ptp
    Create Terminal Tester          ${UART}  defaultPauseEmulation=True
    Create Network Interface Tester  sysbus.ethernet

    Wait For Line On Uart           ptp_port: ptp_port_init: Port 1 initialized

    Start Emulation

    FOR  ${i}  IN RANGE  0  3
        # Wait for a PTP Sync message over UDP from 192.0.2.1:319 to 224.0.1.129:319
        Wait For Outgoing Packet With Bytes At Index  0800__________________11____C0000201E0000181013F013F________0012  12  5  10
        # Wait for a PTP Follow_Up message over UDP from 192.0.2.1:320 to 224.0.1.129:320 - which should be the next transmitted packet
        ${follow_up}=                   Wait For Outgoing Packet With Bytes At Index  0800__________________11____C0000201E000018101400140________0812  12  1  1

        ${packet_seconds}=              Extract Int From Bytes  ${follow_up.Bytes}  76  count=6
        ${packet_nanoseconds}=          Extract Int From Bytes  ${follow_up.Bytes}  82  count=4
        ${packet_milliseconds}=         Evaluate  (${packet_seconds} * 10**9 + ${packet_nanoseconds}) / 10**6

        # Emulation time and the packet timestamp should be within 100ms of one another (100ms is to account for board initialization)
        Should Be True                  abs(${packet_milliseconds} - ${follow_up.Timestamp}) < 100
    END

Should Encrypt And Decrypt Using DMA
    Create Machine                      ${CRYPTO_AES_DMA}  crypt
    Execute Command                     machine LoadPlatformDescriptionFromString ${EVAL_STUB}

    ${led3_tester}=                     Create LED Tester   sysbus.gpioPortA.led3     defaultTimeout=1
    ${led1_tester}=                     Create LED Tester   sysbus.gpioPortF.led1     defaultTimeout=1

    # LED3 would be set if at any point of the test a failure occurred
    # LED1 is set at the very end of the test, when the entire procedure is complete with no failures
    Assert LED State                    false    testerId=${led3_tester}
    Assert LED State                    true     testerId=${led1_tester}

Should Erase And Program Flash Memory
    Create Machine                      ${FLASH_EraseProgram}  flash
    Execute Command                     machine LoadPlatformDescriptionFromString ${EVAL_STUB}

    ${led3_tester}=                     Create LED Tester   sysbus.gpioPortA.led3     defaultTimeout=1
    ${led1_tester}=                     Create LED Tester   sysbus.gpioPortF.led1     defaultTimeout=1

    # LED3 would be set if at any point of the test a failure occurred
    # LED1 is set at the very end of the test, when the entire procedure is complete with no failures
    Assert LED State                    false    testerId=${led3_tester}
    Assert LED State                    true     testerId=${led1_tester}
