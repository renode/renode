*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]     ${elf}      ${name}     ${id}

    Execute Command             mach create ${name}
    Execute Command             using sysbus
    Execute Command             machine LoadPlatformDescription @platforms/cpus/cc2538.repl

    Execute Command             machine PyDevFromFile @scripts/pydev/rolling-bit.py 0x400D2004 0x4 True "sysctrl"

    Execute Command             sysbus WriteDoubleWord 0x00280028 ${id}
    Execute Command             sysbus WriteDoubleWord 0x0028002C 0x00
    Execute Command             sysbus WriteDoubleWord 0x00280030 0xAB
    Execute Command             sysbus WriteDoubleWord 0x00280034 0x89
    Execute Command             sysbus WriteDoubleWord 0x00280038 0x00
    Execute Command             sysbus WriteDoubleWord 0x0028003C 0x4B
    Execute Command             sysbus WriteDoubleWord 0x00280040 0x12
    Execute Command             sysbus WriteDoubleWord 0x00280044 0x00

    Execute Command             sysbus LoadBinary ${URI}/cc2538_rom_dump.bin-s_524288-0c196cdc21b5397f82e0ff42b206d1cc4b6d7522 0x0
    Execute Command             sysbus LoadELF ${elf}
    Execute Command             cpu VectorTableOffset `sysbus GetSymbolAddress "vectors"`

*** Test Cases ***
Should Run Hello World
    [Tags]                    cc2538  uart
    Create Machine            ${URI}/cc2538-contiki_hello_world.elf-s_242120-08fc83d11f790ccc1aa46abfdfc9c2e1a94baed2       "cc2538"      1

    Create Terminal Tester    ${UART}
    Start Emulation
    Wait For Line On Uart     Hello, world
