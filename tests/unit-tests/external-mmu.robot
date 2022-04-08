*** Settings ***
Suite Setup                         Setup
Suite Teardown                      Teardown
Test Setup                          Reset Emulation
Test Teardown                       Test Teardown
Resource                            ${RENODEKEYWORDS}

*** Variables ***
${a0}                               0xa
${a1}                               0xb
${a2}                               0xc
${PRIV_ALL}                         7
${PRIV_WRITE_ONLY}                  2
${PRIV_EXEC_ONLY}                   4
${PRIV_NONE}                        0
${START_PC}                         0x0

*** Keywords ***
Create Platform
    Execute Command                 using sysbus
    Execute Command                 mach create "risc-v"

    Execute Command                 machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { timeProvider: clint; cpuType: \\"rv32gc\\" }"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x100000 }"

    Execute Command                 cpu PC ${START_PC}

Expect Value Read From Address
    [Arguments]                     ${address}  ${value}
    Execute Command                 cpu PC ${START_PC}
    Execute Command                 cpu SetRegisterUnsafe ${a0} ${address}
    Execute Command                 sysbus WriteDoubleWord ${START_PC} 0x52583  # lw a1, 0(a0)

    Execute Command                 cpu ExecutionMode SingleStepBlocking
    Execute Command                 start
    Execute Command                 cpu Step

    ${val}=                         Execute Command   cpu GetRegisterUnsafe ${a1}
    Should Be Equal As Integers     ${val}  ${value}

Write Range With Doublewords
    [Arguments]                     ${start_addr}  ${length}  ${value}
    ${end_addr}=                    Evaluate  ${start_addr}+${length}
    ${bytesPerDoubleword}=          Evaluate  4
    FOR   ${addr}  IN RANGE         ${start_addr}  ${end_addr}  ${bytesPerDoubleWord}
        Execute Command             sysbus WriteDoubleWord ${addr} ${value}
    END

Define Window Using CPU API
    [Arguments]                     ${start_addr}  ${end_addr}  ${addend}  ${priv}
    Execute Command                 cpu EnableExternalWindowMmu true
    ${window_index}=                Execute Command  cpu AcquireExternalMmuWindow
    Execute Command                 cpu SetMmuWindowStart ${window_index} ${start_addr}
    Execute Command                 cpu SetMmuWindowEnd ${window_index} ${end_addr}
    Execute Command                 cpu SetMmuWindowAddend ${window_index} ${addend}
    Execute Command                 cpu SetMmuWindowPrivileges ${window_index} ${priv}
    Return From Keyword             ${window_index}

*** Test Cases ***
Setting MMU Window Parameters Before Enabling Throws
    Create Platform
    Run Keyword And Expect Error    KeywordException: *There was an error executing command 'cpu SetMmuWindowAddend 0 256'External MMU not enabled*
    ...  Execute Command                 cpu SetMmuWindowAddend 0 0x100

Using Too High MMU Window Index Throws
    Create Platform
    Execute Command                 cpu EnableExternalWindowMmu true
    Run Keyword And Expect Error    KeywordException: *There was an error executing command 'cpu SetMmuWindowAddend 256 256'Window index to high, maximum number: 255, got 256*
    ...  Execute Command            cpu SetMmuWindowAddend 256 0x100

Read/Write From Address Outside The Defined MMU Windows Works Properly
    Create Platform
    Execute Command                 cpu EnableExternalWindowMmu true
    Execute Command                 sysbus WriteWord 0x2000 0x1234
    Expect Value Read From Address  0x2000  0x1234

Is Able To Retrive The Properties
    Create Platform

    ${window}=                      Define Basic Window At          0x1000  0x2000  0x100  ${PRIV_ALL}
    ${range_start}=                 Execute Command    cpu GetMmuWindowStart ${window}
    ${range_end}=                   Execute Command    cpu GetMmuWindowEnd ${window}
    ${addend}=                      Execute Command    cpu GetMmuWindowAddend ${window}
    ${priv}=                        Execute Command    cpu GetMmuWindowPrivileges ${window}
    Should Be Equal As Integers     0x1000  ${range_start}
    Should Be Equal As Integers     0x2000  ${range_end}
    Should Be Equal As Integers     0x100   ${addend}
    Should Be Equal As Integers     ${PRIV_ALL}  ${priv}

Can Reset The Windows
    Create Platform

    ${window1}=                     Define Basic Window At          0x1000  0x2000  0x100  ${PRIV_ALL}
    ${window2}=                     Define Basic Window At          0x2000  0x3000  0x100  ${PRIV_ALL}
    ${window3}=                     Define Basic Window At          0x3000  0x4000  0x100  ${PRIV_ALL}
    Execute Command                 cpu ResetMmuWindow ${window2}

    # Removed window
    ${range_start}=                 Execute Command    cpu GetMmuWindowStart ${window2}
    ${range_end}=                   Execute Command    cpu GetMmuWindowEnd ${window2}
    ${addend}=                      Execute Command    cpu GetMmuWindowAddend ${window2}
    ${priv}=                        Execute Command    cpu GetMmuWindowPrivileges ${window2}
    Should Be Equal As Integers     0  ${range_start}
    Should Be Equal As Integers     0  ${range_end}
    Should Be Equal As Integers     0  ${addend}
    Should Be Equal As Integers     0  ${priv}

    # Surrounding windows should remain untouched
    ${range_start}=                 Execute Command    cpu GetMmuWindowStart ${window1}
    ${range_end}=                   Execute Command    cpu GetMmuWindowEnd ${window1}
    ${addend}=                      Execute Command    cpu GetMmuWindowAddend ${window1}
    ${priv}=                        Execute Command    cpu GetMmuWindowPrivileges ${window1}
    Should Be Equal As Integers     0x1000  ${range_start}
    Should Be Equal As Integers     0x2000  ${range_end}
    Should Be Equal As Integers     0x100  ${addend}
    Should Be Equal As Integers     ${PRIV_ALL}  ${priv}

    ${range_start}=                 Execute Command    cpu GetMmuWindowStart ${window3}
    ${range_end}=                   Execute Command    cpu GetMmuWindowEnd ${window3}
    ${addend}=                      Execute Command    cpu GetMmuWindowAddend ${window3}
    ${priv}=                        Execute Command    cpu GetMmuWindowPrivileges ${window3}
    Should Be Equal As Integers     0x3000  ${range_start}
    Should Be Equal As Integers     0x4000  ${range_end}
    Should Be Equal As Integers     0x100  ${addend}
    Should Be Equal As Integers     ${PRIV_ALL}  ${priv}

Read/Write Uses The Proper Addend
    Create Platform
    Define Window Using CPU API     0x0000  0x1000  0x0  ${PRIV_ALL}
    Define Window Using CPU API     0x10000  0x11000  0x1000  ${PRIV_ALL}
    Execute Command                 sysbus WriteWord 0x10000 0xFFFF
    Execute Command                 sysbus WriteWord 0x11000 0x0124
    Expect Value Read From Address  0x10000  0x0124

Throws On Ranges Unaligned To The Page Size
    Create Platform
    Run Keyword And Expect Error    CpuAbortException: MMU ranges must be aligned to the page size (0x1000), the address 0x100 is not*
    ...  Define Window Using CPU API     0x100  0x1100  0x1000  ${PRIV_ALL}

Permissions Are Respected
    Create Platform
    Create Log Tester               0
    Execute Command                 logLevel -1 cpu
    Define Window Using CPU API     0x0000  0x1000  0x0  ${PRIV_ALL}
    Define Window Using CPU API     0x1000  0x2000  0x100  ${PRIV_EXEC_ONLY}
    Write Range With Doublewords    0x1000  0x1FF  0xFFFFFFFF
    Expect Value Read From Address  0x1100  0x0
    Wait For Log Entry              External MMU fault at 0x1100

Fault Callback Works Only When Enabled
    Create Platform
    Create Log Tester               0.0001
    Execute Command                 logLevel -1 cpu
    Expect Value Read From Address  0x1100  0x0
    Should Not Be In Log            External MMU fault at 0x1100
