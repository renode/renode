*** Keywords ***
Create Machine
    Execute Command                             mach create

    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.VexRiscv @ sysbus { cpuType: \\"rv32gc\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x80000000 { size: 0x1000 }"
    # Disable UART buffering for compatibility with older firmware
    Execute Command                             machine LoadPlatformDescriptionFromString "uart: UART.LiteX_UART @ sysbus 0x40008000 { txFifoCapacity: 0 }"

    Execute Command                             sysbus LoadELF @https://dl.antmicro.com/projects/renode/riscv32--ebreak_custom_test.elf-s_5760-4db0870a69de9bba7ccda18908832c5b72cff35e

*** Test Cases ***
Should Generate Ebreak

    Create Machine
    Create Terminal Tester                      sysbus.uart

    Start Emulation

    Wait For Line On Uart                       !starting test...
    Wait For Line On Uart                       ecall instruction from machine mode
    Wait For Line On Uart                       ebreak instruction
    Wait For Line On Uart                       ecall instruction from machine mode
    Wait For Line On Uart                       ebreak instruction
    Wait For Line On Uart                       finished test

