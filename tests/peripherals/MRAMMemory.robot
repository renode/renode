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
