*** Variables ***
# ARM Thumb "b ." (branch to self) = 0xE7FE
${THUMB_LOOP}=          0xE7FE

*** Keywords ***
Create Machine With Array Memory
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @${CURDIR}/platform_array.repl
    Create Log Tester       0

Create Machine With Non Mapped Executable Memory
    Execute Command         mach create
    Execute Command         include @${CURDIR}/ExecutableByteMemory.cs
    Execute Command         machine LoadPlatformDescription @${CURDIR}/platform_custom.repl
    Create Log Tester       0

Setup CPU And Write Loop
    # Write ARM Thumb "b ." (branch to self) at 0x20000000
    Execute Command         sysbus WriteWord 0x20000000 ${THUMB_LOOP}
    Execute Command         cpu PC 0x20000000

*** Test Cases ***
Should Execute Code From ArrayMemory
    [Documentation]         Control test: ArrayMemory (non-IMapped, built-in) should
    ...                     already support instruction fetch via IO_MEM_EXECUTABLE_IO.
    [Timeout]               60 seconds
    Create Machine With Array Memory
    Setup CPU And Write Loop
    Execute Command         emulation RunFor "0.0001"
    Should Not Be In Log    CPU abort

Should Execute Code From Non IMapped Peripheral
    [Documentation]         Reproduces Renode bug #877: RunFor aborts when
    ...                     instruction fetches hit a non-IMapped C# peripheral.
    [Timeout]               60 seconds
    Create Machine With Non Mapped Executable Memory
    Setup CPU And Write Loop
    Execute Command         emulation RunFor "0.0001"
    Should Not Be In Log    CPU abort
