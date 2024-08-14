*** Keywords ***
Prepare Machine
    ${TEST_DIR}=             Evaluate  r"${CURDIR}".replace(" ", "\\ ")
    Execute Command          include @${TEST_DIR}/TestPeripheral.cs

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString "cpu: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command          machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command          machine LoadPlatformDescriptionFromString "mock: Mocks.TestPeripheral @ sysbus 0x2000"


Prepare Multicore Machine
    ${TEST_DIR}=             Evaluate  r"${CURDIR}".replace(" ", "\\ ")
    Execute Command          include @${TEST_DIR}/TestPeripheral.cs

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString "cpu0: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command          machine LoadPlatformDescriptionFromString "cpu1: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command          machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command          machine LoadPlatformDescriptionFromString "mock: Mocks.TestPeripheral @ sysbus 0x2000"


Scheduled Action Should Be Delayed By ${delay} Microseconds
    ${x}=  Wait For Log Entry       Written value 0x0 to Reg0
    ${c}=  Get Regexp Matches  ${x}   \\.([0-9]+)   1
    ${y}=  Evaluate    str(int(${c[0]}) + ${delay}).rjust(6, '0')
    Wait For Log Entry       Executing scheduled action for Reg0; current timestamp is 00:00:00.${y}

Fill Memory
    # prepare a block of code
    # containing precisely 12 instructions
    # consisting mostly of `nops` with
    # a single `strb` inbetween

    #  1: nop
    Execute Command          sysbus WriteDoubleWord 0x10 0xe320f000
    #  2: nop
    Execute Command          sysbus WriteDoubleWord 0x14 0xe320f000
    #  3: nop
    Execute Command          sysbus WriteDoubleWord 0x18 0xe320f000
    #  4: nop
    Execute Command          sysbus WriteDoubleWord 0x1c 0xe320f000
    #  5: nop
    Execute Command          sysbus WriteDoubleWord 0x20 0xe320f000
    #  6: nop
    Execute Command          sysbus WriteDoubleWord 0x24 0xe320f000
    #  7: nop
    Execute Command          sysbus WriteDoubleWord 0x28 0xe320f000
    #  8: strb r0, [r1]
    Execute Command          sysbus WriteDoubleWord 0x2c 0xe5c10000
    #  9: nop
    Execute Command          sysbus WriteDoubleWord 0x30 0xe320f000
    # 10: nop
    Execute Command          sysbus WriteDoubleWord 0x34 0xe320f000
    # 11: nop
    Execute Command          sysbus WriteDoubleWord 0x38 0xe320f000
    # 12: nop
    Execute Command          sysbus WriteDoubleWord 0x3c 0xe320f000
    # 13: j -4
    Execute Command          sysbus WriteDoubleWord 0x40 0xeafffffd


*** Test Cases ***
Should Delay Action
    Prepare Machine
    Execute Command          sysbus.mock SetDelay 3

    Create Log Tester        1

    Execute Command          sysbus.cpu PC 0x10
    Execute Command          sysbus.cpu SetRegister 1 0x2000

    Fill Memory
    Scheduled Action Should Be Delayed By 3 Microseconds


Should Delay Action With Multiple Cores
    Prepare Multicore Machine
    Execute Command          machine SetSerialExecution true
    Execute Command          sysbus.mock SetDelay 3

    Create Log Tester        1

    Execute Command          sysbus.cpu0 PC 0x10
    Execute Command          sysbus.cpu0 SetRegister 1 0x2000

    # just make the other CPU spin in a loop
    Execute Command          sysbus.cpu1 PC 0x3c

    Fill Memory
    Scheduled Action Should Be Delayed By 3 Microseconds


Should Delay Action With Multiple Cores In Different Ordering
    Prepare Multicore Machine
    Execute Command          machine SetSerialExecution true
    Execute Command          sysbus.mock SetDelay 3

    Create Log Tester        1

    Execute Command          sysbus.cpu1 PC 0x10
    Execute Command          sysbus.cpu1 SetRegister 1 0x2000

    # just make the other CPU spin in a loop
    Execute Command          sysbus.cpu0 PC 0x3c

    Fill Memory
    Scheduled Action Should Be Delayed By 3 Microseconds
