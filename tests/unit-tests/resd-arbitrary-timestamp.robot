*** Variables ***
${bin}             @https://dl.antmicro.com/projects/renode/stm32l07--zephyr-shell_module.elf-s_1195760-e9474da710aca88c89c7bddd362f7adb4b0c4b70
${CSV2RESD}        ${RENODETOOLS}/csv2resd/csv2resd.py
# Sample CSV contains a 'version' string with each letter as a separate sample delayed by 100ms
${SAMPLES_CSV}     ${RENODETOOLS}/../tests/unit-tests/resd-uart-sample.csv

${UART}            sysbus.usart2
${UART_FEEDER}     uartFeeder
${UART_HUB}        uartHub

*** Keywords ***
Create Machine With UARTHub And UARTRESDFeeder
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            include @platforms/cpus/stm32l071.repl

    Execute Command            machine CreateUARTRESDFeeder "${UART_FEEDER}"

Create Machine
    Create Machine With UARTHub And UARTRESDFeeder
    Create Terminal Tester          ${UART}
    Execute Command                 sysbus LoadELF ${bin}

# Must be run after software configures UART
Setup UARTRESDFeeder
    ${baud_rate}=              Execute Command    ${UART} BaudRate
    Execute Command            uartFeeder BaudRate ${baud_rate}
    ${parity_bit}=             Execute Command    ${UART} ParityBit
    Execute Command            uartFeeder ParityBit ${parity_bit}
    ${stop_bits}=              Execute Command    ${UART} StopBits
    Execute Command            uartFeeder StopBits ${stop_bits}
    Execute Command            uartFeeder Echo False

Create UARTHub With UARTRESDFeeder
    Setup UARTRESDFeeder
    Execute Command            emulation CreateUARTHub "${UART_HUB}"
    Execute Command            connector Connect ${UART} ${UART_HUB}
    Execute Command            connector Connect ${UART_FEEDER} ${UART_HUB}

Emulation Should Be Paused
    ${st}=                          Execute Command  emulation IsStarted
    Should Contain                  ${st}  False

Emulation Should Be Paused At Time
    [Arguments]                     ${time}
    Emulation Should Be Paused
    ${ts}=                          Execute Command  machine GetTimeSourceInfo
    Should Contain                  ${ts}  Elapsed Virtual Time: ${time}

Wait For Uart Prompt At Viartual Time
    [Arguments]                     ${prompt}    ${time}
    Wait For Prompt On Uart         ${prompt}    pauseEmulation=true
    Emulation Should Be Paused At Time    ${time}

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "BINARY_DATA:uart_size,uart_data:size,data"
    ...                             "--start-time", "0"
    ...                             "--timestamp", "timestamp"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***
Should Print To UART In One Second
    Create Machine

    Execute Command                 emulation RunFor "1.0"
    Wait For Uart Prompt At Viartual Time    uart:~$    00:00:01.00

    Create UARTHub With UARTRESDFeeder

    Provides                        initialized-zephyr

Should Deliver RESD Samples Precisely Starting From CurrentVirtualTime
    Requires                        initialized-zephyr
    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}
    
    Execute Command                 ${UART_FEEDER} FeedDataFromRESD @${resd_path} Normal 0 CurrentVirtualTime

    Wait For Uart Prompt At Viartual Time    v    00:00:01.10
    Wait For Uart Prompt At Viartual Time    e    00:00:01.20
    Wait For Uart Prompt At Viartual Time    r    00:00:01.30
    Wait For Uart Prompt At Viartual Time    s    00:00:01.40
    Wait For Uart Prompt At Viartual Time    i    00:00:01.50
    Wait For Uart Prompt At Viartual Time    o    00:00:01.60
    Wait For Uart Prompt At Viartual Time    n    00:00:01.70

    Wait For Prompt On Uart         Zephyr version 2

Should Deliver RESD Samples Precisely Starting From Specified Offset
    Requires                        initialized-zephyr
    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}

    # Start to deliver samples according to timestamps with a delay of 2 seconds
    Execute Command                 ${UART_FEEDER} FeedDataFromRESD @${resd_path} Normal 0 Specified -2000000000

    Wait For Uart Prompt At Viartual Time    v    00:00:02.10
    Wait For Uart Prompt At Viartual Time    e    00:00:02.20
    Wait For Uart Prompt At Viartual Time    r    00:00:02.30
    Wait For Uart Prompt At Viartual Time    s    00:00:02.40
    Wait For Uart Prompt At Viartual Time    i    00:00:02.50
    Wait For Uart Prompt At Viartual Time    o    00:00:02.60
    Wait For Uart Prompt At Viartual Time    n    00:00:02.70

    Wait For Prompt On Uart         Zephyr version 2
