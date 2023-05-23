*** Variables ***
${MEM}                                  0x0
${LOG_TIMEOUT}                          1

*** Keywords ***
Create Machine
    Execute Command                     mach create
    Execute Command                     machine LoadPlatformDescriptionFromString "mem: Memory.ArrayMemory @ sysbus ${MEM} { size: 0x1000 }"

Test Peripheral Read Write Hook
    [Arguments]         ${size}         ${writeValue}        ${expectedOutput}
    Execute Command                     sysbus SetHookBeforePeripheralWrite sysbus.mem "self.Log(LogLevel.Info, 'written: 0x{0:x}', value)"
    Execute Command                     sysbus Write${size} ${MEM} ${writeValue}
    Wait For Log Entry                  written: ${expectedOutput}
    Execute Command                     sysbus SetHookBeforePeripheralWrite sysbus.mem ""

    Execute Command                     sysbus SetHookAfterPeripheralRead sysbus.mem "self.Log(LogLevel.Info, 'read: 0x{0:x}', value)"
    Execute Command                     sysbus Read${size} ${MEM}
    Wait For Log Entry                  read: ${expectedOutput}
    Execute Command                     sysbus SetHookAfterPeripheralRead sysbus.mem ""

*** Test Cases ***
Should Handle Peripheral Read Write Hooks
    Create Machine
    Create Log Tester                   ${LOG_TIMEOUT}
    Start Emulation
    Test Peripheral Read Write Hook     Byte        0x2b         0x2b
    Test Peripheral Read Write Hook     Byte        0xff         0xff
    Test Peripheral Read Write Hook     Byte        0x100        0x0

    Test Peripheral Read Write Hook     Word        0xdead       0xdead
    Test Peripheral Read Write Hook     Word        0xffff       0xffff
    Test Peripheral Read Write Hook     Word        0x10000      0x0

    Test Peripheral Read Write Hook     DoubleWord  0xdeadbeef   0xdeadbeef
    Test Peripheral Read Write Hook     DoubleWord  0xffffffff   0xffffffff
    Test Peripheral Read Write Hook     DoubleWord  0x100000000  0x0

    Test Peripheral Read Write Hook     QuadWord    0x1234facedeadbabe   0x1234facedeadbabe
    # Test Peripheral Read Write Hook     QuadWord    0xffffffffffffffff   0xffffffffffffffff
    # Test Peripheral Read Write Hook     QuadWord    0x10000000000000000  0x0
    # As of writing this, Monitor does not support parsing UInt64. Once support
    # is added, please uncomment the above two tests.
