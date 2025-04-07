*** Keywords ***
Create Machine
    Execute Command          i @scripts/single-node/sifive_fe310.resc

Create Tock Machine
    Execute Command          i @scripts/single-node/stm32f4_tock.resc

Create Trivial Machine
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString "uart0: UART.TrivialUart @ sysbus 0x1000"

Write Bytes To Trivial Uart
    [Arguments]              ${bytes}

    # Just @{bytes} does not work as $bytes is not list or list-like.
    # It does work for str though, just not bytes.
    FOR  ${byte}  IN  @{{[b for b in $bytes]}}
        Execute Command      sysbus.uart0 WriteDoubleWord 0 ${byte}
    END

*** Test Cases ***
Should Fail On Non-Existing UART
    Create Machine
    Run Keyword And Expect Error
    ...   *not found or of wrong type*
    ...   Create Terminal Tester  sysbus.non_existing_uart

Should Not Require Tester Id When Single Tester
    Create Machine
    Create Terminal Tester  sysbus.uart0

    Wait For Line On Uart   ZEPHYR

Should Require Tester Id When Two Testers
    Create Machine
    Create Terminal Tester  sysbus.uart0
    Create Terminal Tester  sysbus.uart1

    Run Keyword And Expect Error
    ...   *There is more than one tester available*
    ...   Wait For Line On Uart   ZEPHYR

Should Respect Tester Id In The Keyword When Two Testers
    Create Machine
    ${u0}=  Create Terminal Tester  sysbus.uart0
    ${u1}=  Create Terminal Tester  sysbus.uart1

    Wait For Line On Uart   ZEPHYR    testerId=${u0}

Should Respect The Default Tester Id
    Create Machine
    ${u0}=  Create Terminal Tester  sysbus.uart0
    ${u1}=  Create Terminal Tester  sysbus.uart1
    Set Default Tester      ${u0}

    Wait For Line On Uart   ZEPHYR

Should Use Tester Id Selected By Keyword
    Create Machine
    ${u0}=  Create Terminal Tester  sysbus.uart0
    ${u1}=  Create Terminal Tester  sysbus.uart1
    Set Default Tester      ${u1}

    Wait For Line On Uart   ZEPHYR   testerId=${u0}

Should Respect The Default Tester Id 2
    Create Machine
    ${u0}=  Create Terminal Tester  sysbus.uart0
    ${u1}=  Create Terminal Tester  sysbus.uart1
    Set Default Tester      ${u1}

    Run Keyword And Expect Error
    ...   *Terminal tester failed!*
    ...   Wait For Line On Uart   ZEPHYR  timeout=1

Should Overwrite The Default Tester Id
    Create Machine
    ${u0}=  Create Terminal Tester  sysbus.uart0
    ${u1}=  Create Terminal Tester  sysbus.uart1
    Set Default Tester      ${u1}
    Set Default Tester      ${u0}

    Wait For Line On Uart   ZEPHYR

Should Allow To Clear The Default Tester Id
    Create Machine
    ${u0}=  Create Terminal Tester  sysbus.uart0
            Create Terminal Tester  sysbus.uart1

    Set Default Tester      ${u0}
    Set Default Tester      null

    Run Keyword And Expect Error
    ...   *There is more than one tester available*
    ...   Wait For Line On Uart   ZEPHYR

Should Not Allow Waiting For Byte String On A Tester Not Created In Binary Mode
    Create Machine
    Create Terminal Tester  sysbus.uart0  defaultPauseEmulation=true

    Run Keyword And Expect Error
    ...   *Attempt to wait for bytes on a tester configured in text mode*
    ...   Wait For Bytes On Uart  59 52 20 4f 53  timeout=1

Should Not Allow Waiting For Text String On A Tester Created In Binary Mode
    Create Machine
    Create Terminal Tester  sysbus.uart0  defaultPauseEmulation=true  binaryMode=true

    Run Keyword And Expect Error
    ...   *Attempt to wait for text on a tester configured in binary mode*
    ...   Wait For Line On Uart  ZEPHYR  timeout=1

Should Allow Waiting For Byte String Spanning Lines
    Create Machine
    Create Terminal Tester  sysbus.uart0  defaultPauseEmulation=true  binaryMode=true

    # ****\r\nsh
    Wait For Bytes On Uart  2a 2a 2a 2a 0d 0a 73 68

Should Allow Waiting For Immediately Adjacent Byte Strings
    Create Machine
    Create Terminal Tester  sysbus.uart0  defaultPauseEmulation=true  binaryMode=true

    # ZEPHYR
    Wait For Bytes On Uart  5a 45 50 48 59 52

    # R OS, making sure the characters from ZEPHYR have left the match window
    Run Keyword And Expect Error
    ...   *Terminal tester failed*
    ...   Wait For Bytes On Uart  52 20 4f 53  timeout=1

    # ****\r\nsh
    Wait For Bytes On Uart  2a 2a 2a 2a 0d 0a 73 68  timeout=0

    # ell
    Wait For Bytes On Uart  65 6c 6c  timeout=0

Should Allow Waiting For Byte String At Start
    Create Machine
    Create Terminal Tester  sysbus.uart0  defaultPauseEmulation=true  binaryMode=true

    # ZEPHYR
    Wait For Bytes On Uart  5a 45 50 48 59 52

    # OS, want at start (but there's a space in the way, so no match)
    Run Keyword And Expect Error
    ...   *Terminal tester failed*
    ...   Wait For Bytes On Uart  4f 53  timeout=1  matchStart=true

    # And now with the space, which should match (" OS")
    Wait For Bytes On Uart  20 4f 53  timeout=0  matchStart=true

Should Allow Waiting For Byte String Containing All Byte Values
    Create Trivial Machine
    Create Terminal Tester  sysbus.uart0  binaryMode=true

    ${bytes}=  Evaluate     bytes(range(2**8))
    Write Bytes To Trivial Uart  ${bytes}

    # Exact match required
    ${m}=  Wait For Bytes On Uart  ${{$bytes.hex()}}  matchStart=true
    Should Be Equal         ${m.Content}  ${bytes}

Should Allow Waiting For Byte String Containing All Byte Values As Regex
    Create Trivial Machine
    Create Terminal Tester  sysbus.uart0  binaryMode=true

    ${bytes}=  Evaluate     bytes(range(2**8))
    # Queue it up 3 times and then let's match each repetition in a different way
    FOR  ${i}  IN RANGE  3
        Write Bytes To Trivial Uart  ${bytes}
    END

    # First one verbatim (might as well not have used a regex)
    ${bytes_re}=  Evaluate  "".join(rf"\\x{b:02x}" for b in $bytes)
    ${m}=  Wait For Bytes On Uart  ${bytes_re}  matchStart=true  treatAsRegex=true
    Should Be Equal         ${m.Content}  ${bytes}

    # Note that due to how the tester works (evaluating the pattern after every byte written)
    # if the entire string hadn't already been printed at assertion time then the ? would not
    # be required for a non-greedy match
    ${m}=  Wait For Bytes On Uart  \\x00.*?\\xff  matchStart=true  treatAsRegex=true
    Should Be Equal         ${m.Content}  ${bytes}

    # And now with some groups
    ${m}=  Wait For Bytes On Uart  (\\x11.*)\\x41.*?([\\x50-\\x5f]+).*?\\xfd  treatAsRegex=true
    Should Be Equal         ${m.Content}  ${{$bytes[0x11:-2]}}
    Should Be Equal         ${m.Groups[0]}  ${{bytes(range(0x11, 0x41))}}
    Should Be Equal         ${m.Groups[1]}  ${{bytes(range(0x50, 0x60))}}

Should Fail On Failing String
    Create Tock Machine

    Create Terminal Tester          sysbus.usart2
    Register Failing Uart String    Entering.*loop  treatAsRegex=true

    Run Keyword And Expect Error
    ...                             *Test failing entry*
    ...                             Wait For Line On Uart  D2

Should Fail On Failing String On Specific Tester
    Create Tock Machine

    ${tester1}=                     Create Terminal Tester  sysbus.usart3
    ${tester2}=                     Create Terminal Tester  sysbus.usart2
    Register Failing Uart String    D1  testerId=${tester2}

    Run Keyword And Expect Error
    ...                             *Test failing entry*
    ...                             Wait For Line On Uart  D1  testerId=${tester2}

Should Unregister Failing String
    Create Tock Machine

    Create Terminal Tester          sysbus.usart2

    Register Failing Uart String    D1
    Unregister Failing Uart String  D1

    Wait For Line On Uart           D1
