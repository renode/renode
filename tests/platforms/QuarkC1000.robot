*** Variables ***
${CPU}                        sysbus.cpu
${UART}                       sysbus.uartB
${URI}                        @https://dl.antmicro.com/projects/renode
${SCRIPT}                     ${CURDIR}/../../scripts/single-node/quark_c1000.resc

*** Test Cases ***
Should Run Hello World
    [Documentation]           Runs Zephyr's 'hello_world' sample on Quark C1000 platform.
    [Tags]                    zephyr  uart
    Execute Command           $bin = ${URI}/hello_world.elf-s_314404-767e7a65942935de2abf276086957170847d99b5
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Start Emulation
    Wait For Line On Uart     Hello World! x86

Should Run Hello World With Sleep
    [Documentation]           Runs modified Zephyr's 'hello_world' sample on Quark C1000 platform. This one outputs 'Hello World! x86' on uart every 2 seconds.
    [Tags]                    zephyr  uart  interrupts
    Set Test Variable         ${SLEEP_TIME}                 2000
    Set Test Variable         ${SLEEP_TOLERANCE}            20
    Set Test Variable         ${REPEATS}                    5

    Execute Command           $bin = ${URI}/hello_world-with-sleep.elf-s_317148-a279de34d55b10c97720845fdf7e58bd42bb0477
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Start Emulation

    ${l}=               Create List
    ${MAX_SLEEP_TIME}=  Evaluate  ${SLEEP_TIME} + ${SLEEP_TOLERANCE}

    FOR  ${i}  IN RANGE  0  ${REPEATS}
         ${r}        Wait For Line On Uart     Hello World! x86
                     Append To List            ${l}  ${r.Timestamp}
    END

    FOR  ${i}  IN RANGE  1  ${REPEATS}
         ${i1}=  Get From List   ${l}                       ${i - 1}
         ${i2}=  Get From List   ${l}                       ${i}
         ${d}=   Evaluate        ${i2} - ${i1}
                 Should Be True  ${d} >= ${SLEEP_TIME}      Too short sleep detected between entries ${i} and ${i + 1}: expected ${SLEEP_TIME}, got ${d}
                 Should Be True  ${d} <= ${MAX_SLEEP_TIME}  Too long sleep detected between entires ${i} and ${i + 1}: expected ${SLEEP_TIME}, got ${d}
    END

Should Run Shell
    [Documentation]           Runs Zephyr's 'shell' sample on Quark C1000 platform.
    [Tags]                    zephyr  uart  interrupts
    Execute Command           $bin = ${URI}/shell.elf-s_392956-4b5bdd435f3d7c6555e78447438643269a87186b
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}  endLineOption=TreatCarriageReturnAsEndLine
    Start Emulation

    Wait For Prompt On Uart   shell>
    # this sleep here is to prevent against writing to soon on uart - it can happen under high stress of the host CPU - when an uart driver is not initalized which leads to irq-loop
    Sleep                     3
    Write Line To Uart        select sample_module
    Wait For Prompt On Uart   sample_module>
    Write Line To Uart        ping
    Wait For Line On Uart     pong

Should Handle Gpio Button
    [Documentation]           Runs Zephyr's 'basic/button' sample on Quark C1000 platform.
    [Tags]                    zephyr  uart  interrupts  gpio  button  non_critical
    Set Test Variable         ${WAIT_PERIOD}             2
    Execute Command           $bin = ${URI}/button.elf-s_317524-b42765dd760d0dd260079b99724aabec2b5cf34b
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     Press the user defined button on the board
    Test If Uart Is Idle      ${WAIT_PERIOD}
    Execute Command           gpio.button Toggle
    Test If Uart Is Idle      ${WAIT_PERIOD}
    Execute Command           gpio.button Toggle
    Wait For Line On Uart     Button pressed
    Test If Uart Is Idle      ${WAIT_PERIOD}
    Execute Command           gpio.button PressAndRelease
    Wait For Line On Uart     Button pressed

Should Read Sensor
    [Documentation]           Runs antmicro's 'sensor/lm74' sample on Quark C1000 platform.
    [Tags]                    zephyr  uart  lm74  temperature  sensor  spi
    Set Test Variable         ${SENSOR}             spi0.lm74

    Execute Command           $bin = ${URI}/lm74.elf-s_397752-47a08286be251887f15b378bd3c9f0d7829e1469
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     SPI Example application
    Wait For Line On Uart     Current temperature: 0.0
    Execute Command           ${SENSOR} Temperature 36
    Wait For Line On Uart     Current temperature: 36.0

Should Talk Over Network Using Ethernet
    [Documentation]           Runs Zephyr's 'net/echo' sample on Quark C1000 platform with external ENC28J60 ethernet module.
    [Tags]                    zephyr  uart  spi  ethernet  gpio
    Set Test Variable         ${REPEATS}             5

    Execute Command           emulation CreateSwitch "switch"
    Execute Command           $bin = ${URI}/echo_server.elf-s_684004-1ebf8c5dffefb95db60350692cf81fb7fd888869
    Execute Command           $name="quark-server"
    Execute Script            ${SCRIPT}
    Execute Command           connector Connect spi1.ethernet switch

    Execute Command           mach clear
    Execute Command           $bin = ${URI}/echo_client.elf-s_686384-fab5f2579652cf4bf16d68a456e6f6e4dbefbafa
    Execute Command           $name="quark-client"
    Execute Script            ${SCRIPT}
    Execute Command           connector Connect spi1.ethernet switch
    ${mach0_tester}=  Create Terminal Tester    ${UART}  machine=quark-server
    ${mach1_tester}=  Create Terminal Tester    ${UART}  machine=quark-client

    Start Emulation

    FOR  ${i}  IN RANGE  1  ${REPEATS}
        ${r}=  Evaluate  random.randint(1, 50)  modules=random
        RepeatKeyword  ${r}
        ...    Wait For Next Line On Uart  testerId=${mach0_tester}
    
        ${p}=  Wait For Line On Uart       build_reply_pkt: UDP IPv4 received (\\d+)    testerId=${mach0_tester}    treatAsRegex=true
        ${n}=  Wait For Next Line On Uart  testerId=${mach0_tester}
    
        Should Contain  ${n.Line}  pkt_sent: Sent ${p.Groups[0]} bytes
    END

    FOR  ${i}  IN RANGE  1  ${REPEATS}
        ${r}=  Evaluate  random.randint(1, 50)  modules=random
        RepeatKeyword  ${r}
        ...    Wait For Next Line On Uart  testerId=${mach1_tester}
    
        ${p}=  Wait For Line On Uart       udp_sent: IPv4: sent (\\d+)  testerId=${mach1_tester}    treatAsRegex=true
        ${n}=  Wait For Next Line On Uart  testerId=${mach1_tester}
    
        Should Contain  ${n.Line}  Compared ${p.Groups[0]} bytes, all ok
    END
