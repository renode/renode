*** Keywords ***
Prepare Machine
    [Arguments]  ${architecture}  ${memoryType}

    Execute Command           using sysbus
    Execute Command           mach create "Leon3"

    Execute Command           machine LoadPlatformDescriptionFromString "sysbus: { Endianess: Endianess.BigEndian }"
    IF  "${architecture}" == "Sparc"
        Execute Command       machine LoadPlatformDescriptionFromString "cpu: CPU.Sparc @ sysbus { cpuType: \\"leon3\\" }"
    ELSE IF  "${architecture}" == "PowerPC"
        Execute Command       machine LoadPlatformDescriptionFromString "cpu: CPU.PowerPc @ sysbus { cpuType: \\"e200z6\\" }"
    ELSE
        Fail                  Unknown architecture ${architecture}
    END
    Execute Command           machine LoadPlatformDescriptionFromString "rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x40000000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "ddr: Memory.${memoryType} @ sysbus 0x40000000 { size: 0x20000000 }"

    Execute Command           cpu PC 0x0

Load Sparc Reader Program
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

Load Sparc Writer Program
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

Load PowerPC Reader Program
    # lis r1, 0x4000
    Execute Command           sysbus WriteDoubleWord 0x00000000 0x3c204000
    # ori r1, r1, 0x104
    Execute Command           sysbus WriteDoubleWord 0x00000004 0x60210104
    # lwz r2, 0(r1)
    Execute Command           sysbus WriteDoubleWord 0x00000008 0x80410000
    # b .
    Execute Command           sysbus WriteDoubleWord 0x0000000c 0x48000000
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000010 0x60000000

Load PowerPC Writer Program
    # lis r1, 0x4000
    Execute Command           sysbus WriteDoubleWord 0x00000000 0x3c204000
    # ori r1, r1, 0x104
    Execute Command           sysbus WriteDoubleWord 0x00000004 0x60210104
    # lis r2, 0x1234
    Execute Command           sysbus WriteDoubleWord 0x00000008 0x3c401234
    # ori r2, r2, 0x5678
    Execute Command           sysbus WriteDoubleWord 0x0000000c 0x60425678
    # stw r2, 0(r1)
    Execute Command           sysbus WriteDoubleWord 0x00000010 0x90410000
    # b .-4
    Execute Command           sysbus WriteDoubleWord 0x00000014 0x4bfffffc
    # nop
    Execute Command           sysbus WriteDoubleWord 0x00000018 0x60000000

Load Program
    [Arguments]  ${architecture}  ${type}

    Run Keyword               Load ${architecture} ${type} Program

Memory Should Be Equal
    [Arguments]  ${address}   ${value}  ${width}=DoubleWord
    ${res}=  Execute Command  sysbus Read${width} ${address}
    Should Be Equal As Numbers  ${res}  ${value}

Should Read Big-Endian Value With Watchpoint
    [Arguments]  ${architecture}  ${memoryType}

    Prepare Machine           ${architecture}  ${memoryType}
    Load Program              ${architecture}  Reader

    # Target-endian write
    Execute Command           sysbus WriteDoubleWord 0x40000104 0x12345678

    # Same page as the value that gets accessed, not same address
    Execute Command           sysbus AddWatchpointHook 0x40000200 4 2 "pass"

    PC Should Be Equal        0x00000000

    Execute Command           cpu Step 3
    PC Should Be Equal        0x0000000c
    Register Should Be Equal  2  0x12345678

Should Write Big-Endian Value With Watchpoint
    [Arguments]  ${architecture}  ${memoryType}

    Prepare Machine           ${architecture}  ${memoryType}
    Load Program              ${architecture}  Writer

    # Same page as the value that gets accessed, not same address
    Execute Command           sysbus AddWatchpointHook 0x40000200 4 2 "pass"

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000

    Execute Command           cpu Step 5
    PC Should Be Equal        0x00000014
    Memory Should Be Equal    0x40000104  0x12345678
    # Also verify that reading parts of the value separately works as expected
    Memory Should Be Equal    0x40000104  0x1234  Word
    Memory Should Be Equal    0x40000106  0x5678  Word
    Memory Should Be Equal    0x40000104  0x12  Byte

Write Watchpoint Should See Correct Value
    [Arguments]  ${architecture}  ${memoryType}

    Prepare Machine           ${architecture}  ${memoryType}
    Create Log Tester         0
    Load Program              ${architecture}  Writer

    # Watch the address that gets accessed
    # Watchpoints see the value as the CPU sees it, so BE here.
    Execute Command           sysbus AddWatchpointHook 0x40000104 4 2 "self.DebugLog('Watchpoint saw ' + hex(value))"
    Execute Command           logLevel 0

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000

    Execute Command           cpu Step 6
    IF  "${architecture}" == "Sparc"
        PC Should Be Equal    0x00000018
    ELSE
        PC Should Be Equal    0x00000010
    END
    Wait For Log Entry        Watchpoint saw 0x12345678L

Write Watchpoint Should Work Multiple Times
    [Arguments]  ${architecture}  ${memoryType}

    Prepare Machine           ${architecture}  ${memoryType}
    Create Log Tester         0
    Load Program              ${architecture}  Writer

    # Watch the address that gets accessed
    Execute Command           sysbus AddWatchpointHook 0x40000104 4 2 "self.DebugLog('Watchpoint saw ' + hex(value))"
    Execute Command           logLevel 0

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000

    Execute Command           cpu ExecutionMode Continuous
    Execute Command           start

    FOR    ${i}    IN RANGE    32
        Wait For Log Entry        Watchpoint saw 0x12345678L    timeout=1
    END

Abort Should Work After Watchpoint Hit
    [Arguments]  ${memoryType}

    Prepare Machine           Sparc  ${memoryType}
    Create Log Tester         0
    Load Program              Sparc  Writer

    # Overwrite branch with illegal instruction
    Execute Command           rom WriteDoubleWord 0x00000014 0xffffffff

    # Watch the address that gets accessed
    Execute Command           sysbus AddWatchpointHook 0x40000104 4 2 "self.DebugLog('Watchpoint saw ' + hex(value))"
    Execute Command           logLevel 0

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000

    Execute Command           cpu ExecutionMode Continuous
    Execute Command           start

    Wait For Log Entry        Watchpoint saw 0x12345678L    timeout=1
    Wait For Log Entry        CPU abort [PC=0x14]: Trap 0x02 while interrupts disabled    timeout=1

Should Read Big-Endian Value Without Watchpoint
    [Arguments]  ${architecture}

    Prepare Machine           ${architecture}  MappedMemory
    Load Program              ${architecture}  Reader

    # Target-endian write
    Execute Command           sysbus WriteDoubleWord 0x40000104 0x12345678

    PC Should Be Equal        0x00000000

    Execute Command           cpu Step 3
    PC Should Be Equal        0x0000000c
    Register Should Be Equal  2  0x12345678

Should Write Big-Endian Value Without Watchpoint
    [Arguments]  ${architecture}

    Prepare Machine           ${architecture}  MappedMemory
    Load Program              ${architecture}  Writer

    PC Should Be Equal        0x00000000
    Memory Should Be Equal    0x40000104  0x00000000

    Execute Command           cpu Step 5
    PC Should Be Equal        0x00000014
    Memory Should Be Equal    0x40000104  0x12345678


*** Test Cases ***
Should Read Big-Endian Value Without Watchpoint On Sparc
    Should Read Big-Endian Value Without Watchpoint  Sparc

Should Write Big-Endian Value Without Watchpoint On Sparc
    Should Write Big-Endian Value Without Watchpoint  Sparc

Should Read Big-Endian Value With Watchpoint On MappedMemory On Sparc
    Should Read Big-Endian Value With Watchpoint  Sparc  MappedMemory

Should Read Big-Endian Value With Watchpoint On ArrayMemory On Sparc
    Should Read Big-Endian Value With Watchpoint  Sparc  ArrayMemory

Should Write Big-Endian Value With Watchpoint On MappedMemory On Sparc
    Should Write Big-Endian Value With Watchpoint  Sparc  MappedMemory

Should Write Big-Endian Value With Watchpoint On ArrayMemory On Sparc
    Should Write Big-Endian Value With Watchpoint  Sparc  ArrayMemory

Write Watchpoint Should See Correct Value On MappedMemory On Sparc
    Write Watchpoint Should See Correct Value  Sparc  MappedMemory

Write Watchpoint Should See Correct Value On ArrayMemory On Sparc
    Write Watchpoint Should See Correct Value  Sparc  ArrayMemory

Write Watchpoint Should Work Multiple Times On MappedMemory On Sparc
    Write Watchpoint Should Work Multiple Times  Sparc  MappedMemory

Write Watchpoint Should Work Multiple Times On ArrayMemory On Sparc
    Write Watchpoint Should Work Multiple Times  Sparc  ArrayMemory

Should Read Big-Endian Value With Watchpoint On MappedMemory On PowerPC
    Should Read Big-Endian Value With Watchpoint  PowerPC  MappedMemory

Should Read Big-Endian Value With Watchpoint On ArrayMemory On PowerPC
    Should Read Big-Endian Value With Watchpoint  PowerPC  ArrayMemory

Should Write Big-Endian Value With Watchpoint On MappedMemory On PowerPC
    Should Write Big-Endian Value With Watchpoint  PowerPC  MappedMemory

Should Write Big-Endian Value With Watchpoint On ArrayMemory On PowerPC
    Should Write Big-Endian Value With Watchpoint  PowerPC  ArrayMemory

Write Watchpoint Should See Correct Value On MappedMemory On PowerPC
    Write Watchpoint Should See Correct Value  PowerPC  MappedMemory

Write Watchpoint Should See Correct Value On ArrayMemory On PowerPC
    Write Watchpoint Should See Correct Value  PowerPC  ArrayMemory

Write Watchpoint Should Work Multiple Times On MappedMemory On PowerPC
    Write Watchpoint Should Work Multiple Times  PowerPC  MappedMemory

Write Watchpoint Should Work Multiple Times On ArrayMemory On PowerPC
    Write Watchpoint Should Work Multiple Times  PowerPC  ArrayMemory

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
