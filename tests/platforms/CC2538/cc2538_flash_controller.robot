*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]     ${elf}

    Execute Command             mach create
    Execute Command             using sysbus
    Execute Command             machine LoadPlatformDescription @platforms/cpus/cc2538.repl

    Execute Command             machine PyDevFromFile @scripts/pydev/rolling-bit.py 0x400D2004 0x4 True "sysctrl"

    Execute Command             sysbus LoadBinary @https://dl.antmicro.com/projects/renode/cc2538_rom_dump.bin-s_524288-0c196cdc21b5397f82e0ff42b206d1cc4b6d7522 0x0
    Execute Command             sysbus LoadELF ${elf}
    Execute Command             sysbus.cpu VectorTableOffset `sysbus GetSymbolAddress "vectors"`

*** Test Cases ***
Should Write, Read and Erase Flash using Flash Controller
    Create Machine              ${URI}/cc2538-contiki_ng-flash_test.elf-s_174036-32132ab0ef2488062468544c05b5c0ea8142cb94

    Create Terminal Tester      ${UART}
    Start Emulation

    Wait For Line On Uart       CC2538 FLASH TEST
    Wait For Line On Uart       FLASH SIZE: 0x10000
    Wait For Line On Uart       [OK] Data written with memset successfully
    Wait For Line On Uart       [OK] Data written successfully               timeout=12
    Wait For Line On Uart       [OK] Data erased successfully
    Wait For Line On Uart       [OK] Data erased successfully
