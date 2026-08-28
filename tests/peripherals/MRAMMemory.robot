*** Variables ***
${PLATFORM}=    SEPARATOR=
...  """                                                 ${\n}
...  cpu: CPU.CortexM @ sysbus                           ${\n}
...  ${SPACE*4}cpuType: "cortex-m0+"                     ${\n}
...  ${SPACE*4}nvic: nvic                                ${\n}
...                                                      ${\n}
...  nvic: IRQControllers.NVIC @ sysbus 0xE000E000       ${\n}
...  ${SPACE*4}-> cpu@0                                  ${\n}
...                                                      ${\n}
...  sram: Memory.MappedMemory @ sysbus 0x20000000       ${\n}
...  ${SPACE*4}size: 0x10000                             ${\n}
...                                                      ${\n}
...  mram: Memory.MRAMMemory @ sysbus 0x10000000         ${\n}
...  ${SPACE*4}size: 0x80000                             ${\n}
...  ${SPACE*4}WordSize: 8                               ${\n}
...  ${SPACE*4}EnforceWordWriteSemantics: true            ${\n}
...  """

*** Keywords ***
Create MRAM Machine
    Execute Command    mach create
    Execute Command    machine LoadPlatformDescriptionFromString ${PLATFORM}

*** Test Cases ***
MRAM Persists Across Reset
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0xAABBCCDD
    Execute Command    machine Reset
    ${read_back}=      Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${read_back}    0xAABBCCDD

MRAM Word Write Preserves Unaddressed Bytes
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0xFFEEDDCCBBAA9988
    # Overwriting only the upper 4 bytes performs a word read-modify-write.
    Execute Command    sysbus WriteDoubleWord 0x10000004 0x11223344
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    Should Be Equal As Integers    ${word}    0x11223344BBAA9988

MRAM InjectPartialWrite Corrupts Second Half Of Word
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0xA1A2A3A4B1B2B3B4
    Execute Command    sysbus.mram InjectPartialWrite 0x0
    # First 4 bytes survive, last 4 bytes are zeroed (erase fill).
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    Should Be Equal As Integers    ${word}    0x00000000B1B2B3B4

MRAM InjectFault Overwrites Region With Pattern
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0xFFFFFFFFFFFFFFFF
    Execute Command    sysbus.mram InjectFault 0x0 4 0xDE
    ${word}=           Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${word}    0xDEDEDEDE
    # Upper half untouched.
    ${upper}=          Execute Command    sysbus ReadDoubleWord 0x10000004
    Should Be Equal As Integers    ${upper}    0xFFFFFFFF

MRAM FaultAtWordWrite Injects At Specified Write Index
    Create MRAM Machine
    Execute Command    sysbus.mram FaultAtWordWrite 2
    # Write 1: succeeds.
    Execute Command    sysbus WriteQuadWord 0x10000000 0x1111111111111111
    # Write 2: triggers partial write (fault at word write index 2).
    Execute Command    sysbus WriteQuadWord 0x10000008 0x2222222222222222
    ${word1}=          Execute Command    sysbus ReadQuadWord 0x10000000
    Should Be Equal As Integers    ${word1}    0x1111111111111111
    # Second word: first half programmed, second half erased.
    ${word2}=          Execute Command    sysbus ReadQuadWord 0x10000008
    Should Be Equal As Integers    ${word2}    0x0000000022222222

MRAM Byte Read Write Without Word Semantics
    Create MRAM Machine
    Execute Command    sysbus.mram EnforceWordWriteSemantics false
    Execute Command    sysbus.mram InjectPartialWrite 0x0
    Execute Command    sysbus WriteByte 0x10000003 0x42
    ${b}=              Execute Command    sysbus ReadByte 0x10000003
    Should Be Equal As Integers    ${b}    0x42
    ${last_fault}=     Execute Command    sysbus.mram LastFaultInjected
    Should Be Equal As Strings    ${last_fault}    False    strip_spaces=True
    ${fault_ever}=     Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fault_ever}    True    strip_spaces=True

MRAM FaultEverFired Is Sticky
    Create MRAM Machine
    Execute Command    sysbus.mram FaultAtWordWrite 1
    # Write 1: triggers fault.
    Execute Command    sysbus WriteQuadWord 0x10000000 0x1111111111111111
    ${fired}=          Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fired}    True    strip_spaces=True
    # Write 2: subsequent write should NOT clear FaultEverFired.
    Execute Command    sysbus.mram FaultAtWordWrite 999999
    Execute Command    sysbus WriteQuadWord 0x10000008 0x2222222222222222
    ${still_fired}=    Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${still_fired}    True    strip_spaces=True

MRAM RetainOldDataOnFault Preserves Upper Half
    Create MRAM Machine
    # Pre-fill word with known data.
    Execute Command    sysbus WriteQuadWord 0x10000000 0xDDCCBBAA44332211
    Execute Command    sysbus.mram FaultAtWordWrite 2
    Execute Command    sysbus.mram RetainOldDataOnFault true
    # Overwrite: fault fires, first half programmed, second half retains old data.
    Execute Command    sysbus WriteQuadWord 0x10000000 0xFFFFFFFFFFFFFFFF
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    # Upper 4 bytes should be old data (0xDDCCBBAA), not EraseFill (0x00).
    Should Be Equal As Integers    ${word}    0xDDCCBBAAFFFFFFFF

MRAM BitCorruption Flips Bits In Written Word
    Create MRAM Machine
    Execute Command    sysbus.mram WriteFaultMode 1
    Execute Command    sysbus.mram FaultAtWordWrite 1
    Execute Command    sysbus.mram CorruptionSeed 42
    Execute Command    sysbus WriteQuadWord 0x10000000 0xAAAAAAAAAAAAAAAA
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    # With seed 42, bit corruption produces this deterministic result.
    Should Be Equal As Integers    ${word}    0xABEAAAAAAAA8AAAA
    ${fired}=          Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fired}    True    strip_spaces=True

MRAM WriteTrace Records Word Offsets
    Create MRAM Machine
    Execute Command    sysbus.mram WriteTraceEnabled true
    Execute Command    sysbus WriteQuadWord 0x10000000 0x1111111111111111
    Execute Command    sysbus WriteQuadWord 0x10000008 0x2222222222222222
    ${trace}=          Execute Command    sysbus.mram WriteTraceToString
    Should Contain     ${trace}    1,0
    Should Contain     ${trace}    2,8
    # Clear and verify empty.
    Execute Command    sysbus.mram WriteTraceClear
    ${empty}=          Execute Command    sysbus.mram WriteTraceToString
    Should Be Equal As Strings    ${empty}    ${EMPTY}    strip_spaces=True

MRAM ReadFault Corrupts Returned Value Without Modifying NVM
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0xAABBCCDD
    # Arm a read fault at offset 0 with a known seed.
    Execute Command    sysbus.mram ReadFaultAddress 0x0
    Execute Command    sysbus.mram ReadFaultSeed 42
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultEnabled true
    # First read triggers the fault.
    ${corrupted}=      Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${corrupted}    0xA2BBCCDD
    ${fired}=          Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${fired}    True    strip_spaces=True
    # NVM contents are unchanged.
    Execute Command    sysbus.mram ReadFaultEnabled false
    Execute Command    sysbus.mram ReadFaultFired false
    Execute Command    sysbus.mram ReadFaultAddress -1
    ${raw}=            Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${raw}    0xAABBCCDD

MRAM ReadFault Is One Shot
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0x12345678
    Execute Command    sysbus.mram ReadFaultAddress 0x0
    Execute Command    sysbus.mram ReadFaultSeed 99
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultEnabled true
    # First read: corrupted.
    ${first}=          Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${first}    0x12345679
    # Second read: clean (fault already fired and auto-disarmed).
    ${second}=         Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${second}    0x12345678

MRAM ReadFault SkipCount Delays Firing
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0xDEADBEEF
    Execute Command    sysbus.mram ReadFaultAddress 0x0
    Execute Command    sysbus.mram ReadFaultSeed 77
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultSkipCount 2
    Execute Command    sysbus.mram ReadFaultEnabled true
    # Reads 1 and 2: skipped, return clean value.
    ${r1}=             Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${r1}    0xDEADBEEF
    ${r2}=             Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${r2}    0xDEADBEEF
    # Read 3: fires.
    ${r3}=             Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${r3}    0xDEADBEEB
    ${fired}=          Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${fired}    True    strip_spaces=True

MRAM ReadFault Ignores Non Overlapping Address
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0x11111111
    Execute Command    sysbus WriteDoubleWord 0x10000010 0x22222222
    Execute Command    sysbus.mram ReadFaultAddress 0x10
    Execute Command    sysbus.mram ReadFaultSeed 55
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultEnabled true
    # Read at non-armed address: clean.
    ${clean}=          Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${clean}    0x11111111
    ${not_fired}=      Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${not_fired}    False    strip_spaces=True
    # Read at armed address: corrupted.
    ${corrupted}=      Execute Command    sysbus ReadDoubleWord 0x10000010
    Should Be Equal As Integers    ${corrupted}    0x22222232

MRAM Reset Preserves Data But Clears Fault State
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0xCAFEBABE
    Execute Command    sysbus.mram FaultAtWordWrite 2
    Execute Command    sysbus WriteQuadWord 0x10000008 0x1111111111111111
    Execute Command    sysbus.mram ReadFaultAddress 0x0
    Execute Command    sysbus.mram ReadFaultEnabled true
    ${fired_before}=   Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fired_before}    True    strip_spaces=True
    # Reset clears fault state but preserves NVM data.
    Execute Command    machine Reset
    ${data}=           Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Integers    ${data}    0xCAFEBABE
    ${fired_after}=    Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fired_after}    False    strip_spaces=True
    ${writes}=         Execute Command    sysbus.mram TotalWordWrites
    Should Be Equal As Integers    ${writes}    0
    ${write_target}=   Execute Command    sysbus.mram FaultAtWordWrite
    Should Be Equal As Strings    ${write_target}    0xFFFFFFFFFFFFFFFF    strip_spaces=True
    ${read_enabled}=   Execute Command    sysbus.mram ReadFaultEnabled
    Should Be Equal As Strings    ${read_enabled}    False    strip_spaces=True
    ${read_address}=   Execute Command    sysbus.mram ReadFaultAddress
    Should Be Equal As Strings    ${read_address}    0xFFFFFFFFFFFFFFFF    strip_spaces=True

MRAM ReadFault On Byte Access
    Create MRAM Machine
    Execute Command    sysbus WriteByte 0x10000000 0xAA
    Execute Command    sysbus.mram ReadFaultAddress 0x0
    Execute Command    sysbus.mram ReadFaultSeed 123
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultEnabled true
    ${corrupted}=      Execute Command    sysbus ReadByte 0x10000000
    Should Be Equal As Integers    ${corrupted}    0xAB
    ${fired}=          Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${fired}    True    strip_spaces=True

MRAM ReadFault On Direct Bulk Access
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0xAABBCCDD
    Execute Command    sysbus.mram ReadFaultAddress 0x0
    Execute Command    sysbus.mram ReadFaultSeed 42
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultEnabled true
    ${first}=          Execute Command    python "import System; m=monitor.Machine['sysbus.mram']; r=m.ReadBytes(0,4); print('0x%08x' % System.BitConverter.ToUInt32(r,0))"
    Should Be Equal As Strings    ${first}    0xaabbccd5    strip_spaces=True
    ${fired}=          Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${fired}    True    strip_spaces=True
    ${second}=         Execute Command    python "import System; m=monitor.Machine['sysbus.mram']; r=m.ReadBytes(0,4); print('0x%08x' % System.BitConverter.ToUInt32(r,0))"
    Should Be Equal As Strings    ${second}    0xaabbccdd    strip_spaces=True

MRAM Rejects Non Divisible Word Size
    Create MRAM Machine
    Run Keyword And Expect Error    *WordSize must be a power of two between 2 and the memory size, and divide the memory size evenly*
    ...    Execute Command    python "from Antmicro.Renode.Peripherals.Memory import MRAMMemory; MRAMMemory(10, 8)"

MRAM RetainOldDataOnFault False Uses EraseFill
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0xDDCCBBAA44332211
    Execute Command    sysbus.mram FaultAtWordWrite 2
    Execute Command    sysbus.mram RetainOldDataOnFault false
    Execute Command    sysbus WriteQuadWord 0x10000000 0xFFFFFFFFFFFFFFFF
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    # Upper 4 bytes should be EraseFill (0x00), not old data.
    Should Be Equal As Integers    ${word}    0x00000000FFFFFFFF

MRAM Write Spanning Two Words Counts Both
    Create MRAM Machine
    # Writing 8 bytes starting at offset 4 spans two 8-byte words:
    # word 0 (0x00-0x07) and word 1 (0x08-0x0F).
    Execute Command    sysbus WriteQuadWord 0x10000004 0xAAAAAAAABBBBBBBB
    ${count}=          Execute Command    sysbus.mram TotalWordWrites
    Should Be Equal As Integers    ${count}    2

MRAM GetWordWriteCount Matches TotalWordWrites
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0x1111111111111111
    Execute Command    sysbus WriteQuadWord 0x10000008 0x2222222222222222
    Execute Command    sysbus WriteQuadWord 0x10000010 0x3333333333333333
    ${prop}=           Execute Command    sysbus.mram TotalWordWrites
    ${method}=         Execute Command    sysbus.mram GetWordWriteCount
    Should Be Equal As Integers    ${prop}    3
    Should Be Equal As Integers    ${method}    3

MRAM ReadFault On QuadWord Access
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0x0123456789ABCDEF
    Execute Command    sysbus.mram ReadFaultAddress 0x4
    Execute Command    sysbus.mram ReadFaultSeed 123
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultEnabled true
    ${corrupted}=      Execute Command    sysbus ReadQuadWord 0x10000000
    Should Be Equal As Integers    ${corrupted}    0x0123456788ABCDEF
    ${clean}=          Execute Command    sysbus ReadQuadWord 0x10000000
    Should Be Equal As Integers    ${clean}    0x0123456789ABCDEF

MRAM Out Of Bounds Write Is Ignored
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x1007FFFC 0xAABBCCDDEEFF0011
    ${tail}=           Execute Command    sysbus ReadDoubleWord 0x1007FFFC
    Should Be Equal As Integers    ${tail}    0

MRAM ReadFault Ignores Out Of Bounds Access
    Create MRAM Machine
    Execute Command    sysbus.mram ReadFaultAddress 0x7FFFF
    Execute Command    sysbus.mram ReadFaultSeed 42
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultEnabled true
    ${out_of_bounds}=  Execute Command    sysbus ReadDoubleWord 0x1007FFFE
    Should Be Equal As Integers    ${out_of_bounds}    0
    ${fired}=          Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${fired}    False    strip_spaces=True
    ${enabled}=        Execute Command    sysbus.mram ReadFaultEnabled
    Should Be Equal As Strings    ${enabled}    True    strip_spaces=True
    ${final_byte}=     Execute Command    sysbus ReadByte 0x1007FFFF
    Should Be Equal As Integers    ${final_byte}    0x08
    ${fired}=          Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${fired}    True    strip_spaces=True

MRAM Manual Faults Set Sticky Flag
    Create MRAM Machine
    Execute Command    sysbus.mram InjectPartialWrite 0x0
    ${partial_fired}=  Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${partial_fired}    True    strip_spaces=True
    Execute Command    sysbus.mram FaultEverFired false
    Execute Command    sysbus.mram InjectFault 0x8 4 0xA5
    ${fault_fired}=    Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fault_fired}    True    strip_spaces=True

MRAM Bulk Write Uses Word Semantics
    Create MRAM Machine
    Execute Command    python "import System; m=monitor.Machine['sysbus.mram']; d=System.Array[System.Byte]([1,2,3,4,5,6,7,8]); m.WriteBytes(4,d,0,8)"
    ${lower}=          Execute Command    sysbus ReadQuadWord 0x10000000
    ${upper}=          Execute Command    sysbus ReadQuadWord 0x10000008
    ${count}=          Execute Command    sysbus.mram TotalWordWrites
    Should Be Equal As Integers    ${lower}    0x0403020100000000
    Should Be Equal As Integers    ${upper}    0x0000000008070605
    Should Be Equal As Integers    ${count}    2
