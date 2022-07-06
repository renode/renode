*** Variables ***
${UART}                           sysbus.cpu.uartSemihosting

*** Keywords ***
Create Machine
    Execute Command               using sysbus
    Execute Command               mach create
    Execute Command               machine LoadPlatformDescription @platforms/cpus/xtensa-sample-controller.repl

Load Opcodes To Memory
    # MOVI at0, 0x400
    Execute Command               sysbus WriteDoubleWord 0x00 0x0000A402
    # L32I at1, at0, 0x0
    Execute Command               sysbus WriteDoubleWord 0x03 0x00002012
    # L32I at2, at0, 0x1 (load from at0 + 4)
    Execute Command               sysbus WriteDoubleWord 0x06 0x00012022
    # BEQZ at2, 0x12          
    Execute Command               sysbus WriteDoubleWord 0x09 0x00005216
    # QUOU at3, at1, at2 (integer division)
    Execute Command               sysbus WriteDoubleWord 0x0c 0x00C23120
    # J 0x15
    Execute Command               sysbus WriteDoubleWord 0x0f 0x00000086
    # MOVI at3, 0x0
    Execute Command               sysbus WriteDoubleWord 0x12 0x0000A032
    # J 0x15
    Execute Command               sysbus WriteDoubleWord 0x15 0xFFFFFF06

*** Test Cases ***
Test Division
    ${NUMERATOR}=                  Set Variable   0x10
    ${DENOMINATOR}=                Set Variable   0x02
    ${EXPECTED_RES}=               Evaluate       str(0 if ${DENOMINATOR} == 0 else ${NUMERATOR} // ${DENOMINATOR})

    Create Machine
    Execute Command               machine LoadPlatformDescriptionFromString 'opmem: Memory.MappedMemory @ sysbus 0x0 { size: 0x30000 }'
    Execute Command               cpu PC 0x0
    Execute Command               cpu ExecutionMode SingleStepBlocking
    Load Opcodes To Memory

    # Load operands of the operation
    # in this example it will calculate:
    # 0x10 / 0x02
    Execute Command               sysbus WriteDoubleWord 0x400 ${NUMERATOR}
    Execute Command               sysbus WriteDoubleWord 0x404 ${DENOMINATOR}

    Start Emulation

    Execute Command               cpu Step
    PC Should Be Equal            0x3
    Register Should Be Equal      1  0x400

    Execute Command               cpu Step
    PC Should Be Equal            0x6
    Register Should Be Equal      2  ${NUMERATOR}

    Execute Command               cpu Step
    PC Should Be Equal            0x9
    Register Should Be Equal      3  ${DENOMINATOR}

    Execute Command               cpu Step 3

    PC Should Be Equal            0x15
    Register Should Be Equal      4  ${EXPECTED_RES}


Test Zephyr hello_world sample
    Create Machine
    Execute Command               sysbus LoadELF @https://dl.antmicro.com/projects/renode/xtensa-sample-controller-zephyr-hello-world.elf-s_293544-4be60f8a3891e70c30e1e8a471df4ad12ab08144
    Execute Command               cpu PC 0x50000000

    Create Terminal Tester        ${UART}

    Start Emulation

    Wait For Line On Uart         Booting Zephyr OS
    Wait For Line On Uart         Hello World! qemu_xtensa
