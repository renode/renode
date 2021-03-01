*** Settings ***
Suite Setup                     Setup
Suite Teardown                  Teardown
Test Setup                      Reset Emulation
Test Teardown                   Test Teardown
Resource                        ${RENODEKEYWORDS}

*** Variables ***
${UART}                         sysbus.uart

${LEDS}=    SEPARATOR=
...  """                                     ${\n}
...  gpio:                                   ${\n}
...  ${SPACE*4}8 -> led0@0                   ${\n}
...  ${SPACE*4}9 -> led1@0                   ${\n}
...  ${SPACE*4}10 -> led2@0                  ${\n}
...  ${SPACE*4}11 -> led3@0                  ${\n}
...  ${SPACE*4}12 -> led4@0                  ${\n}
...  ${SPACE*4}13 -> led5@0                  ${\n}
...  ${SPACE*4}14 -> led6@0                  ${\n}
...  ${SPACE*4}15 -> led7@0                  ${\n}
...                                          ${\n}
...  led0: Miscellaneous.LED @ gpio 8        ${\n}
...  led1: Miscellaneous.LED @ gpio 9        ${\n}
...  led2: Miscellaneous.LED @ gpio 10       ${\n}
...  led3: Miscellaneous.LED @ gpio 11       ${\n}
...  led4: Miscellaneous.LED @ gpio 12       ${\n}
...  led5: Miscellaneous.LED @ gpio 13       ${\n}
...  led6: Miscellaneous.LED @ gpio 14       ${\n}
...  led7: Miscellaneous.LED @ gpio 15       ${\n}
...  """

*** Keywords ***
Setup Machine
    Execute Command             include @scripts/single-node/opentitan-earlgrey.resc
    Execute Command             machine LoadPlatformDescriptionFromString ${LEDS}

    Create Terminal Tester      ${UART}
    Set Default Uart Timeout    1

*** Test Cases ***
Should Print To Uart
    Setup Machine
    Start Emulation

    Wait For Line On Uart       The LEDs show the ASCII code of the last character.

    Provides                    initialization

Should Echo On Uart
    Requires                    initialization

    Write Line To Uart          Testing testing 1-2-3

    Provides                    working-uart

Should Display Output on GPIO
    Requires                    working-uart

    Execute Command             emulation CreateLEDTester "led0" sysbus.gpio.led0
    Execute Command             emulation CreateLEDTester "led1" sysbus.gpio.led1
    Execute Command             emulation CreateLEDTester "led2" sysbus.gpio.led2
    Execute Command             emulation CreateLEDTester "led3" sysbus.gpio.led3

    Execute Command             emulation CreateLEDTester "led4" sysbus.gpio.led4
    Execute Command             emulation CreateLEDTester "led5" sysbus.gpio.led5
    Execute Command             emulation CreateLEDTester "led6" sysbus.gpio.led6
    Execute Command             emulation CreateLEDTester "led7" sysbus.gpio.led7

    Send Key To Uart            0x0

    Execute Command             led0 AssertState false 0.2
    Execute Command             led1 AssertState false 0.2
    Execute Command             led2 AssertState false 0.2
    Execute Command             led3 AssertState false 0.2

    Execute Command             led4 AssertState false 0.2
    Execute Command             led5 AssertState false 0.2
    Execute Command             led6 AssertState false 0.2
    Execute Command             led7 AssertState false 0.2

    Write Char On Uart          B
    # B is 0100 0010

    Execute Command             led0 AssertState false 0.2
    Execute Command             led1 AssertState true 0.2
    Execute Command             led2 AssertState false 0.2
    Execute Command             led3 AssertState false 0.2

    Execute Command             led4 AssertState false 0.2
    Execute Command             led5 AssertState false 0.2
    Execute Command             led6 AssertState true 0.2
    Execute Command             led7 AssertState false 0.2
