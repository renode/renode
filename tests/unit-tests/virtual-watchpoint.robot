*** Keywords ***
Prepare Machine
    Execute Command           using sysbus
    Execute Command           mach create

    Execute Command           machine LoadPlatformDescriptionFromString 'cpu: CPU.ARMv7A @ sysbus { cpuType: "arm926" }'
    Execute Command           machine LoadPlatformDescriptionFromString 'mem: Memory.MappedMemory @ sysbus 0x00000000 { size: 0x200000 }'

    Execute Command           cpu ExecutionMode SingleStepBlocking

Load Program
    # mov r0, #3
    Execute Command           sysbus WriteDoubleWord 0x00000000 0xe3a00003
    # mcr p15, 0, r0, c3, c0, 0
    Execute Command           sysbus WriteDoubleWord 0x00000004 0xee030f10
    # mov r0, #level1_table (0x4000)
    Execute Command           sysbus WriteDoubleWord 0x00000008 0xe3a00901
    # mcr p15, 0, r0, c2, c0, 0
    Execute Command           sysbus WriteDoubleWord 0x0000000c 0xee020f10
    # mrc p15, 0, r0, c1, c0, 0
    Execute Command           sysbus WriteDoubleWord 0x00000010 0xee110f10
    # orr r0, #0x1
    Execute Command           sysbus WriteDoubleWord 0x00000014 0xe3800001
    # mcr p15, 0, r0, c1, c0, 0
    Execute Command           sysbus WriteDoubleWord 0x00000018 0xee010f10
    # ldr r0, pointer
    Execute Command           sysbus WriteDoubleWord 0x0000001c 0xe59f0020
    # ldr r1, value
    Execute Command           sysbus WriteDoubleWord 0x00000020 0xe59f1018
    # First store - ensure page is in TLB
    # str r0, [r0]
    Execute Command           sysbus WriteDoubleWord 0x00000024 0xe5800000
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000028 0xe1a00000
    # nop, breakpoint will be set here
    Execute Command           sysbus WriteDoubleWord 0x0000002c 0xe1a00000
    # Store under test (should trigger watchpoint)
    # str r1, [r0]
    Execute Command           sysbus WriteDoubleWord 0x00000030 0xe5801000
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000034 0xe1a00000
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000038 0xe1a00000
    # wfi
    Execute Command           sysbus WriteDoubleWord 0x0000003c 0xe320f00e

    # value: .word 0x12345678
    Execute Command           sysbus WriteDoubleWord 0x00000040 0x12345678
    # pointer: .word 0xc00004c4
    Execute Command           sysbus WriteDoubleWord 0x00000044 0xc00004c4

    # level1_table: .word level2_table_0x000 + 3
    Execute Command           sysbus WriteDoubleWord 0x00004000 0x00008003
    # level1_table + 0x3000: .word level2_table_0xc00 + 3
    Execute Command           sysbus WriteDoubleWord 0x00007000 0x0000c003

    # 0x400 bytes at 0x00000000 -> 0x00000000 (identity)
    Execute Command           sysbus WriteDoubleWord 0x00008000 0x00000003
    # 0x400 bytes at 0xc0000000 -> unmapped
    Execute Command           sysbus WriteDoubleWord 0x0000c000 0x00000000
    # 0x400 bytes at 0xc0000400 -> 0x00100000
    Execute Command           sysbus WriteDoubleWord 0x0000c004 0x00100003

Memory Should Be Equal
    [Arguments]  ${address}   ${value}
    ${res}=  Execute Command  sysbus ReadDoubleWord ${address}
    Should Be Equal As Numbers  ${res}  ${value}

*** Test Cases ***
Write Watchpoint Should Work On Translated Physical Address When Added With Paging Set Up
    Prepare Machine
    Create Log Tester         0
    Load Program

    Start Emulation
    Execute Command           cpu Step 12

    # Add watchpoint hook after MMU is set up
    Execute Command           sysbus AddWatchpointHook 0x001000c4 4 2 'self.DebugLog("val " + hex(value))'
    Execute Command           logLevel 0

    # Run the rest of the way
    Execute Command           cpu Step 4

    Wait For Log Entry        val 0x12345678L
    Memory Should Be Equal    0x001000c4  0x12345678

Write Watchpoint Should Work On Translated Physical Address When Added Without Paging Set Up
    Prepare Machine
    Create Log Tester         0
    Load Program

    # Add watchpoint hook before MMU is set up
    Execute Command           sysbus AddWatchpointHook 0x001000c4 4 2 'self.DebugLog("val " + hex(value))'
    Execute Command           logLevel 0

    # Run to after first store, it stores 0xc00004c4
    Start Emulation
    Execute Command           cpu Step 12

    Wait For Log Entry        val 0xc00004c4L
    Memory Should Be Equal    0x001000c4  0xc00004c4
