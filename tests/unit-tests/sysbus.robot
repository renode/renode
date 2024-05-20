*** Variables ***
# The values and addresses are totally arbitrary.
${init_value_0x40}             0x11
${init_value_0x80}             0x22
${init_value_0x100}            0x33
${init_value_0x140}            0x44
${init_value_0x180}            0x55

${per-core-memory}=            SEPARATOR=
...                            """
...                            memory2: Memory.ArrayMemory @ { sysbus new Bus.BusPointRegistration { address: 0x200; cpu: mockCpu0 } } ${\n}
...                            ${SPACE*4}size: 0x100                                                                                   ${\n}
...                                                                                                                                    ${\n}
...                            memory3: Memory.ArrayMemory @ { sysbus new Bus.BusPointRegistration { address: 0x250; cpu: mockCpu1 } } ${\n}
...                            ${SPACE*4}size: 0x500                                                                                   ${\n}
...                            """

*** Keywords ***
Read From Sysbus And Check If Blocked
    [Arguments]  ${address}  ${expected_value}=0x0  ${should_be_blocked}=True  ${access_type}=Byte  ${access_size}=1  ${cpu_context}=

    ${blocked_read_log}=           Set Variable    Tried to read ${access_size} bytes at ${address} which is inside a locked address range, returning 0

    ${read_value}=                 Execute Command    sysbus Read${access_type} ${address} ${cpu_context}
    IF    ${should_be_blocked}
        Wait For Log Entry         ${blocked_read_log}
    ELSE
        Should Not Be In Log       ${blocked_read_log}
    END
    Should Be Equal As Integers    ${read_value}  ${expected_value}  base=16

Should Block Read Byte
    [Arguments]  ${address}  ${cpu_context}=
    Read From Sysbus And Check If Blocked    ${address}     cpu_context=${cpu_context}

Should Block Read Quad
    [Arguments]  ${address}  ${cpu_context}=
    Read From Sysbus And Check If Blocked    ${address}  access_type=QuadWord  access_size=8  cpu_context=${cpu_context}

Should Read Byte
    [Arguments]  ${address}  ${expected_value}  ${cpu_context}=
    Read From Sysbus And Check If Blocked    ${address}  ${expected_value}  should_be_blocked=False  cpu_context=${cpu_context}

Should Read Quad
    [Arguments]  ${address}  ${expected_value}  ${cpu_context}=
    Read From Sysbus And Check If Blocked    ${address}  ${expected_value}  should_be_blocked=False  access_type=QuadWord  access_size=8  cpu_context=${cpu_context}

Write To Sysbus And Check If Blocked
    [Arguments]  ${address}  ${value}  ${should_be_blocked}=True  ${access_type}=Byte  ${access_size}=1  ${cpu_context}=

    Execute Command             sysbus Write${access_type} ${address} ${value} ${cpu_context}
    ${blocked_write_log}=       Set Variable  Tried to write ${access_size} bytes (${value}) at ${address} which is inside a locked address range, write ignored
    IF    ${should_be_blocked}
        Wait For Log Entry      ${blocked_write_log}
    ELSE
        Should Not Be In Log    ${blocked_write_log}
    END

Should Block Write Byte
    [Arguments]  ${address}  ${value}  ${cpu_context}=
    Write To Sysbus And Check If Blocked    ${address}  ${value}  cpu_context=${cpu_context}

Should Block Write Quad
    [Arguments]  ${address}  ${value}  ${cpu_context}=
    Write To Sysbus And Check If Blocked    ${address}  ${value}  access_type=QuadWord  access_size=8  cpu_context=${cpu_context}

Should Write Byte
    [Arguments]  ${address}  ${value}  ${cpu_context}=
    Write To Sysbus And Check If Blocked    ${address}  ${value}  should_be_blocked=False  cpu_context=${cpu_context}

Should Write Quad
    [Arguments]  ${address}  ${value}  ${cpu_context}=
    Write To Sysbus And Check If Blocked    ${address}  ${value}  should_be_blocked=False  access_type=QuadWord  access_size=8  cpu_context=${cpu_context}

Should Write Byte To Non Existing Peripheral
    [Arguments]  ${address}  ${value}  ${cpu_context}=
    Execute Command            sysbus WriteByte ${address} ${value} ${cpu_context}
    Wait For Log Entry         WriteByte to non existing peripheral at ${address}, value ${value}

*** Test Cases ***
Test Reading Bytes From Locked Sysbus Range
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescriptionFromString "memory: Memory.ArrayMemory @ sysbus 0x100 { size: 0x100 }"
    Create Log Tester          0

    Execute Command            sysbus Tag <0x40 1> "test" ${init_value_0x40}
    Execute Command            sysbus Tag <0x80 1> "test" ${init_value_0x80}
    Should Write Byte          0x100  ${init_value_0x100}
    Should Write Byte          0x140  ${init_value_0x140}
    Should Write Byte          0x180  ${init_value_0x180}

    Should Read Byte           0x40   ${init_value_0x40}
    Should Read Byte           0x80   ${init_value_0x80}
    Should Read Byte           0x100  ${init_value_0x100}
    Should Read Byte           0x140  ${init_value_0x140}
    Should Read Byte           0x180  ${init_value_0x180}

    Provides                   sysbus-with-test-values

    Execute Command            sysbus SetAddressRangeLocked <0x0 0x200> true
    Should Block Read Byte     0x40
    Should Block Read Byte     0x80
    Should Block Read Byte     0x100
    Should Block Read Byte     0x140
    Should Block Read Byte     0x180

    Provides                   sysbus-with-test-values-locked-below-0x200

Test Accessing Locked Sysbus Range Boundaries With Wide Accesses
    Requires                   sysbus-with-test-values
    ${quad_test_value}=        Set Variable  0xFEDCBA9876543210

    Execute Command            sysbus SetAddressRangeLocked <0x144, 0x17C> true

    # Wide accesses should only succeed if all the bytes are outside a locked range.
    Should Block Read Quad     0x140
    Should Block Write Quad    0x140  ${quad_test_value}
    Should Read Byte           0x140  ${init_value_0x140}

    # 0x17C is the address of the last locked byte.
    Should Block Read Quad     0x17C
    Should Block Write Quad    0x17C  ${quad_test_value}

    Should Read Byte           0x180  ${init_value_0x180}

    Should Write Quad          0x17E  ${quad_test_value}
    Should Read Quad           0x17E  ${quad_test_value}

Test Reading After Unlocking Parts Of Locked Sysbus Range
    Requires                   sysbus-with-test-values-locked-below-0x200

    # Reconfigure locked ranges to unlock arbitrary ranges containing 0x80 and 0x140.
    Execute Command            sysbus SetAddressRangeLocked <0x60, 0x15F> false
    Execute Command            sysbus SetAddressRangeLocked <0x100, 0x13F> true

    Should Block Read Byte     0x40
    Should Read Byte           0x80   ${init_value_0x80}
    Should Block Read Byte     0x100
    Should Read Byte           0x140  ${init_value_0x140}
    Should Block Read Byte     0x180

Test Writing To A Locked Sysbus Range
    Requires                   sysbus-with-test-values

    ${new_value_0x100}=        Set Variable  0x66
    ${new_value_0x140}=        Set Variable  0x77

    # In the first round of writing, only the write to 0x100 should succeed
    # and 0x140 in the second round. 0x180 is locked in both writing rounds
    # so read at the end should return its initial value.

    Execute Command            sysbus SetAddressRangeLocked <0x140, 0x1FF> true
    Should Write Byte          0x100  ${new_value_0x100}
    Should Block Write Byte    0x140  ${new_value_0x100}
    Should Block Write Byte    0x180  ${new_value_0x100}

    Execute Command            sysbus SetAddressRangeLocked <0x100, 0x1FF> true
    Execute Command            sysbus SetAddressRangeLocked <0x140, 0x140> false
    Should Block Write Byte    0x100  ${new_value_0x140}
    Should Write Byte          0x140  ${new_value_0x140}
    Should Block Write Byte    0x180  ${new_value_0x140}

    Execute Command            sysbus SetAddressRangeLocked <0x100, 0x1FF> false
    Should Read Byte           0x100  ${new_value_0x100}
    Should Read Byte           0x140  ${new_value_0x140}
    Should Read Byte           0x180  ${init_value_0x180}

Test Writing To A Locked Sysbus Range With CPU Context
    Requires                   sysbus-with-test-values
    # Architecture doesn't matter, these CPUs are just mocks
    Execute Command            machine LoadPlatformDescriptionFromString "mockCpu0: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command            machine LoadPlatformDescriptionFromString "mockCpu1: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"

    Provides                   sysbus-with-mock-cpus

    ${new_value_0x100}=        Set Variable  0x66
    ${new_value_0x140}=        Set Variable  0x77

    Execute Command            sysbus SetAddressRangeLocked <0x100, 0x1FF> true sysbus.mockCpu0
    Should Block Write Byte    0x100  ${new_value_0x100}  sysbus.mockCpu0
    Should Write Byte          0x100  ${new_value_0x100}
    Should Block Write Byte    0x140  ${new_value_0x100}  sysbus.mockCpu0
    Should Block Write Byte    0x180  ${new_value_0x100}  sysbus.mockCpu0

    Execute Command            sysbus SetAddressRangeLocked <0x100, 0x1FF> true sysbus.mockCpu1
    Execute Command            sysbus SetAddressRangeLocked <0x140, 0x140> false sysbus.mockCpu0
    Should Block Write Byte    0x100  ${new_value_0x140}  sysbus.mockCpu0
    Should Write Byte          0x140  ${new_value_0x140}  sysbus.mockCpu0
    Should Block Write Byte    0x180  ${new_value_0x140}  sysbus.mockCpu1

    Execute Command            sysbus SetAddressRangeLocked <0x100, 0x1FF> false sysbus.mockCpu0
    Should Read Byte           0x100  ${new_value_0x100}
    Should Read Byte           0x140  ${new_value_0x140}
    Should Read Byte           0x180  ${init_value_0x180}

Test Writing To A Locked Sysbus Range Registered Per CPU
    Requires                   sysbus-with-mock-cpus

    Execute Command            machine LoadPlatformDescriptionFromString ${per-core-memory}

    ${new_value_0x200}=        Set Variable  0x99

    Execute Command            sysbus SetAddressRangeLocked <0x200, 0x2FF> true sysbus.mockCpu0
    Should Block Write Byte    0x200  ${new_value_0x200}  sysbus.mockCpu0

    # For these, the range doesn't exist, as it's local to CPU0 only
    Should Write Byte To Non Existing Peripheral    0x200  ${new_value_0x200}  sysbus.mockCpu1
    Should Write Byte To Non Existing Peripheral    0x200  ${new_value_0x200}

    Execute Command            sysbus SetAddressRangeLocked <0x200, 0x2FF> false sysbus.mockCpu0

    # Now the lock is global, but the peripheral is still locally-mapped.
    # Since locking has precedence over non-existent access, CPUs won't trip on non-existing access
    # and all writes will fail (lock is on "any" context)
    Execute Command            sysbus SetAddressRangeLocked <0x200, 0x2FF> true

    Should Block Write Byte    0x200  ${new_value_0x200}
    Should Block Write Byte    0x200  ${new_value_0x200}  sysbus.mockCpu1
    Should Block Write Byte    0x200  ${new_value_0x200}  sysbus.mockCpu0

    # The other range should still not be writable by its core
    Should Block Write Byte    0x250  ${new_value_0x200}  sysbus.mockCpu1

    # Unlock the global range
    Execute Command            sysbus SetAddressRangeLocked <0x200, 0x2FF> false
    # Re-lock it but with CPU1 only and repeat the previous steps
    Execute Command            sysbus SetAddressRangeLocked <0x200, 0x2FF> true sysbus.mockCpu1

    # CPU0 is unaffected by the lock, as is the access without context
    Should Write Byte          0x200  ${new_value_0x200}
    Should Block Write Byte    0x200  ${new_value_0x200}  sysbus.mockCpu1
    Should Write Byte          0x200  ${new_value_0x200}  sysbus.mockCpu0

    # The other range should still not be writable by its core
    Should Block Write Byte    0x250  ${new_value_0x200}  sysbus.mockCpu1

    Execute Command            sysbus SetAddressRangeLocked <0x200, 0x2FF> false sysbus.mockCpu1
    # Now, unlock the first range, and lock the second range
    # Cpu1 should fail on accessing the range
    Execute Command            sysbus SetAddressRangeLocked <0x250, 0x7FF> true sysbus.mockCpu1
    Should Block Write Byte    0x250  ${new_value_0x200}  sysbus.mockCpu1

Test Registering Mapped Memory In Locked Range
    # We want to test IMapped memory here, so we need CPU's presence for a full test
    # relocking is trivial for anything that isn't directly mapped to CPU (unmanaged memory)
    Requires                   sysbus-with-mock-cpus
    ${value}=                  Set Variable  0x66

    Execute Command            sysbus SetAddressRangeLocked <0x4000, 0x4FFF> true

    Execute Command            machine LoadPlatformDescriptionFromString "memory_locked: Memory.MappedMemory @ sysbus 0x4000 { size: 0x1000 }"
    Execute Command            machine LoadPlatformDescriptionFromString "memory_unlocked: Memory.MappedMemory @ sysbus 0x5000 { size: 0x1000 }"

    Should Write Byte          0x5000  ${value}
    Should Block Write Byte    0x4000  ${value}

    Execute Command            sysbus.mockCpu0 PC 0x4000
    Execute Command            sysbus.mockCpu1 PC 0x5000

    Start Emulation

    # Now, to really test if newly registered memory has been locked correctly, try executing code (instructions don't matter here)
    # Cpu0 should abort immediately, and Cpu1 should fall out of memory range
    Wait For Log Entry         mockCpu0: CPU abort \[PC=0x4000\]: Trying to execute code from disabled or locked memory at 0x00004000  timeout=10
    Wait For Log Entry         mockCpu1: CPU abort \[PC=0x6000\]: Trying to execute code outside RAM or ROM at 0x00006000  timeout=10

Symbols Should Be Dynamically Loaded and Unloaded On Request
    ${bin}=                        Set Variable  @https://dl.antmicro.com/projects/renode/stm32l07--zephyr-shell_module.elf-s_1195760-e9474da710aca88c89c7bddd362f7adb4b0c4b70
    ${cpu}=                        Set Variable  sysbus.cpu
    ${main_symbol_name}=           Set Variable  "main"
    ${main_symbol_address}=        Set Variable  0x0000000008007644

    Execute Command                include @platforms/cpus/stm32l072.repl

    # LoadELF without cpu context argument loads symbols in the global scope
    Execute Command                sysbus LoadELF ${bin}
    ${main_address_global}=        Execute Command  sysbus GetSymbolAddress ${main_symbol_name}
    Should Be Equal As Numbers     ${main_symbol_address}  ${main_address_global}
    
    # Symbol lookup fallbacks to the global scope if the per-cpu lookup is not found
    ${main_address_local}=         Execute Command  sysbus GetSymbolAddress ${main_symbol_name} context=${cpu}
    Should Be Equal As Numbers     ${main_symbol_address}  ${main_address_local}

    # Global lookup is not cleared when the per-cpu lookup is cleared, so local lookup fallbacks to the global scope
    Execute Command                sysbus ClearSymbols context=${cpu}
    ${main_address_local}=         Execute Command  sysbus GetSymbolAddress ${main_symbol_name} context=${cpu}
    Should Be Equal As Numbers     ${main_symbol_address}  ${main_address_local}

    Execute Command                sysbus ClearSymbols
    # Global lookup is cleared so both local and global lookup fail
    Run Keyword And Expect Error   *No symbol with name `main` found*
    ...                            Execute Command   sysbus GetSymbolAddress ${main_symbol_name} context=${cpu}
    Run Keyword And Expect Error   *No symbol with name `main` found*
    ...                            Execute Command   sysbus GetSymbolAddress ${main_symbol_name}
    
    # Load symbols in the local scope so they are visible only for the given cpu
    Execute Command                sysbus LoadSymbolsFrom ${bin} context=${cpu}
    ${main_address_local}=         Execute Command  sysbus GetSymbolAddress ${main_symbol_name} context=${cpu}
    Should Be Equal As Numbers     ${main_symbol_address}  ${main_address_local}
    Run Keyword And Expect Error   *No symbol with name `main` found*
    ...                            Execute Command   sysbus GetSymbolAddress ${main_symbol_name}
    