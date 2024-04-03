*** Variables ***
# The values and addresses are totally arbitrary.
${init_value_0x40}             0x11
${init_value_0x80}             0x22
${init_value_0x100}            0x33
${init_value_0x140}            0x44
${init_value_0x180}            0x55

*** Keywords ***
Read From Sysbus And Check If Blocked
    [Arguments]  ${address}  ${expected_value}=0x0  ${should_be_blocked}=True  ${access_type}=Byte  ${access_size}=1

    ${blocked_read_log}=           Set Variable    Tried to read ${access_size} bytes at ${address} which is inside a locked address range, returning 0

    ${read_value}=                 Execute Command    sysbus Read${access_type} ${address}
    IF    ${should_be_blocked}
        Wait For Log Entry         ${blocked_read_log}
    ELSE
        Should Not Be In Log       ${blocked_read_log}
    END
    Should Be Equal As Integers    ${read_value}  ${expected_value}  base=16

Should Block Read Byte
    [Arguments]  ${address}
    Read From Sysbus And Check If Blocked    ${address}

Should Block Read Quad
    [Arguments]  ${address}
    Read From Sysbus And Check If Blocked    ${address}  access_type=QuadWord  access_size=8

Should Read Byte
    [Arguments]  ${address}  ${expected_value}
    Read From Sysbus And Check If Blocked    ${address}  ${expected_value}  should_be_blocked=False

Should Read Quad
    [Arguments]  ${address}  ${expected_value}
    Read From Sysbus And Check If Blocked    ${address}  ${expected_value}  should_be_blocked=False  access_type=QuadWord  access_size=8

Write To Sysbus And Check If Blocked
    [Arguments]  ${address}  ${value}  ${should_be_blocked}=True  ${access_type}=Byte  ${access_size}=1

    Execute Command             sysbus Write${access_type} ${address} ${value}
    ${blocked_write_log}=       Set Variable  Tried to write ${access_size} bytes (${value}) at ${address} which is inside a locked address range, write ignored
    IF    ${should_be_blocked}
        Wait For Log Entry      ${blocked_write_log}
    ELSE
        Should Not Be In Log    ${blocked_write_log}
    END

Should Block Write Byte
    [Arguments]  ${address}  ${value}
    Write To Sysbus And Check If Blocked    ${address}  ${value}

Should Block Write Quad
    [Arguments]  ${address}  ${value}
    Write To Sysbus And Check If Blocked    ${address}  ${value}  access_type=QuadWord  access_size=8

Should Write Byte
    [Arguments]  ${address}  ${value}
    Write To Sysbus And Check If Blocked    ${address}  ${value}  should_be_blocked=False

Should Write Quad
    [Arguments]  ${address}  ${value}
    Write To Sysbus And Check If Blocked    ${address}  ${value}  should_be_blocked=False  access_type=QuadWord  access_size=8

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
