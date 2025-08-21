*** Variables ***
${UART}                       sysbus.uart
${SCRIPT_ZEPHYR}              @scripts/single-node/up_squared_x86_64_zephyr.resc

*** Keywords ***
Create Machine
    Execute Command           include ${SCRIPT_ZEPHYR}
    Create Terminal Tester    ${UART}

*** Test Cases ***
Should Run Zephyr hello_world Sample
    Create Machine

    Wait For Line On Uart     Hello World! up_squared

Should Not Use Dirty Addresses
    Create Machine

    # The log below is on Debug level and can be from any core.
    Create Log Tester         0
    Execute Command           logLevel 0 cpu0
    Execute Command           logLevel 0 cpu1

    Wait For Line On Uart     Hello World! up_squared

    # X86_64 doesn't currently use these addresses, this makes sure they aren't added either.
    Should Not Be In Log      Attempted reduction of x86_64 dirty addresses list failed
