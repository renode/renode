*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Test Cases ***
Should Boot And Display Hello World
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32w108.repl
    Execute Command         sysbus LoadELF @https://dev.antmicro.com/emul8_files/binaries/emul8/demos/stm32w--hello-world.mb951--0466e868ba2770b5c4d69c4aded31fc8fec0e483
    Execute Command         sysbus LoadBinary @https://dev.antmicro.com/emul8_files/binaries/emul8/demos/stm32w--stm32w108_fib_boot.bin--360627dd3ea9d83cc138be70e6ef20a581b2da54 0x8040000

    Create Terminal Tester  sysbus.uart

    Start Emulation

    Wait For Line On Uart   Starting Contiki-2.6-825-g5039566 on MB851 B
    Wait For Line On Uart   Hello, world
