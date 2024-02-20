*** Keywords ***
Prepare Machine
    [Arguments]  ${memoryType}

    Execute Command           using sysbus
    Execute Command           mach create "Leon3"

    Execute Command           machine LoadPlatformDescriptionFromString "sysbus: { Endianess: Endianess.BigEndian }"
    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.Sparc @ sysbus { cpuType: \\"leon3\\" }"
    Execute Command           machine LoadPlatformDescriptionFromString "rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x40000000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "ddr: Memory.${memoryType} @ sysbus 0x40000000 { size: 0x20000000 }"

    Execute Command           cpu PC 0x0
    Execute Command           cpu ExecutionMode SingleStepBlocking

Load Reader Program
    # Note that these writes to memory are in the emulation target's endianness (which is big-endian here), NOT the host's.
    # For example, after `sysbus WriteDoubleWord 0x00000000 0x03100000`, the memory content as a byte array is `[0x03, 0x10, 0x00, 0x00]`.
    # sethi  %hi(0x40000000), %g1
    Execute Command           sysbus WriteDoubleWord 0x00000000 0x03100000
    # or     %g1, 0x104, %g1
    Execute Command           sysbus WriteDoubleWord 0x00000004 0x82106104
    # ld     [ %g1 ], %g2
    Execute Command           sysbus WriteDoubleWord 0x00000008 0xc4004000
    # b      .
    Execute Command           sysbus WriteDoubleWord 0x0000000c 0x10800000
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000010 0x01000000

Load Writer Program
    # sethi  %hi(0x40000000), %g1
    Execute Command           sysbus WriteDoubleWord 0x00000000 0x03100000
    # or  %g1, 0x104, %g1
    Execute Command           sysbus WriteDoubleWord 0x00000004 0x82106104
    # sethi  %hi(0x12345400), %g2
    Execute Command           sysbus WriteDoubleWord 0x00000008 0x05048d15
    # or  %g2, 0x278, %g2
    Execute Command           sysbus WriteDoubleWord 0x0000000c 0x8410a278
    # st  %g2, [ %g1 ]
    Execute Command           sysbus WriteDoubleWord 0x00000010 0xc4204000
    # b .-4  # We jump back to the st instruction to be able to test watchpoints multiple times
    Execute Command           sysbus WriteDoubleWord 0x00000014 0x10bfffff
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000018 0x01000000

Memory Should Be Equal
    [Arguments]  ${address}   ${value}  ${width}=DoubleWord
    ${res}=  Execute Command  sysbus Read${width} ${address}
    Should Be Equal As Numbers  ${res}  ${value}

Should Read Big-Endian Value With Watchpoint
    [Arguments]  ${memoryType}

    Prepare Machine           ${memoryType}
    Load Reader Program

    # Target-endian write
    Execute Command           sysbus WriteDoubleWord 0x40000104 0x12345678

    # Same page as the value that gets accessed, not same address
    Execute Command           sysbus AddWatchpointHook 0x40000200 4 2 "pass"

    PC Should Be Equal        0x00000000
    Start Emulation

    Execute Command           cpu Step 3
    PC Should Be Equal        0x0000000c
    Register Should Be Equal  2  0x12345678

Should Write Big-Endian Value With Watchpoint
    [Arguments]  ${memoryType}

    Prepare Machine           ${memoryType}
    Load Writer Program

    # Same page as the value that gets accessed, not same address
    Execute Command           sysbus AddWatchpointHook 0x40000200 4 2 "pass"

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000
    Start Emulation

    Execute Command           cpu Step 5
    PC Should Be Equal        0x00000014
    Memory Should Be Equal    0x40000104  0x12345678
    # Also verify that reading parts of the value separately works as expected
    Memory Should Be Equal    0x40000104  0x1234  Word
    Memory Should Be Equal    0x40000106  0x5678  Word
    Memory Should Be Equal    0x40000104  0x12  Byte

Write Watchpoint Should See Correct Value
    [Arguments]  ${memoryType}

    Prepare Machine           ${memoryType}
    Create Log Tester         0
    Load Writer Program

    # Watch the address that gets accessed
    # Watchpoints see the value as the CPU sees it, so BE here.
    Execute Command           sysbus AddWatchpointHook 0x40000104 4 2 "self.DebugLog('Watchpoint saw ' + hex(value))"
    Execute Command           logLevel 0

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000
    Start Emulation

    Execute Command           cpu Step 6
    PC Should Be Equal        0x00000018
    Wait For Log Entry        Watchpoint saw 0x12345678L

Write Watchpoint Should Work Multiple Times
    [Arguments]  ${memoryType}

    Prepare Machine           ${memoryType}
    Create Log Tester         0
    Load Writer Program

    # Watch the address that gets accessed
    Execute Command           sysbus AddWatchpointHook 0x40000104 4 2 "self.DebugLog('Watchpoint saw ' + hex(value))"
    Execute Command           logLevel 0

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000
    Start Emulation

    Execute Command           cpu ExecutionMode Continuous
    Execute Command           start

    FOR    ${i}    IN RANGE    32
        Wait For Log Entry        Watchpoint saw 0x12345678L    timeout=1
    END

Abort Should Work After Watchpoint Hit
    [Arguments]  ${memoryType}

    Prepare Machine           ${memoryType}
    Create Log Tester         0
    Load Writer Program

    # Overwrite branch with illegal instruction
    Execute Command           rom WriteDoubleWord 0x00000014 0xffffffff

    # Watch the address that gets accessed
    Execute Command           sysbus AddWatchpointHook 0x40000104 4 2 "self.DebugLog('Watchpoint saw ' + hex(value))"
    Execute Command           logLevel 0

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000
    Start Emulation

    Execute Command           cpu ExecutionMode Continuous
    Execute Command           start

    Wait For Log Entry        Watchpoint saw 0x12345678L    timeout=1
    Wait For Log Entry        CPU abort [PC=0x14]: Trap 0x02 while interrupts disabled    timeout=1

*** Test Cases ***
Should Read Big-Endian Value Without Watchpoint
    Prepare Machine           MappedMemory
    Load Reader Program

    # Target-endian write
    Execute Command           sysbus WriteDoubleWord 0x40000104 0x12345678

    PC Should Be Equal        0x00000000
    Start Emulation

    Execute Command           cpu Step 3
    PC Should Be Equal        0x0000000c
    Register Should Be Equal  2  0x12345678

Should Write Big-Endian Value Without Watchpoint
    Prepare Machine           MappedMemory
    Load Writer Program

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000
    Start Emulation

    Execute Command           cpu Step 5
    PC Should Be Equal        0x00000014
    Memory Should Be Equal    0x40000104  0x12345678

Should Read Big-Endian Value With Watchpoint On MappedMemory
    Should Read Big-Endian Value With Watchpoint  MappedMemory

Should Read Big-Endian Value With Watchpoint On ArrayMemory
    Should Read Big-Endian Value With Watchpoint  ArrayMemory

Should Write Big-Endian Value With Watchpoint On MappedMemory
    Should Write Big-Endian Value With Watchpoint  MappedMemory

Should Write Big-Endian Value With Watchpoint On ArrayMemory
    Should Write Big-Endian Value With Watchpoint  ArrayMemory

Write Watchpoint Should See Correct Value On MappedMemory
    Write Watchpoint Should See Correct Value  MappedMemory

Write Watchpoint Should See Correct Value On ArrayMemory
    Write Watchpoint Should See Correct Value  ArrayMemory

Write Watchpoint Should Work Multiple Times On MappedMemory
    Write Watchpoint Should Work Multiple Times  MappedMemory

Write Watchpoint Should Work Multiple Times On ArrayMemory
    Write Watchpoint Should Work Multiple Times  ArrayMemory

Abort Should Work After Watchpoint Hit On MappedMemory
    Abort Should Work After Watchpoint Hit  MappedMemory

Abort Should Work After Watchpoint Hit On ArrayMemory
    Abort Should Work After Watchpoint Hit  ArrayMemory

Watchpoint Should Not Affect Execution On MPC5567
    # This is a big-endian PowerPC platform
    Execute Script            ${CURDIR}/../../scripts/single-node/mpc5567.resc
    Create Terminal Tester    sysbus.uart
    Create Log Tester         0
    # This address has been chosen to cause a failure to boot if the presence of the watchpoint
    # causes an access endianness mismatch
    Execute Command           sysbus AddWatchpointHook 0x40002ccc 4 3 "cpu.WarningLog('Watchpoint hit')"

    Wait For Prompt On Uart   QR5567>  pauseEmulation=true
    Wait For Log Entry        Watchpoint hit
    # Ensure that access translation works as expected for big-endian peripherals by reading the
    # UART status register, because the MPC5567_UART has ByteToDoubleWord
    Memory Should Be Equal    0xfffb0008  0xc0000000
    Memory Should Be Equal    0xfffb0008  0xc0  Byte
    Memory Should Be Equal    0xfffb0009  0x00  Byte
    Memory Should Be Equal    0xfffb000a  0x00  Byte
    Memory Should Be Equal    0xfffb000b  0x00  Byte

Watchpoint Should Not Affect Execution On Microwatt
    # This is a little-endian PowerPC platform
    Execute Script            ${CURDIR}/../../scripts/single-node/microwatt.resc
    Create Terminal Tester    sysbus.uart
    Create Log Tester         0
    # This address has been chosen to cause a failure to boot if the presence of the watchpoint
    # causes an access endianness mismatch
    Execute Command           sysbus AddWatchpointHook 0x5fee0 8 3 "cpu.WarningLog('Watchpoint hit')"

    Wait For Prompt On Uart   >>>  pauseEmulation=true
    Wait For Log Entry        Watchpoint hit
