*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Keywords ***
Prepare Machine
    Execute Command           using sysbus
    Execute Command           mach create "Leon3"

    Execute Command           machine LoadPlatformDescriptionFromString "rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x40000000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "ddr: Memory.MappedMemory @ sysbus 0x40000000 { size: 0x20000000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.Sparc @ sysbus { cpuType: \\"leon3\\" }"

    Execute Command           cpu PC 0x0
    Execute Command           cpu ExecutionMode SingleStepBlocking

Load Reader Program
    # sethi  %hi(0x40000000), %g1
    Execute Command           sysbus WriteDoubleWord 0x00000000 0x00001003
    # or     %g1, 0x104, %g1
    Execute Command           sysbus WriteDoubleWord 0x00000004 0x04611082
    # ld     [ %g1 ], %g2
    Execute Command           sysbus WriteDoubleWord 0x00000008 0x004000c4
    # b      .
    Execute Command           sysbus WriteDoubleWord 0x0000000c 0x00008010
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000010 0x00000001

Load Writer Program
    # sethi  %hi(0x40000000), %g1
    Execute Command           sysbus WriteDoubleWord 0x00000000 0x00001003
    # or  %g1, 0x104, %g1
    Execute Command           sysbus WriteDoubleWord 0x00000004 0x04611082
    # sethi  %hi(0x12345400), %g2
    Execute Command           sysbus WriteDoubleWord 0x00000008 0x158d0405
    # or  %g2, 0x278, %g2
    Execute Command           sysbus WriteDoubleWord 0x0000000c 0x78a21084
    # st  %g2, [ %g1 ]
    Execute Command           sysbus WriteDoubleWord 0x00000010 0x004020c4
    # b .
    Execute Command           sysbus WriteDoubleWord 0x00000014 0x00008010
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000018 0x00000001

Memory Should Be Equal
    [Arguments]  ${address}   ${value}
    ${res}=  Execute Command  sysbus ReadDoubleWord ${address}
    Should Be Equal As Numbers  ${res}  ${value}

*** Test Cases ***
Should Read Big-Endian Value Without Watchpoint
    Prepare Machine
    Load Reader Program

    # Little-endian write
    Execute Command           sysbus WriteDoubleWord 0x40000104 0x78563412

    Start Emulation
    PC Should Be Equal        0x00000000

    Execute Command           cpu Step 3
    PC Should Be Equal        0x0000000c
    Register Should Be Equal  2  0x12345678

Should Read Big-Endian Value With Watchpoint
    Prepare Machine
    Load Reader Program

    # Little-endian write
    Execute Command           sysbus WriteDoubleWord 0x40000104 0x78563412

    # Same page as the value that gets accessed, not same address
    Execute Command           sysbus AddWatchpointHook 0x40000200 4 2 "pass"

    Start Emulation
    PC Should Be Equal        0x00000000

    Execute Command           cpu Step 3
    PC Should Be Equal        0x0000000c
    Register Should Be Equal  2  0x12345678

Should Write Big-Endian Value Without Watchpoint
    Prepare Machine
    Load Writer Program

    Start Emulation
    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000

    Execute Command           cpu Step 5
    PC Should Be Equal        0x00000014
    Memory Should Be Equal    0x40000104  0x78563412

Should Write Big-Endian Value With Watchpoint
    Prepare Machine
    Load Writer Program

    # Same page as the value that gets accessed, not same address
    Execute Command           sysbus AddWatchpointHook 0x40000200 4 2 "pass"

    Start Emulation
    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000

    Execute Command           cpu Step 5
    PC Should Be Equal        0x00000014
    Memory Should Be Equal    0x40000104  0x78563412

Write Watchpoint Should See Correct Value
    Prepare Machine
    Create Log Tester         0
    Load Writer Program

    # Watch the address that gets accessed
    Execute Command           sysbus AddWatchpointHook 0x40000104 4 2 "self.DebugLog('Watchpoint saw ' + hex(value))"
    Execute Command           logLevel 0

    Start Emulation
    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000

    Execute Command           cpu Step 6
    PC Should Be Equal        0x00000014
    Wait For Log Entry        Watchpoint saw 0x78563412L
