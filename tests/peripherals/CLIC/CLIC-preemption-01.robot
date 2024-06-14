*** Variables ***
${UART}                             sysbus.uart
${PLATFORM}                         @tests/peripherals/CLIC/CLIC-test-platform.repl
${BIN}                              @tests/peripherals/CLIC/binaries/clic_preemption-01.elf

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 sysbus LoadELF ${BIN}

*** Test Cases ***
Should Pass CLIC-preemption-01
    Create Machine
    Create Terminal Tester          ${UART}
    Start Emulation

    Wait For Line On Uart           Init complete
    Execute Command                 clic OnGPIO 16 True
    Wait For Line On Uart           Interrupt 16, level 2
    Execute Command                 clic OnGPIO 17 True
    Should Not Be On Uart           Interrupt 17, level 1
    Execute Command                 clic OnGPIO 18 True
    Wait For Line On Uart           Interrupt 18, level 3
