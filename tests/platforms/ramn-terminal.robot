*** Test Cases ***
Should Provide Started Platform
    [Documentation]         Boot the 4-ECU platform, configure testers, and snapshot

    Execute Command         include @scripts/multi-node/ramn.resc
    Execute Command         emulation RunFor "5s"
    Create Terminal Tester  sysbus.usb_uart  machine=ECUA  endLineOption=TreatCarriageReturnAsEndLine  defaultWaitForEcho=false
    Create CAN Tester       canHub  1

    Provides                post-startup

Should Print Version
    Requires                post-startup
    Write Line To Uart      V
    Wait For Line On Uart   V1 SLCAN R4MN  timeout=1

Should Forward CAN Messages
    Requires                post-startup
    Write Line To Uart      O
    # The forwarded messages all start with "t", so match on that just to see that there is traffic
    Wait For Line On Uart   t

Should Transmit CAN Message
    Requires                     post-startup
    # Writes a CAN frame with ID 0x42, DLC 2, data [0x11, 0xFF]. Id is a random unused one
    Write Line To Uart           t042211FF
    ${content}=                  Wait For Frame With Id  0x42  timeout=1
    Should Be Equal As Numbers   ${content[0]}  0x11
    Should Be Equal As Numbers   ${content[1]}  0xFF
