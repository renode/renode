*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode

*** Keywords ***
Should Run Detection
    Wait For Line On Uart           Attempting to start Arducam
    Wait For Line On Uart           Starting capture
    Wait For Line On Uart           Image captured
    Wait For Line On Uart           Reading \\d+ bytes from Arducam                   treatAsRegex=true
    Wait For Line On Uart           Finished reading
    Wait For Line On Uart           Decoding JPEG and converting to greyscale
    Wait For Line On Uart           Image decoded and processed
    ${l}=  Wait For Line On Uart    Person score: (\\d+) No person score: (\\d+)      treatAsRegex=true
    ${s}=  Evaluate                 int(${l.Groups[0]}) - int(${l.Groups[1]})

    RETURN                          ${s}

Run Test
    [Arguments]                     ${image}

    Execute Command                 Clear
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/boards/arduino_nano_33_ble.repl
    Execute Command                 sysbus LoadELF ${URI}/nrf52840--tf_person_detection.elf-s_7574264-cf1fccf46719c4a60e0df957a1304f17c5647011

    Create Terminal Tester          sysbus.uart0
    Execute Command                 sysbus.spi2.camera ImageSource @${image}
    Start Emulation

Detect Template
    [Arguments]         ${image}

    Run Test            ${image}
    ${r}=  Should Run Detection
    Should Be True                  ${r} > 100

No Detect Template
    [Arguments]         ${image}

    Run Test            ${image}
    ${r}=  Should Run Detection
    Should Be True                  ${r} < -100

*** Test Cases ***
Should Detect Person
    [Template]                      Detect Template

    ${URI}/images/person_image_0.jpg-s_3853-7f2125e28423fa117a1079d84785b17c9b70f62d
    ${URI}/images/person_image_1.jpg-s_3836-25216268e08894d0dda13107ad1ad5f537ad19c2

Should Not Detect Person
    [Template]                      No Detect Template

    ${URI}/images/no_person_image_0.jpg-s_3787-3bed5184fbf005cbb0b6bf18e8885874ca7273bd
    ${URI}/images/no_person_image_1.jpg-s_3910-81edff305382b42f3b98e3764921574e1b9142fe

