*** Variables ***
${VALID_PLATFORM}                          ram: Memory.MappedMemory @ sysbus 0x40_000_000  { size: 8_0000_00_0 }
${INVALID_PLATFORM1}                       ram: Memory.MappedMemory @ sysbus _0x40_000_000 { size: 8_0000_00_0 }
${INVALID_PLATFORM2}                       ram: Memory.MappedMemory @ sysbus 0x40_000_000  { size: _8_0000_00_0 }
${INVALID_PLATFORM3}                       ram: Memory.MappedMemory @ sysbus 0x40_000_000  { size: 8_0000_00_0_ }
${INVALID_PLATFORM4}                       ram: Memory.MappedMemory @ sysbus 0_x40_000_000  { size: 8_0000_00_0 }
${INVALID_PLATFORM5}                       ram: Memory.MappedMemory @ sysbus 0x_40_000_000  { size: 8_0000_00_0 }

*** Test Cases ***
Should Handle Number Separator
    Execute Command               mach create
    Execute Command               machine LoadPlatformDescriptionFromString "${VALID_PLATFORM}"

    ${out}=  Execute Command      sysbus WhatIsAt 0x30000000
    Should Be Empty               ${out}

    # Verify that both parameters that use digit separator resolved correctly
    ${out}=  Execute Command      sysbus WhatPeripheralIsAt 0x40000000
    Should Be Equal As Strings    ${out.strip()}       Antmicro.Renode.Peripherals.Memory.MappedMemory

    ${out}=  Execute Command      sysbus.ram Size
    Should Be Equal As Numbers    ${out}       0x4C4B400

Should Not Handle Invalid Cases
    Execute Command                 mach create
    Run Keyword And Expect Error    *Error E00: Syntax error, unexpected '_'; expected end of input*                                                      Execute Command               machine LoadPlatformDescriptionFromString "${INVALID_PLATFORM1}"
    Run Keyword And Expect Error    *Error E00: Syntax error, unexpected '_'; expected constructor or property value or none keyword or empty keyword*    Execute Command               machine LoadPlatformDescriptionFromString "${INVALID_PLATFORM2}"
    Run Keyword And Expect Error    *Error E00: Syntax error, unexpected '_'; expected attribute list end*                                                Execute Command               machine LoadPlatformDescriptionFromString "${INVALID_PLATFORM3}"
    Run Keyword And Expect Error    *Error E00: Syntax error, unexpected '_'; expected end of input*                                                      Execute Command               machine LoadPlatformDescriptionFromString "${INVALID_PLATFORM4}"
    Run Keyword And Expect Error    *Error E00: Syntax error, unexpected 'x'; expected end of input*                                                      Execute Command               machine LoadPlatformDescriptionFromString "${INVALID_PLATFORM5}"
