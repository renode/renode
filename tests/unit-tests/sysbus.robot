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

${max_32bit_addr}              0xFFFFFFFF

${platform_no_region_specified}   SEPARATOR=${\n}
...                               """
...                               mock: Mocks.MockDoubleWordPeripheralWithOnlyRegionReadMethod @ {
...                               ${SPACE*4}sysbus new Bus.BusMultiRegistration { address: 0x100; size: 0x100; region: "nonexisting" }
...                               }
...                               """

${platform_only_region_read}   SEPARATOR=${\n}
...                            """
...                            mock: Mocks.MockDoubleWordPeripheralWithOnlyRegionReadMethod @ {
...                            ${SPACE*4}sysbus new Bus.BusMultiRegistration { address: 0x100; size: 0x100; region: "region" }
...                            }
...                            """

*** Keywords ***
Create Machine With CPU And Two MappedMemory Peripherals
    Execute Command            using sysbus
    Execute Command            mach create

    # ARMv7A is used only because it can be created without any additional peripherals.
    # Locking can be used with all CPUs.
    Execute Command            machine LoadPlatformDescriptionFromString "cpu: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\"}"
    Execute Command            machine LoadPlatformDescriptionFromString "mem1: Memory.MappedMemory @ sysbus 0x10000 { size: 0x10000 }"
    Execute Command            machine LoadPlatformDescriptionFromString "mem2: Memory.MappedMemory @ sysbus 0x80000 { size: 0x10000 }"

Get ${peripheral} Size, Address And Range
    ${size}=    Execute Command  ${peripheral} Size
    ${size}=    Strip String     ${size}
    ${ranges}=  Execute Command  sysbus GetRegistrationPoints ${peripheral}

    # Let's make sure there's only one range.
    ${count}=  Evaluate          """${ranges}""".count('<')
    Should Be Equal As Integers  1  ${count}

    ${range}  ${address}=  Evaluate
    ...    [ re.search('<(0x[0-9A-F]*), .*>', """${ranges}""").group(i) for i in range(2) ]
    ...    modules=re

    RETURN  ${size}  ${address}  ${range}

${lock_or_unlock:(Lock|Unlock)} Address Range From ${start} To ${end}
    ${range}=     Evaluate   f"<{ hex(${start}) }, { hex(${end}) }>"
    ${lock_or_unlock} Address Range ${range}

${lock_or_unlock:(Lock|Unlock)} Address Range ${range}
    ${set_lock}=  Evaluate   '${lock_or_unlock}' == 'Lock'
    Execute Command          sysbus SetAddressRangeLocked ${range} ${set_lock}

Range From ${start} To ${end} Should Be Accessible
    ${range}=       Evaluate         f"<{ hex(${start}) }, { hex(${end}) }>"
    ${locked_str}=  Execute Command  sysbus IsAddressRangeLocked ${range}
    Should Start With                ${locked_str}  False

No Blocked Access Should Be In Log
    Should Not Be In Log     Tried to (read|write) .* which is inside a locked address range  treatAsRegex=True

Blocked ${access_size}B Read From ${address} Should Be In Log
    ${eval_addr}=  Evaluate  '0x' + hex(${address}).upper()[2:]
    Wait For Log Entry       Tried to read ${access_size} bytes at ${eval_addr} which is inside a locked address range, returning 0

Read From Sysbus And Check If Blocked
    [Arguments]  ${address}  ${expected_value}=0x0  ${should_be_blocked}=True  ${access_type}=Byte  ${access_size}=1  ${cpu_context}=

    ${read_value}=  Execute Command  sysbus Read${access_type} ${address} ${cpu_context}
    IF    ${should_be_blocked}
        Blocked ${access_size}B Read From ${address} Should Be In Log
    ELSE
        No Blocked Access Should Be In Log
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

Blocked ${access_size}B Write${access_type} Of ${value} To ${address} Should Be In Log
    ${eval_addr}=  Evaluate  '0x' + hex(${address}).upper()[2:]
    Wait For Log Entry       Tried to write ${access_size} bytes (${value}) at ${eval_addr} which is inside a locked address range, write ignored

Write To Sysbus And Check If Blocked
    [Arguments]  ${address}  ${value}  ${should_be_blocked}=True  ${access_type}=Byte  ${access_size}=1  ${cpu_context}=

    Execute Command  sysbus Write${access_type} ${address} ${value} ${cpu_context}
    IF    ${should_be_blocked}
        Blocked ${access_size}B Write Of ${value} To ${address} Should Be In Log
    ELSE
        No Blocked Access Should Be In Log
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

    # SerialExecution is necessary only because the logs might appear in any order when being run concurrently on two CPUs
    # and this will cause the tests to timeout
    Execute Command            machine SetSerialExecution True

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
    # Waiting for abort logs is tricky and might hang the test if something goes wrong cause
    # virtual timeouts don't really work with aborts; 20 seconds should be more than enough.
    [Timeout]                  20 seconds

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

    # Now, to really test if newly registered memory has been locked correctly, try executing code (instructions don't matter here)
    # Cpu0 should abort immediately, and Cpu1 should fall out of memory range soon after
    # We don't wait for the exact logs in case there's another CPU abort or a different order of aborts in which case we could wait forever.
    ${log}=  Wait For Log Entry    CPU abort  timeout=1
    Should Contain    ${log}       mockCpu0: CPU abort \[PC=0x4000\]: Trying to execute code from disabled or locked memory at 0x00004000

    ${log}=  Wait For Log Entry    CPU abort  timeout=1
    Should Contain    ${log}       mockCpu1: CPU abort \[PC=0x6000\]: Trying to execute code outside RAM or ROM at 0x00006000

Locked MappedMemory Should Not Be Accessible From CPU
    Create Machine With CPU And Two MappedMemory Peripherals
    ${flash}=  Set Variable    mem1
    ${ram}=    Set Variable    mem2

    ${flash_size}  ${flash_addr}  ${flash_range}=  Get ${flash} Size, Address And Range
    ${ram_size}    ${ram_addr}    ${ram_range}=    Get ${ram} Size, Address And Range

    Execute Command            cpu ExecutionMode SingleStep
    Execute Command            cpu PC ${ram_addr}
    Create Log Tester          0

    # With flash locked, the loads from [r3] and stores to [r3] should be blocked.
    ${result_addr}=  Evaluate  hex(${flash_addr} + 0x1000)
    Execute Command            cpu SetRegister 3 ${result_addr}

    Execute Command            ${ram} WriteDoubleWord 0x00 0xe59f2028  # ldr   r2, [pc, #40] // =0x11111111
    Execute Command            ${ram} WriteDoubleWord 0x04 0xe5832000  # str   r2, [r3]
    Execute Command            ${ram} WriteDoubleWord 0x30 0x11111111  # this will be loaded by LDR instruction above

    # Ranges have to fully contain all MappedMemory peripherals registered in the given range.
    # Here we lock whole sysbus and then unlock ram.
    Lock Address Range From 0x0 To ${max_32bit_addr}
    Unlock Address Range ${ram_range}
    Execute Command            cpu Step 2

    Blocked 4B Write Of 0x11111111 To ${result_addr} Should Be In Log

    Execute Command            ${ram} WriteDoubleWord 0x08 0xe59f2024  # ldr   r2, [pc, #34] // =0x22222222
    Execute Command            ${ram} WriteDoubleWord 0x0c 0xe5832000  # str   r2, [r3]
    Execute Command            ${ram} WriteDoubleWord 0x10 0xe3032333  # movw  r2, #0x3333
    Execute Command            ${ram} WriteDoubleWord 0x14 0xe1c320b1  # strh  r2, [r3, #1]
    Execute Command            ${ram} WriteDoubleWord 0x34 0x22222222  # this will be loaded by LDR instruction above

    Unlock Address Range ${flash_range}
    Execute Command            cpu Step 4

    No Blocked Access Should Be In Log

    Execute Command            ${ram} WriteDoubleWord 0x18 0xe3a02044  # mov   r2, #0x44
    Execute Command            ${ram} WriteDoubleWord 0x1c 0xe5c32001  # strb  r2, [r3, #1]
    Execute Command            ${ram} WriteDoubleWord 0x20 0xe5932000  # ldr   r2, [r3]

    # Lock flash and some memory around it.
    Lock Address Range From ${flash_addr}-${flash_size} To ${flash_addr}+${flash_size}*2
    Execute Command            cpu Step 3

    Blocked 1B Write Of 0x44 To ${result_addr}+1 Should Be In Log
    Blocked 4B Read From ${result_addr} Should Be In Log

    Execute Command            ${ram} WriteDoubleWord 0x24 0xe3a02055  # mov   r2, #0x55
    Execute Command            ${ram} WriteDoubleWord 0x28 0xe5c32002  # strb  r2, [r3, #2]
    Execute Command            ${ram} WriteDoubleWord 0x2c 0xe5932000  # ldr   r2, [r3]

    Unlock Address Range From 0x0 To ${max_32bit_addr}
    Execute Command            cpu Step 3

    No Blocked Access Should Be In Log

    ${res}=  Execute Command   sysbus ReadDoubleWord ${result_addr}
    Should Be True             """${res}""".strip() == '0x22553322'

Partial MappedMemory Locking Should Not Be Allowed With ICPUWithMappedMemory
    # CPU is important; partial MappedMemory locking isn't allowed only with ICPUWithMappedMemory.
    Create Machine With CPU And Two MappedMemory Peripherals
    Create Log Tester             0

    ${mem1_size}  ${mem1_addr}  ${mem1_range}=  Get mem1 Size, Address And Range
    ${mem2_size}  ${mem2_addr}  ${mem2_range}=  Get mem2 Size, Address And Range
    ${mem2_end}=  Evaluate        hex(${mem2_addr} + ${mem2_size} - 1)

    ${error}=     Set Variable    Mapped peripherals registered at the given range * have to be fully included:
    ${mem1_reg}=  Set Variable    \n\* machine-0.mem1 registered at ${mem1_range}
    ${mem2_reg}=  Set Variable    \n\* machine-0.mem2 registered at ${mem2_range}

    # Test partial locking of one or both MappedMemory peripherals.

    Run Keyword And Expect Error  *${error}${mem1_reg}*
    ...  Lock Address Range From 0x0 To ${mem1_addr}+0x10

    Run Keyword And Expect Error  *${error}${mem1_reg}*
    ...  Lock Address Range From ${mem1_addr}+0x10 To ${max_32bit_addr}

    Run Keyword And Expect Error  *${error}${mem2_reg}*
    ...  Lock Address Range From 0x0 To ${mem2_addr}+0x10

    Run Keyword And Expect Error  *${error}${mem1_reg}${mem2_reg}*
    ...  Lock Address Range From ${mem1_addr}+0x10 To ${mem2_addr}+0x10

    # Make sure no range within 32-bit address space has been locked.
    Range From 0x0 To ${max_32bit_addr} Should Be Accessible

    # Lock mem1, mem2 and the address space in between.
    Execute Command               sysbus SetAddressRangeLocked <${mem1_addr}, ${mem2_end}> true

    # Test partial unlocking of one or both MappedMemory peripherals.

    Run Keyword And Expect Error  *${error}${mem1_reg}*
    ...  Unlock Address Range From 0x0 To ${mem1_addr}+0x10

    Run Keyword And Expect Error  *${error}${mem1_reg}*
    ...  Unlock Address Range From ${mem1_addr}+0x10 To ${max_32bit_addr}

    Run Keyword And Expect Error  *${error}${mem2_reg}*
    ...  Unlock Address Range From ${mem2_addr}+0x10 To ${max_32bit_addr}

    Run Keyword And Expect Error  *${error}${mem1_reg}${mem2_reg}*
    ...  Unlock Address Range From ${mem1_addr}+0x10 To ${mem2_addr}+0x10

    # Make sure mem1, mem2 and the address space in between are still locked. Range
    # is considered locked if the given range contains any locked range which is why
    # `IsAddressRangeLocked` isn't used. Let's check accessing a byte every 0x8000.
    @{locked_range_addresses}=  Evaluate
    ...    [address for address in range(${mem1_addr}, ${mem2_end}, 0x8000)]
    FOR  ${address}  IN  ${mem1_addr}  @{locked_range_addresses}
        Log    ${address}
        Should Block Read Byte    ${address}
    END

    # Unlock mem1, mem2 and the address space in between and verify there are no locks now.
    Unlock Address Range <${mem1_addr}, ${mem2_end}>
    Range From ${mem1_addr} To ${mem2_end} Should Be Accessible

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
    Run Keyword And Expect Error   *Could not find any address for symbol: main*
    ...                            Execute Command   sysbus GetSymbolAddress ${main_symbol_name} context=${cpu}
    Run Keyword And Expect Error   *Could not find any address for symbol: main*
    ...                            Execute Command   sysbus GetSymbolAddress ${main_symbol_name}

    # Load symbols in the local scope so they are visible only for the given cpu
    Execute Command                sysbus LoadSymbolsFrom ${bin} context=${cpu}
    ${main_address_local}=         Execute Command  sysbus GetSymbolAddress ${main_symbol_name} context=${cpu}
    Should Be Equal As Numbers     ${main_symbol_address}  ${main_address_local}
    Run Keyword And Expect Error   *Could not find any address for symbol: main*
    ...                            Execute Command   sysbus GetSymbolAddress ${main_symbol_name}

Should Log All Peripherals Accesses Only When Enabled
    ${log}=                        Set Variable   peripheral: ReadByte from 0x0 (unknown), returned 0x0
    Create Log Tester              0
    Execute Command                mach create
    Execute Command                machine LoadPlatformDescriptionFromString "peripheral: Mocks.MockBytePeripheralWithoutTranslations @ sysbus <0x0, +0x8>"

    Execute Command                sysbus LogAllPeripheralsAccess True
    Execute Command                sysbus ReadByte 0x0
    Wait For Log Entry             ${log}

    Execute Command                sysbus LogAllPeripheralsAccess False
    Execute Command                sysbus ReadByte 0x0
    Should Not Be In Log           ${log}

Should Not Register Platform When Nonexisting Region Is Specified
    Execute Command                mach create
    Run Keyword And Expect Error   *No region "nonexisting" is available for Antmicro.Renode.Peripherals.Mocks.MockDoubleWordPeripheralWithOnlyRegionReadMethod*
    ...                            Execute Command   machine LoadPlatformDescriptionFromString ${platform_no_region_specified}

Should Not Register Region When Only Read Method Is Implemented
    Execute Command                mach create
    Run Keyword And Expect Error   *WriteDoubleWord is not specified for region*
    ...                            Execute Command   machine LoadPlatformDescriptionFromString ${platform_only_region_read}

Should Not Dispose Registered Peripheral When Exception Thrown During Registration
    Execute Command                mach create
    Run Keyword And Expect Error   *Could not register*
    ...                            Execute Command  machine LoadPlatformDescription "${CURDIR}${/}registration-disposal.repl"

    Execute Command                allowPrivates true
    ${x}=                          Execute Command  sram1 disposed
    Should Be Equal                ${x}  False  strip_spaces=True

Should Not Leave References To Unregistered CPU When Exception Thrown During Another Peripheral's Registration
    Execute Command                mach create
    Run Keyword And Expect Error   *Could not register*
    ...                            Execute Command  machine LoadPlatformDescription "${CURDIR}${/}registration-disposal.repl"

    # see if there are any stale references to cpu0 by attempting to save, which will cause a crash if there are
    ${x}=                          Allocate Temporary File
    Execute Command                Save @${x}

Should Not Leave References To Unregistered CPU When Exception Thrown During Its Registration
    Execute Command                mach create
    Run Keyword And Expect Error   *Could not register*
    ...                            Execute Command  machine LoadPlatformDescription "${CURDIR}${/}registration-disposal-cpuexn.repl"

    # will cause a crash if there are stale references
    Execute Command                Clear

Should Not Leave References To A Peripheral That Obtained The System Bus In Its Constructor If This Peripheral Fails Registration
    Execute Command                mach create
    Run Keyword And Expect Error   *Cannot register peripheral*
    ...                            Execute Command  machine LoadPlatformDescription "${CURDIR}${/}registration-disposal-noregister.repl"

    ${x}=                          Allocate Temporary File
    Execute Command                Save @${x}
