*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imac\\"; timeProvider: empty }"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x10000000 }"
    Execute Command                 sysbus Tag <0x4, 0x4> "tagged_region"

    Execute Command                 cpu PC 0x1000

Tag Area And Access It From Sysbus
    [Arguments]                     ${address}  ${tag}  ${silent}=false
    Execute Command                 sysbus Tag <${address}, ${address}> "${tag}" silent=${silent}

    Execute Command                 sysbus WriteByte ${address} 0x4

*** Test Cases ***
Should Log Unhandled Read From Monitor
    Create Log Tester               0
    Execute Command                 mach create
    Execute Command                 sysbus ReadDoubleWord 0x0

    Wait For Log Entry              ReadDoubleWord from non existing peripheral at 0x0

Should Log Unhandled Write From Monitor
    Create Log Tester               0
    Execute Command                 mach create
    Execute Command                 sysbus WriteDoubleWord 0x0 0x147

    Wait For Log Entry              WriteDoubleWord to non existing peripheral at 0x0, value 0x147

Should Log Unhandled Software Read
    Create Log Tester               1000
    Create Machine

    # lw x0, 0(x0)
    Execute Command                 sysbus WriteDoubleWord 0x1000 0x00002003

    Start Emulation

    Wait For Log Entry              [cpu: 0x1000] ReadDoubleWord from non existing peripheral at 0x0

Should Log Unhandled Software Read From Tagged Area
    Create Log Tester               1000
    Create Machine

    # lw x0, 4(x0)
    Execute Command                 sysbus WriteDoubleWord 0x1000 0x00402003

    Start Emulation

    Wait For Log Entry              [cpu: 0x1000] (tag: 'tagged_region') ReadDoubleWord from non existing peripheral at 0x4, returning 0x0

Should Log Unhandled Software Write
    Create Log Tester               1000
    Create Machine

    # sw x0, 0(x0)
    Execute Command                 sysbus WriteDoubleWord 0x1000 0x00002023

    Start Emulation

    Wait For Log Entry              [cpu: 0x1000] WriteDoubleWord to non existing peripheral at 0x0, value 0x0

Should Log Unhandled Write From Software To Tagged Area
    Create Log Tester               1000
    Create Machine

    # sw x0, 4(x0)
    Execute Command                 sysbus WriteDoubleWord 0x1000 0x00002223

    Start Emulation

    Wait For Log Entry              [cpu: 0x1000] (tag: 'tagged_region') WriteDoubleWord to non existing peripheral at 0x4, value 0x0

Should Not Log Unhandled Access As Warning On Silent Tag
    Create Log Tester               0
    Create Machine
    Execute Command                 logLevel 0

    ${tag}=                         Set Variable  test1
    Tag Area And Access It From Sysbus  address=0x06  tag=${tag}  silent=true
    Wait For Log Entry              (tag: '${tag}')  keep=true  level=Debug
    Should Not Be In Log            (tag: '${tag}')  level=Warning

Should Log From Subobject
    Create Log Tester               1
    Create Machine
    Execute Command                 include "${CURDIR}/SubobjectTester.cs"
    Execute Command                 EnsureTypeIsLoaded "Antmicro.Renode.Peripherals.Dynamic.SubobjectTester"

    Execute Command                 machine LoadPlatformDescriptionFromString "tester: Dynamic.SubobjectTester @ sysbus 0xf0000000"

    Start Emulation

    Execute Command                 logLevel -1 sysbus.tester
    Execute Command                 sysbus WriteDoubleWord 0xf0000000 0x1
    Wait For Log Entry              Hello from object
    Wait For Log Entry              Hello from sub-object

Should Set Machine Log Level
    Create Machine

    ${l}=                           Execute Command  logLevel
    Should Not Contain              ${l}  machine-0:sysbus : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-0:sysbus.cpu : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-0:sysbus.mem : ERROR  collapse_spaces=True

    Execute Command                 logLevel 3 machine-0
    ${l}=                           Execute Command  logLevel

    Should Contain                  ${l}  machine-0:sysbus : ERROR  collapse_spaces=True
    Should Contain                  ${l}  machine-0:sysbus.cpu : ERROR  collapse_spaces=True
    Should Contain                  ${l}  machine-0:sysbus.mem : ERROR  collapse_spaces=True

Should Set Machine Log Level 2
    Create Machine
    Create Machine

    ${l}=                           Execute Command  logLevel

    Should Not Contain              ${l}  machine-0:sysbus : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-0:sysbus.cpu : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-0:sysbus.mem : ERROR  collapse_spaces=True

    Should Not Contain              ${l}  machine-1:sysbus : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-1:sysbus.cpu : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-1:sysbus.mem : ERROR  collapse_spaces=True

    Execute Command                 mach set 1
    Execute Command                 logLevel 3 machine-0
    ${l}=                           Execute Command  logLevel

    Should Contain                  ${l}  machine-0:sysbus : ERROR  collapse_spaces=True
    Should Contain                  ${l}  machine-0:sysbus.cpu : ERROR  collapse_spaces=True
    Should Contain                  ${l}  machine-0:sysbus.mem : ERROR  collapse_spaces=True

    Should Not Contain              ${l}  machine-1:sysbus : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-1:sysbus.cpu : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-1:sysbus.mem : ERROR  collapse_spaces=True

Should Set Machine Log Level 3
    Create Machine
    Create Machine

    ${l}=                           Execute Command  logLevel

    Should Not Contain              ${l}  machine-0:sysbus : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-0:sysbus.cpu : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-0:sysbus.mem : ERROR  collapse_spaces=True

    Should Not Contain              ${l}  machine-1:sysbus : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-1:sysbus.cpu : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-1:sysbus.mem : ERROR  collapse_spaces=True

    Execute Command                 mach set 1
    Execute Command                 logLevel 3 machine-1
    ${l}=                           Execute Command  logLevel

    Should Not Contain              ${l}  machine-0:sysbus : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-0:sysbus.cpu : ERROR  collapse_spaces=True
    Should Not Contain              ${l}  machine-0:sysbus.mem : ERROR  collapse_spaces=True

    Should Contain                  ${l}  machine-1:sysbus : ERROR  collapse_spaces=True
    Should Contain                  ${l}  machine-1:sysbus.cpu : ERROR  collapse_spaces=True
    Should Contain                  ${l}  machine-1:sysbus.mem : ERROR  collapse_spaces=True

Should Fail On Failing String In Log
    Create Log Tester               0
    Execute Command                 mach create
    Execute Command                 sysbus ReadDoubleWord 0x0

    Register Failing Log String     ReadDoubleWord from non existing peripheral at 0x.  treatAsRegex=true

    Run Keyword And Expect Error
    ...                             *Test failing entry*
    ...                             Wait For Log Entry  ReadDoubleWord from non existing peripheral at 0x0

Should Unregister Failing String In Log
    Create Log Tester               0
    Execute Command                 mach create
    Execute Command                 sysbus ReadDoubleWord 0x0

    Register Failing Log String     ReadDoubleWord from non existing peripheral at 0x.  treatAsRegex=true

    Unregister Failing Log String   ReadDoubleWord from non existing peripheral at 0x.  treatAsRegex=true

    Wait For Log Entry  ReadDoubleWord from non existing peripheral at 0x0

# It is important that this tests is placed after some tests that creates a log tester
Should Not Preserve Log Tester Between Tests
    Run Keyword And Expect Error    *Log tester is not available*
    ...                             Should Not Be In Log  Non existing log message
