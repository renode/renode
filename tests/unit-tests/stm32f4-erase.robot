*** Keywords ***
Create Machine
    Execute Command                         using sysbus
    Execute Command                         mach create
    Execute Command                         machine LoadPlatformDescription @platforms/boards/stm32f4_discovery-kit.repl

Unlock Control Register
    Execute Command                         sysbus WriteDoubleWord 0x40023c04 0x45670123
    Execute Command                         sysbus WriteDoubleWord 0x40023c04 0xcdef89ab

*** Test Cases ***

Should Ignore Erase When MER And SER Are Reset
    Create Machine
    Create Log Tester                       3

    Execute Command                         sysbus WriteDoubleWord 0x08000000 0xdeadbeef
    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x08000000
    Should Be True      """${read_result}""".strip() == "0xDEADBEEF"

    Unlock Control Register

    Execute Command                         sysbus WriteDoubleWord 0x40023c10 0x00010000    ## Try to perform erase with both SER and MER unset

    Wait For Log Entry                      Tried to erase flash, but MER and SER are reset. This should be forbidden, ignoring...
    
    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x08000000                ## Should ignore erase attempt
    Should Be True      """${read_result}""".strip() == "0xDEADBEEF"

Should Perform Mass Erase
    Create Machine

    Execute Command                         sysbus WriteDoubleWord 0x08000000 0xdeadbeef
    Execute Command                         sysbus WriteDoubleWord 0x080E0000 0xcafebabe
    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x08000000
    Should Be True      """${read_result}""".strip() == "0xDEADBEEF"
    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x080E0000
    Should Be True      """${read_result}""".strip() == "0xCAFEBABE"

    Unlock Control Register

    Execute Command                         sysbus WriteDoubleWord 0x40023c10 0x00010004    ## Set MER and try to perform mass erase

    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x08000000
    Should Be True      """${read_result}""".strip() == "0xFFFFFFFF"
    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x080E0000
    Should Be True      """${read_result}""".strip() == "0xFFFFFFFF"

Should Perform Sector Erase
    Create Machine

    Execute Command                         sysbus WriteDoubleWord 0x08000000 0xdeadbeef
    Execute Command                         sysbus WriteDoubleWord 0x080E0000 0xcafebabe
    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x08000000
    Should Be True      """${read_result}""".strip() == "0xDEADBEEF"
    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x080E0000
    Should Be True      """${read_result}""".strip() == "0xCAFEBABE"

    Unlock Control Register

    Execute Command                         sysbus WriteDoubleWord 0x40023c10 0x0001005a    ## Set SER and SNB to sector 11, and try to perform sector erase

    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x08000000
    Should Be True      """${read_result}""".strip() == "0xDEADBEEF"
    ${read_result} =    Execute Command     sysbus ReadDoubleWord 0x080E0000
    Should Be True      """${read_result}""".strip() == "0xFFFFFFFF"
