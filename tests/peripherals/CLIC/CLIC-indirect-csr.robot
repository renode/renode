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
    Execute Command           sysbus LoadELF @tests/peripherals/CLIC/binaries/clic_indirect_csr-01.elf
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     OK
