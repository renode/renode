*** Keywords ***
Create Machine
    [Arguments]                     ${elf}
    Execute Command                 mach create "DA14592"
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/renesas-da14592.repl
    Execute Command                 sysbus LoadELF @${elf} useVirtualAddress=true
    Execute Command                 sysbus.cmac IsHalted true
    Execute Command                 sysbus Tag <0x50000028 +4> "SYS_STAT_REG" 0x605

*** Test Cases ***
UART Should Work
    Create Machine                  https://dl.antmicro.com/projects/renode/renesas-da1459x-hello_world.elf-s_1266192-ec30b009ff7f1c806e6905030626dce2374817db
    Create Terminal Tester          sysbus.uart1

    Wait For Line On Uart           Hello, world!
