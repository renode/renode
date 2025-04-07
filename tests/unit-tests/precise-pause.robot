*** Keywords ***
Create Machine With Button And LED
    [Arguments]              ${firmware}  ${usart}=2  ${button_port}=B  ${button_pin}=2  ${led_port}=A  ${led_pin}=5
    IF  "${firmware}" == "button"
        Execute Command          $bin = @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-button.elf-s_402204-2343dc7268dedc253893a84300f3dbd02bc63a2a
    ELSE IF  "${firmware}" == "blinky"
        Execute Command          $bin = @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-blinky.elf-s_395652-4d2c6106335435629d3611d2a732e37ca9f17eeb
    ELSE IF  "${firmware}" == "led_shell"
        Execute Command          $bin = @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-led_shell.elf-s_1471160-5398b2ac0ab1c71ec144eba55f4840d86ddb921a
    ELSE IF  "${firmware}" == "pwm_shell"
        Execute Command          $bin = @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-custom_shell_pwm.elf-s_884872-f36f63ef9435aaf89f37922d3c78428c52be1320
    ELSE
        Fail                     Unknown firmware '${firmware}'
    END
    Execute Command          include @scripts/single-node/stm32l072.resc
    Execute Command          machine LoadPlatformDescriptionFromString "gpioPort${led_port}: { ${led_pin} -> led@0 }; led: Miscellaneous.LED @ gpioPort${led_port} ${led_pin}"
    Execute Command          machine LoadPlatformDescriptionFromString "button: Miscellaneous.Button @ gpioPort${button_port} ${button_pin} { invert: true; -> gpioPort${button_port}@${button_pin} }"

    Create Terminal Tester   sysbus.usart${usart}
    Create LED Tester        sysbus.gpioPort${led_port}.led  defaultTimeout=2

Create Machine With Trivial Uart
    ${platform}=             Catenate  SEPARATOR=${\n}
    ...  """
    ...  cpu: CPU.ARMv7R @ sysbus
    ...  ${SPACE*4}cpuType: "cortex-r8"
    ...  mem: Memory.MappedMemory @ sysbus 0x0
    ...  ${SPACE*4}size: 0x400
    ...  uart: UART.TrivialUart @ sysbus <0x1000, +0x100>
    ...  """
    Execute Command          using sysbus
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString ${platform}

Emulation Should Be Paused
    ${st}=                   Execute Command  emulation IsStarted
    Should Contain           ${st}  False

Emulation Should Be Paused At Time
    [Arguments]              ${time}
    Emulation Should Be Paused
    ${ts}=                   Execute Command  machine GetTimeSourceInfo
    Should Contain           ${ts}  Elapsed Virtual Time: ${time}

Emulation Should Not Be Paused
    ${st}=                   Execute Command  emulation IsStarted
    Should Contain           ${st}  True

*** Test Cases ***
Terminal Tester Assert Should Start Emulation
    Create Machine With Button And LED  button

    Emulation Should Be Paused

    Wait For Line On Uart    Press the button

    Emulation Should Not Be Paused

Terminal Tester Idle Assert Should Start Emulation
    # We attach the tester to usart1 because nothing is printed to it
    Create Machine With Button And LED  button  usart=1

    Emulation Should Be Paused

    Test If Uart Is Idle     2

    Emulation Should Not Be Paused

Terminal Tester Assert Should Not Start Emulation If Matching String Has Already Been Printed
    Create Machine With Button And LED  button

    # Give the sample plenty of virtual time to print the string
    Execute Command          emulation RunFor "0.1"

    Emulation Should Be Paused At Time  00:00:00.100000

    Provides                 string-printed-without-assert

    Wait For Line On Uart    Press the button

    Emulation Should Be Paused At Time  00:00:00.100000

Terminal Tester Assert Should Not Start Emulation With Timeout 0
    Requires                 string-printed-without-assert

    Run Keyword And Expect Error  *Terminal tester failed*  Wait For Line On Uart  String that was not printed  timeout=0

    Emulation Should Be Paused At Time  00:00:00.100000

Terminal Tester Assert Should Precisely Pause Emulation
    [Tags]                   instructions_counting
    Create Machine With Button And LED  button

    Wait For Line On Uart    Press the button  pauseEmulation=true

    Execute Command          gpioPortB.button Press

    ${l}=                    Wait For Line On Uart  Button pressed at (\\d+)  pauseEmulation=true  treatAsRegex=true
    Should Be Equal          ${l.Groups[0]}  4897

    Emulation Should Be Paused At Time  00:00:00.000226
    PC Should Be Equal       0x8002c0a  # this is the next instruction after STR that writes to TDR in LL_USART_TransmitData8

Emulation Should Pause Precisely Between Translation Blocks
    [Tags]                   instructions_counting
    Create Machine With Button And LED  button
    # Forcing all blocks to contain a single instruction will force the precise pauses to be handled between blocks
    Execute Command          cpu MaximumBlockSize 1

    Wait For Line On Uart    Press the button  pauseEmulation=true

    Execute Command          gpioPortB.button Press

    ${l}=                    Wait For Line On Uart  Button pressed at (\\d+)  pauseEmulation=true  treatAsRegex=true
    Should Be Equal          ${l.Groups[0]}  4215

    Emulation Should Be Paused At Time  00:00:00.000226
    PC Should Be Equal       0x8002c0a  # this is the next instruction after STR that writes to TDR in LL_USART_TransmitData8

Quantum Should Not Impact Tester Pause PC
    Create Machine With Button And LED  button
    Execute Command          emulation SetGlobalQuantum "0.010000"

    Wait For Line On Uart    Press the button  pauseEmulation=true

    Execute Command          gpioPortB.button Press

    Wait For Line On Uart    Button pressed at (\\d+)  pauseEmulation=true  treatAsRegex=true

    PC Should Be Equal       0x8002c0a

RunFor Should Work After Precise Pause
    Create Machine With Button And LED  button

    Wait For Line On Uart    Press the button  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:00.000179

    Execute Command          emulation RunFor "0.1"
    Emulation Should Be Paused At Time  00:00:00.100179

LED Tester Assert Should Start Emulation Unless The State Already Matches
    Create Machine With Button And LED  blinky

    # The LED state is false by default on reset because it is not inverted, so this assert
    # should pass immediately without starting the emulation
    Assert LED State         false
    Emulation Should Be Paused At Time  00:00:00.000000

    # And this one should start the emulation
    Assert LED State         true
    Emulation Should Not Be Paused

LED Tester Assert Should Not Start Emulation With Timeout 0
    Create Machine With Button And LED  blinky

    # The LED state is false by default, so this assert should fail immediately without
    # starting the emulation because the timeout is 0
    Run Keyword And Expect Error  *LED assertion not met*  Assert LED State  true  0

    Emulation Should Be Paused At Time  00:00:00.000000

LED Tester Assert Should Precisely Pause Emulation
    [Tags]                   instructions_counting
    Create Machine With Button And LED  blinky

    Assert LED State         true  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:00.000115
    PC Should Be Equal       0x8002a48  # this is the next instruction after STR that writes to BSRR in gpio_stm32_port_set_bits_raw

    Assert LED State         false  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:01.000157
    PC Should Be Equal       0x80028a4  # this is the next instruction after STR that writes to BRR in LL_GPIO_ResetOutputPin

    Provides                 synced-blinky

LED Tester Assert And Hold Should Precisely Pause Emulation
    [Tags]                   instructions_counting
    Requires                 synced-blinky

    # The expected times have 3 decimal places because the default quantum is 0.000100
    ${state}=                Set Variable  False
    FOR  ${i}  IN RANGE  2  5
        Assert And Hold LED State  ${state}  timeoutAssert=1  timeoutHold=1  pauseEmulation=true
        Emulation Should Be Paused At Time  00:00:0${i}.000
        ${state}=                Evaluate  not ${state}
    END

LED Tester Assert Is Blinking Should Precisely Pause Emulation
    [Tags]                   instructions_counting
    Requires                 synced-blinky

    Assert LED Is Blinking   testDuration=5  onDuration=1  offDuration=1  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:06.000200

LED Tester Assert Duty Cycle Should Precisely Pause Emulation
    [Tags]                   instructions_counting
    Requires                 synced-blinky

    Assert LED Duty Cycle    testDuration=5  expectedDutyCycle=0.5  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:06.000200

LED And Terminal Testers Should Cooperate
    Create Machine With Button And LED  led_shell

    Wait For Prompt On Uart  $  pauseEmulation=true
    Write Line To Uart       led on leds 0  waitForEcho=false
    Wait For Line On Uart    leds: turning on LED 0  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:00.001239
    PC Should Be Equal       0x800b26c
    # The LED should not be turned on yet: the string is printed before actually changing the GPIO
    Assert LED State         false  0

    # Now wait for the LED to turn on
    Assert LED State         true  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:00.001243
    PC Should Be Equal       0x800af0c

LED Tester Assertion Triggered By PWM Should Not Log Errors
    Create Log Tester        0
    Create Machine With Button And LED  pwm_shell  led_port=B  led_pin=10

    ${pwm}=  Wait For Line On Uart  pwm device: (\\w+)  treatAsRegex=true  pauseEmulation=true
    ${pwm}=  Set Variable    ${pwm.Groups[0]}

    Write Line To Uart       pwm cycles ${pwm} 3 256 127  pauseEmulation=true
    Wait For Prompt On Uart  $  pauseEmulation=true

    # The LED state is true at this point, so this will wait for it to turn off
    Assert LED State         false  pauseEmulation=true

    # There should be a warning but no errors
    Wait For Log Entry       Failed to restart translation block for precise pause  keep=true
    Should Not Be In Log     ${EMPTY}  level=Error

Log Tester Assert Should Precisely Pause Emulation
    [Tags]                   instructions_counting
    Create Log Tester        5
    Create Machine With Button And LED  pwm_shell  led_port=B  led_pin=10

    ${pwm}=  Wait For Line On Uart  pwm device: (\\w+)  treatAsRegex=true  pauseEmulation=true
    ${pwm}=  Set Variable    ${pwm.Groups[0]}

    Write Line To Uart       pwm cycles ${pwm} 3 256 127  waitForEcho=false

    Provides                 waiting-for-unhandled-write-log

    Wait For Log Entry       Unhandled write to offset 0x1C.  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:00.001297

    Provides                 paused-at-log-assertion

Log Tester Should Not Be In Log Assert Should Precisely Pause Emulation
    Requires                 paused-at-log-assertion

    Should Not Be In Log     No such random message in log  timeout=2  pauseEmulation=true
    # The time gets rounded to the sync point
    Emulation Should Be Paused At Time  00:00:02.001300

Log Tester Should Not Be In Log Assert Should Not Pause Emulation Later If The Matching String Actually Gets Logged
    Requires                 waiting-for-unhandled-write-log

    Run Keyword And Expect Error  *Unexpected line detected in the log*  Should Not Be In Log  Unhandled write to offset 0x1C.  timeout=2  pauseEmulation=true
    Emulation Should Be Paused At Time  00:00:00.001297

    Execute Command  emulation RunFor "3"
    Emulation Should Be Paused At Time  00:00:03.001297

Should Finish Instructions Before Pausing
    Create Machine With Trivial Uart
    Create Terminal Tester   sysbus.uart  defaultPauseEmulation=true

    Execute Command          cpu SetRegister 0 0x1000  # UART write address
    Execute Command          cpu SetRegister 1 0x4F  # 'O'
    Execute Command          cpu SetRegister 2 0x6E  # 'n'
    Execute Command          cpu SetRegister 3 0x65  # 'e'
    Execute Command          cpu SetRegister 4 0x0A  # '\n'
    Execute Command          cpu SetRegister 5 0x54  # 'T'
    Execute Command          cpu SetRegister 6 0x77  # 'w'
    Execute Command          cpu SetRegister 7 0x6F  # 'o'
    Execute Command          cpu SetRegister 8 0x0A  # '\n'

    Execute Command          sysbus WriteDoubleWord 0x10 0xE8A001FE  # stm r0!, {r1-r8}
    Execute Command          cpu PC 0x10

    Wait For Line On Uart    One
    # This string should already be present, as the instruction printing it should have finished successfully
    Wait For Line On Uart    Two  timeout=0  matchNextLine=true
    PC Should Be Equal       0x14
