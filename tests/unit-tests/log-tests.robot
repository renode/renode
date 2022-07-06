*** Keywords ***
Create Machine                                  
    Execute Command           using sysbus
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imac\\"; timeProvider: empty }"
    Execute Command           machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x10000000 }"
    Execute Command           sysbus Tag <0x4, 0x4> "tagged_region"

    Execute Command           cpu PC 0x1000


*** Test Cases ***
Should Log Unhandled Read From Monitor
    Create Log Tester         0
    Execute Command           mach create
    Execute Command           sysbus ReadDoubleWord 0x0

    Wait For Log Entry        ReadDoubleWord from non existing peripheral at 0x0

Should Log Unhandled Write From Monitor
    Create Log Tester         0
    Execute Command           mach create
    Execute Command           sysbus WriteDoubleWord 0x0 0x147

    Wait For Log Entry        WriteDoubleWord to non existing peripheral at 0x0, value 0x147

Should Log Unhandled Software Read
    Create Log Tester         1000
    Create Machine

    # lw x0, 0(x0)
    Execute Command           sysbus WriteDoubleWord 0x1000 0x00002003

    Start Emulation

    Wait For Log Entry        [cpu: 0x1000] ReadDoubleWord from non existing peripheral at 0x0

Should Log Unhandled Software Read From Tagged Area
    Create Log Tester         1000
    Create Machine

    # lw x0, 4(x0)
    Execute Command           sysbus WriteDoubleWord 0x1000 0x00402003

    Start Emulation

    Wait For Log Entry        [cpu: 0x1000] (tag: 'tagged_region') ReadDoubleWord from non existing peripheral at 0x4, returning 0x0

Should Log Unhandled Software Write
    Create Log Tester         1000
    Create Machine

    # sw x0, 0(x0)
    Execute Command           sysbus WriteDoubleWord 0x1000 0x00002023

    Start Emulation

    Wait For Log Entry        [cpu: 0x1000] WriteDoubleWord to non existing peripheral at 0x0, value 0x0

Should Log Unhandled Write From Software To Tagged Area
    Create Log Tester         1000
    Create Machine

    # sw x0, 4(x0)
    Execute Command           sysbus WriteDoubleWord 0x1000 0x00002223

    Start Emulation

    Wait For Log Entry        [cpu: 0x1000] (tag: 'tagged_region') WriteDoubleWord to non existing peripheral at 0x4, value 0x0

Should Log From Subobject
    [Tags]                    skip_windows
    # there are problems with Windows package test as it uses whitespaces in the path; to be resolved later

    Create Log Tester         1
    Create Machine
    Execute Command           include @${CURDIR}${/}SubobjectTester.cs
    Execute Command           EnsureTypeIsLoaded "Antmicro.Renode.Peripherals.Dynamic.SubobjectTester"

    Execute Command           machine LoadPlatformDescriptionFromString "tester: Dynamic.SubobjectTester @ sysbus 0xf0000000"

    Start Emulation

    Execute Command           logLevel -1 sysbus.tester
    Execute Command           sysbus WriteDoubleWord 0xf0000000 0x1
    Wait For Log Entry        Hello from object
    Wait For Log Entry        Hello from sub-object
