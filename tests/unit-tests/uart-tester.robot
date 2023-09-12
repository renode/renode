*** Keywords ***
Create Machine
    Execute Command          i @scripts/single-node/sifive_fe310.resc

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
