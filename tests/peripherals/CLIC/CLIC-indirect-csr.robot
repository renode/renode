*** Variables ***
${UART}                       sysbus.uart

*** Keywords ***
Create Machine
    Execute Command           mach create
    Execute Command           using sysbus
    Execute Command           machine LoadPlatformDescription @tests/peripherals/CLIC/CLIC-test-platform.repl

*** Test Cases ***
Registers Should Be Accessible Through Indirect CSRs
    Create Machine
    Execute Script            ${CURDIR}/CLIC-indirect-csr-binary.resc
    Execute Command           cpu PC 0x80000000
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     OK
