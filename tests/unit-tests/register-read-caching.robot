*** Keywords ***
Prepare Machine
    Execute Command                             using sysbus
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { cpuType: \\"rv64imacv_zicsr\\"; timeProvider: empty }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mapmem: Memory.MappedMemory @ sysbus 0x10000 { size: 0x1000 }"
    # cashing works only on peripherals accessible via sysbus, hence we can't use MappedMemory
    Execute Command                             machine LoadPlatformDescriptionFromString "arrmem: Memory.ArrayMemory @ sysbus 0x100000 { size: 0x1000 }"

    Execute Command                             cpu PC 0x10000
    Write Program

Write Program
    # lui a5,0x100
    Execute Command                            sysbus WriteDoubleWord 0x10000 0x001007b7

    # lw a0, 16(a5)
    Execute Command                            sysbus WriteDoubleWord 0x10004 0x0107a503

    # beqz x0,-4
    Execute Command                            sysbus WriteDoubleWord 0x10008 0xfe000ee3

*** Test Cases ***
Cache Read Value
    Prepare Machine
    Execute Command                            cpu EnableReadCache 0x100010 2 4
    Execute Command                            cpu Step 1

    # check that register has a proper reset value
    Register Should Be Equal                   10  0x0

    # first two reads should not be cached - we should observe the actual value
    Execute Command                            sysbus WriteDoubleWord 0x100010 0x10
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x10

    Execute Command                            sysbus WriteDoubleWord 0x100010 0x11
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x11

    # the next 4 reads should be cached - we should observe the previous value
    Execute Command                            sysbus WriteDoubleWord 0x100010 0x12
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x11

    Execute Command                            sysbus WriteDoubleWord 0x100010 0x13
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x11

    Execute Command                            sysbus WriteDoubleWord 0x100010 0x14
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x11

    Execute Command                            sysbus WriteDoubleWord 0x100010 0x15
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x11

    # now caching should be disabled for the next 2 reads
    Execute Command                            sysbus WriteDoubleWord 0x100010 0x16
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x16

    Execute Command                            sysbus WriteDoubleWord 0x100010 0x17
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x17

    # and now the caching should be enabled again
    Execute Command                            sysbus WriteDoubleWord 0x100010 0x18
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x17

    Execute Command                            sysbus WriteDoubleWord 0x100010 0x19
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x17

    Execute Command                            sysbus WriteDoubleWord 0x100010 0x1A
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x17

    Execute Command                            sysbus WriteDoubleWord 0x100010 0x1B
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x17

    # and again caching should be disabled
    Execute Command                            sysbus WriteDoubleWord 0x100010 0x1C
    Execute Command                            cpu Step 2
    Register Should Be Equal                   10  0x1C