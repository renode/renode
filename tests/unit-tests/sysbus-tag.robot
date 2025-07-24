*** Variables ***
${ORDINARY_TAG_START}               0x0
${OVERRIDING_TAG_START}             0x10
${TAG_SIZE}                         0x8
${TAG_VALUE_BYTE}                   0xF0
${TAG_VALUE_WORD}                   0xF1F0
${TAG_VALUE_DWORD}                  0xF3F2F1F0
${TAG_VALUE_QWORD}                  0xF7F6F5F4F3F2F1F0
${MEM_START}                        0x0
${NOT_COVERED_MEM_START}            0x20
${MEM_SIZE}                         0x30
${MEM_VALUE_BYTE}                   0x01
${MEM_VALUE_WORD}                   0x0101
${MEM_VALUE_DWORD}                  0x01010101

*** Keywords ***
Create Machine With Tags An Array Memory
    #  Memory layout:

    # |00|01|02|03|04|05|06|07|08|09|0A|0B|0C|0D|0E|0F|10|11|12|13|14|15|16|17|18|19|1A|1B|1C|1D|1E|1F|20|...|2F|
    # | ------------------------------------------------------------------------------------------------------- |
    # | ordinary tag  | overriding tag  |  ---  |
    # | memory filled with 0x1 at each cell  |

    Execute Command                 mach create
    Execute Command                 sysbus Tag <${OVERRIDING_TAG_START} ${TAG_SIZE}> "overridingTag" ${TAG_VALUE_QWORD} overridePeripheralAccesses=True
    Execute Command                 sysbus Tag <${ORDINARY_TAG_START} ${TAG_SIZE}> "ordinaryTag" ${TAG_VALUE_QWORD} overridePeripheralAccesses=False
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.ArrayMemory @ sysbus ${MEM_START} { size : ${MEM_SIZE}; initialValue: ${MEM_VALUE_BYTE} }"

*** Test Cases ***
Overriding Tag Should Override ReadByte Access To A Peripheral
    Create Machine With Tags An Array Memory

    ${read_byte}=                   Execute Command  sysbus ReadByte ${OVERRIDING_TAG_START}
    Should Be Equal As Numbers      ${TAG_VALUE_BYTE}  ${read_byte}

Overriding Tag Should Override ReadWord Access To A Peripheral
    Create Machine With Tags An Array Memory

    ${read_word}=                   Execute Command  sysbus ReadWord ${OVERRIDING_TAG_START}
    Should Be Equal As Numbers      ${TAG_VALUE_WORD}  ${read_word}

Ordinary Tag Should Not Override ReadByte Access To A Peripheral
    Create Machine With Tags An Array Memory

    ${read_byte}=                   Execute Command  sysbus ReadByte ${ORDINARY_TAG_START}
    Should Be Equal As Numbers      ${MEM_VALUE_BYTE}  ${read_byte}

Ordinary Tag Should Not Override ReadWord Access To A Peripheral
    Create Machine With Tags An Array Memory

    ${read_word}=                   Execute Command  sysbus ReadWord ${ORDINARY_TAG_START}
    Should Be Equal As Numbers      ${MEM_VALUE_WORD}  ${read_word}

Write To An Overriding Tag Should Not Write To Peripheral
    Create Machine With Tags An Array Memory

    ${SOME_VALUE}=                  Set Variable  0x11
    Execute Command                 sysbus WriteByte ${OVERRIDING_TAG_START} ${SOME_VALUE}
    Execute Command                 sysbus RemoveTag ${OVERRIDING_TAG_START}
    ${read_byte}=                   Execute Command  sysbus ReadByte ${OVERRIDING_TAG_START}
    Should Be Equal As Numbers      ${read_byte}  ${MEM_VALUE_BYTE}

