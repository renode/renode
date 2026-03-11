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
    Should Be Equal As Numbers    ${read_back}    0xAABBCCDD

MRAM Word Write Uses Erase Then Program
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0xFFEEDDCCBBAA9988
    # Overwriting only the upper 4 bytes triggers a full word erase+program cycle.
    Execute Command    sysbus WriteDoubleWord 0x10000004 0x11223344
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    Should Be Equal As Numbers    ${word}    0x11223344BBAA9988

MRAM InjectPartialWrite Corrupts Second Half Of Word
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0xA1A2A3A4B1B2B3B4
    Execute Command    sysbus.mram InjectPartialWrite 0x0
    # First 4 bytes survive, last 4 bytes are zeroed (erase fill).
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    Should Be Equal As Numbers    ${word}    0x00000000B1B2B3B4

MRAM InjectFault Overwrites Region With Pattern
    Create MRAM Machine
    Execute Command    sysbus WriteQuadWord 0x10000000 0xFFFFFFFFFFFFFFFF
    Execute Command    sysbus.mram InjectFault 0x0 4 0xDE
    ${word}=           Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Numbers    ${word}    0xDEDEDEDE
    # Upper half untouched.
    ${upper}=          Execute Command    sysbus ReadDoubleWord 0x10000004
    Should Be Equal As Numbers    ${upper}    0xFFFFFFFF

MRAM FaultAtWordWrite Injects At Specified Write Index
    Create MRAM Machine
    Execute Command    sysbus.mram FaultAtWordWrite 2
    # Write 1: succeeds.
    Execute Command    sysbus WriteQuadWord 0x10000000 0x1111111111111111
    # Write 2: triggers partial write (fault at word write index 2).
    Execute Command    sysbus WriteQuadWord 0x10000008 0x2222222222222222
    ${word1}=          Execute Command    sysbus ReadQuadWord 0x10000000
    Should Be Equal As Numbers    ${word1}    0x1111111111111111
    # Second word: first half programmed, second half erased.
    ${word2}=          Execute Command    sysbus ReadQuadWord 0x10000008
    Should Not Be Equal As Numbers    ${word2}    0x2222222222222222

MRAM Byte Read Write Without Word Semantics
    Create MRAM Machine
    Execute Command    sysbus.mram EnforceWordWriteSemantics false
    Execute Command    sysbus WriteByte 0x10000003 0x42
    ${b}=              Execute Command    sysbus ReadByte 0x10000003
    Should Be Equal As Numbers    ${b}    0x42

MRAM FaultEverFired Is Sticky
    Create MRAM Machine
    Execute Command    sysbus.mram FaultAtWordWrite 1
    # Write 1: triggers fault.
    Execute Command    sysbus WriteQuadWord 0x10000000 0x1111111111111111
    ${fired}=          Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fired}    True
    # Write 2: subsequent write should NOT clear FaultEverFired.
    Execute Command    sysbus.mram FaultAtWordWrite 999999
    Execute Command    sysbus WriteQuadWord 0x10000008 0x2222222222222222
    ${still_fired}=    Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${still_fired}    True

MRAM RetainOldDataOnFault Preserves Upper Half
    Create MRAM Machine
    # Pre-fill word with known data.
    Execute Command    sysbus WriteQuadWord 0x10000000 0xDDCCBBAA44332211
    Execute Command    sysbus.mram FaultAtWordWrite 1
    Execute Command    sysbus.mram RetainOldDataOnFault true
    # Overwrite: fault fires, first half programmed, second half retains old data.
    Execute Command    sysbus WriteQuadWord 0x10000000 0xFFFFFFFFFFFFFFFF
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    # Upper 4 bytes should be old data (0xDDCCBBAA), not EraseFill (0x00).
    Should Be Equal As Numbers    ${word}    0xDDCCBBAAFFFFFFFF

MRAM BitCorruption Flips Bits In Written Word
    Create MRAM Machine
    Execute Command    sysbus.mram WriteFaultMode 1
    Execute Command    sysbus.mram FaultAtWordWrite 1
    Execute Command    sysbus.mram CorruptionSeed 42
    Execute Command    sysbus WriteQuadWord 0x10000000 0xAAAAAAAAAAAAAAAA
    ${word}=           Execute Command    sysbus ReadQuadWord 0x10000000
    # Bit corruption should alter the written value (exact result depends on LCG).
    Should Not Be Equal As Numbers    ${word}    0xAAAAAAAAAAAAAAAA
    ${fired}=          Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fired}    True

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
    Should Be Empty    ${empty}

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
    Should Not Be Equal As Numbers    ${corrupted}    0xAABBCCDD
    ${fired}=          Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${fired}    True
    # NVM contents are unchanged.
    Execute Command    sysbus.mram ReadFaultEnabled false
    Execute Command    sysbus.mram ReadFaultFired false
    Execute Command    sysbus.mram ReadFaultAddress -1
    ${raw}=            Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Numbers    ${raw}    0xAABBCCDD

MRAM ReadFault Is One Shot
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0x12345678
    Execute Command    sysbus.mram ReadFaultAddress 0x0
    Execute Command    sysbus.mram ReadFaultSeed 99
    Execute Command    sysbus.mram ReadFaultBitFlips 1
    Execute Command    sysbus.mram ReadFaultEnabled true
    # First read: corrupted.
    ${first}=          Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Not Be Equal As Numbers    ${first}    0x12345678
    # Second read: clean (fault already fired and auto-disarmed).
    ${second}=         Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Numbers    ${second}    0x12345678

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
    Should Be Equal As Numbers    ${r1}    0xDEADBEEF
    ${r2}=             Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Numbers    ${r2}    0xDEADBEEF
    # Read 3: fires.
    ${r3}=             Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Not Be Equal As Numbers    ${r3}    0xDEADBEEF
    ${fired}=          Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${fired}    True

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
    Should Be Equal As Numbers    ${clean}    0x11111111
    ${not_fired}=      Execute Command    sysbus.mram ReadFaultFired
    Should Be Equal As Strings    ${not_fired}    False
    # Read at armed address: corrupted.
    ${corrupted}=      Execute Command    sysbus ReadDoubleWord 0x10000010
    Should Not Be Equal As Numbers    ${corrupted}    0x22222222

MRAM Reset Preserves Data But Clears Fault State
    Create MRAM Machine
    Execute Command    sysbus WriteDoubleWord 0x10000000 0xCAFEBABE
    Execute Command    sysbus.mram FaultAtWordWrite 1
    Execute Command    sysbus WriteQuadWord 0x10000008 0x1111111111111111
    ${fired_before}=   Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fired_before}    True
    # Reset clears fault state but preserves NVM data.
    Execute Command    machine Reset
    ${data}=           Execute Command    sysbus ReadDoubleWord 0x10000000
    Should Be Equal As Numbers    ${data}    0xCAFEBABE
    ${fired_after}=    Execute Command    sysbus.mram FaultEverFired
    Should Be Equal As Strings    ${fired_after}    False
    ${writes}=         Execute Command    sysbus.mram TotalWordWrites
    Should Be Equal As Numbers    ${writes}    0
