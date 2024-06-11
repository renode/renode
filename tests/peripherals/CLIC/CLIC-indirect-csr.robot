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
    Execute Command           sysbus LoadELF @https://dl.antmicro.com/projects/renode/clic/clic_indirect_csr-01.elf-s_6164-08ee198d10e7c86b0cf15f54a4c90cfa2f6cd5f8
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     OK
