*** Variables ***
${a0}                               0xa
${a1}                               0xb
${a2}                               0xc
${PRIV_ALL}                         7
${PRIV_READWRITE}                   3
${PRIV_WRITE_ONLY}                  2
${PRIV_EXEC_ONLY}                   4
${PRIV_NONE}                        0
${START_PC}                         0x0
${-1u64}                            0xFFFFFFFFFFFFFFFF

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
    Execute Command                 cpu SetRegister ${a0} ${address}
    Execute Command                 sysbus WriteDoubleWord ${START_PC} 0x52583  # lw a1, 0(a0)

    Execute Command                 cpu Step

    ${val}=                         Execute Command   cpu GetRegister ${a1}
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
    ${window_index}=                Execute Command  cpu AcquireExternalMmuWindow ${PRIV_ALL}
    Execute Command                 cpu SetMmuWindowStart ${window_index} ${start_addr}
    Execute Command                 cpu SetMmuWindowEnd ${window_index} ${end_addr}
    Execute Command                 cpu SetMmuWindowAddend ${window_index} ${addend}
    Execute Command                 cpu SetMmuWindowPrivileges ${window_index} ${priv}
    Return From Keyword             ${window_index}

Define Typed Window Using CPU API
    [Arguments]                     ${start_addr}  ${end_addr}  ${addend}  ${priv}  ${type}
    Execute Command                 cpu EnableExternalWindowMmu true
    ${window_index}=                Execute Command  cpu AcquireExternalMmuWindow ${type}
    Execute Command                 cpu SetMmuWindowStart ${window_index} ${start_addr}
    Execute Command                 cpu SetMmuWindowEnd ${window_index} ${end_addr}
    Execute Command                 cpu SetMmuWindowAddend ${window_index} ${addend}
    Execute Command                 cpu SetMmuWindowPrivileges ${window_index} ${priv}
    Return From Keyword             ${window_index}

Define Window In Peripheral
    [Arguments]                     ${periph}  ${window_index}  ${start_addr}  ${end_addr}  ${addend}  ${priv}
    ${offset}=                      Evaluate  4 * ${window_index}
    ${start_register}=              Evaluate  0x0 + ${offset}
    ${end_register}=                Evaluate  0x400 + ${offset}
    ${addend_register}=             Evaluate  0x800 + ${offset}
    ${priv_register}=               Evaluate  0xC00 + ${offset}
    Execute Command                 ${periph} WriteDoubleWord ${start_register} ${start_addr}
    Execute Command                 ${periph} WriteDoubleWord ${end_register} ${end_addr}
    Execute Command                 ${periph} WriteDoubleWord ${addend_register} ${addend}
    Execute Command                 ${periph} WriteDoubleWord ${priv_register} ${priv}

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

Read/Write From Address Outside The Defined MMU Windows Throws
    Create Platform
    Execute Command                 cpu EnableExternalWindowMmu true
    Create Log Tester               0
    Execute Command                 sysbus WriteWord 0x2000 0x1234
    Expect Value Read From Address  0x10000  0x0
    Wait For Log Entry              MMU fault - the address 0x0 is not specified in any of the existing ranges

Window Can Handle Only One Type Of Access
    Create Platform
    Execute Command                 cpu EnableExternalWindowMmu true
    Create Log Tester               0
    Define Typed Window Using CPU API    0x0000  0x1000  0x0  ${PRIV_EXEC_ONLY}  ${PRIV_EXEC_ONLY}
    Define Typed Window Using CPU API    0x0000  0x1000  0x1000  ${PRIV_READWRITE}  ${PRIV_READWRITE}
    Execute Command                 sysbus WriteWord 0x1000 0x0124
    Expect Value Read From Address  0x0  0x0124

Is Able To Retrive The Properties
    Create Platform

    ${window}=                      Define Window Using CPU API  0x1000  0x2000  0x100  ${PRIV_ALL}
    ${range_start}=                 Execute Command   cpu GetMmuWindowStart ${window}
    ${range_end}=                   Execute Command   cpu GetMmuWindowEnd ${window}
    ${addend}=                      Execute Command   cpu GetMmuWindowAddend ${window}
    ${priv}=                        Execute Command   cpu GetMmuWindowPrivileges ${window}
    Should Be Equal As Integers     0x1000  ${range_start}
    Should Be Equal As Integers     0x2000  ${range_end}
    Should Be Equal As Integers     0x100   ${addend}
    Should Be Equal As Integers     ${PRIV_ALL}  ${priv}

Can Reset The Windows
    Create Platform

    ${window1}=                     Define Window Using CPU API     0x1000  0x2000  0x100  ${PRIV_ALL}
    ${window2}=                     Define Window Using CPU API     0x2000  0x3000  0x100  ${PRIV_ALL}
    ${window3}=                     Define Window Using CPU API     0x3000  0x4000  0x100  ${PRIV_ALL}
    Execute Command                 cpu ResetMmuWindow ${window2}

    # Removed window
    ${range_start}=                 Execute Command    cpu GetMmuWindowStart ${window2}
    ${range_end}=                   Execute Command    cpu GetMmuWindowEnd ${window2}
    ${addend}=                      Execute Command    cpu GetMmuWindowAddend ${window2}
    ${priv}=                        Execute Command    cpu GetMmuWindowPrivileges ${window2}
    Should Be Equal As Integers     0  ${range_start}  "Range start incorrect"
    Should Be Equal As Integers     0  ${range_end}  "Range end incorrect"
    Should Be Equal As Integers     0  ${addend}  "Range adden incorrect"
    Should Be Equal As Integers     0  ${priv}  "Range privileges incorrect"

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
    Execute Command                 logLevel -1
    Define Window Using CPU API     0x0000  0x1000  0x0  ${PRIV_ALL}
    Define Window Using CPU API     0x1000  0x2000  0x100  ${PRIV_EXEC_ONLY}
    Write Range With Doublewords    0x1000  0x1FF  0xFFFFFFFF
    Expect Value Read From Address  0x1100  0x0
    Wait For Log Entry              External MMU fault at 0x1100

Fault Callback Works Only When Enabled
    Create Platform
    Create Log Tester               0.0001
    Execute Command                 logLevel 0 cpu
    Expect Value Read From Address  0x1100  0x0
    Should Not Be In Log            External MMU fault at 0x1100

Peripheral Can Be Attached To The Sysbus
    Create Platform
    Execute Command                 machine LoadPlatformDescriptionFromString "mmu1: Miscellaneous.ExternalWindowMMU @ sysbus 0x47000000 {cpu: cpu; numberOfWindows: 4}"
    Define Window In Peripheral     mmu1  0  0x0  0x1000  0x0  ${PRIV_EXEC_ONLY}
    Provides                        SingleMMU

Peripheral Can Be Configured Using The Registers Inteface
    Requires                        SingleMMU
    Define Window In Peripheral     mmu1  1  0x10000  0x11000  0x1000  ${PRIV_ALL}
    Execute Command                 sysbus WriteWord 0x10000 0xFFFF
    Execute Command                 sysbus WriteWord 0x11000 0x0124
    Expect Value Read From Address  0x10000  0x0124

CPU Can Have Two MMUs
    Create Platform
    Execute Command                 machine LoadPlatformDescriptionFromString "mmu1: Miscellaneous.ExternalWindowMMU @ sysbus 0x47000000 {cpu: cpu; numberOfWindows: 2}"
    Execute Command                 machine LoadPlatformDescriptionFromString "mmu2: Miscellaneous.ExternalWindowMMU @ sysbus 0x47001000 {cpu: cpu; numberOfWindows: 2}"
    Define Window In Peripheral     mmu1  0  0x0  0x1000  0x0  ${PRIV_EXEC_ONLY}
    Define Window In Peripheral     mmu2  0  0x0  0x1000  0x0  ${PRIV_EXEC_ONLY}
    Provides                        TwoMmus

Peripheral Throws Fault On Illegal Data Access
    Requires                        SingleMMU
    Create Log Tester               0
    Define Window In Peripheral     mmu1  1  0x0000  0x1000  0x0000  ${PRIV_ALL}
    Define Window In Peripheral     mmu1  2  0x1000  0x2000  0x0000  ${PRIV_NONE}
    Execute Command                 logLevel 0 mmu1

    Expect Value Read From Address  0x1100  0x0
    Wait For Log Entry              mmu1: MMU fault occured

Peripheral Does Not Throw When no_page_fault Is Set
    Requires                        SingleMMU
    Create Log Tester               0
    Define Window In Peripheral     mmu1  1  0x0000  0x1000  0x0000  ${PRIV_ALL}
    Define Window In Peripheral     mmu1  2  0x1000  0x2000  0x0000  ${PRIV_NONE}
    Execute Command                 logLevel 0 mmu1

    # cpu TranslateAddress uses the cpu_handle_mmu_fault with no_page_fault set to 1
    Run Keyword And Expect Error
    ...   *Failed to translate address*
    ...   Execute Command  cpu TranslateAddress 0x1100 Read
    Should Not Be In Log            mmu1: MMU fault occured

Peripheal Throws On Illegal Instruction Fetch
    Create Platform
    Create Log Tester               0
    Execute Command                 machine LoadPlatformDescriptionFromString "mmu1: Miscellaneous.ExternalWindowMMU @ sysbus 0x47000000 {cpu: cpu; numberOfWindows: 4}"
    Define Window In Peripheral     mmu1  1  0x0000  0x1000  0x0000  ${PRIV_WRITE_ONLY}
    Execute Command                 logLevel 0 mmu1

    Expect Value Read From Address  0x2000  0x0
    Wait For Log Entry              mmu1: MMU fault occured

First MMU Throws On Fault In Its Window
    Requires                        TwoMmus
    Create Log Tester               0

    Execute Command                 logLevel 0 mmu1
    Execute Command                 logLevel 0 mmu2

    Define Window In Peripheral     mmu1  1  0x1000  0x2000  0x0000  ${PRIV_NONE}
    Execute Command                 sysbus WriteWord 0x1000 0x0124
    Expect Value Read From Address  0x1000  0x0

    Wait For Log Entry              mmu1: MMU fault occured
    Should Not Be In Log            mmu2: MMU fault occured

Second MMU Throws On Fault In Its Window
    Requires                        TwoMmus
    Create Log Tester               0

    Execute Command                 logLevel 0 mmu1
    Execute Command                 logLevel 0 mmu2

    Define Window In Peripheral     mmu2  1  0x2000  0x3000  0x1000  ${PRIV_WRITE_ONLY}
    Execute Command                 sysbus WriteWord 0x2000 0x0124
    Expect Value Read From Address  0x2000  0x0

    Wait For Log Entry              mmu2: MMU fault occured
    Should Not Be In Log            mmu1: MMU fault occured

Execution Stops On Fault
    Requires                        SingleMMU
    Write Range With Doublewords    0x0  0x1000  0x13 # Nop sled on whole page
    Execute Command                 cpu SetRegister ${a0} 0x1C
    Execute Command                 sysbus WriteDoubleWord 0x1C 0x52583  # lw a1, 0(a0)
    Execute Command                 sysbus WriteDoubleWord 0x20 0xd02503 # lw a2, 0(zero)
    Start Emulation
    Sleep 							0.1

    # Assert we are halted on the faulting insn
    ${pc}=                          Execute Command   cpu PC
    Should Be Equal As integers     ${pc}  0x1C
    # Assert that the second insn was not executed
    ${val}=                         Execute Command   cpu GetRegister ${a2}
    Should Be Equal As Integers     ${val}  0x0

Throws When Window Is Out Of Range
    Requires                        SingleMMU
    Run Keyword And Expect Error    *Address is outside of the possible range.*
    ...                             Define Typed Window Using CPU API  0x0  0x100001000  0x0  ${PRIV_ALL}  ${PRIV_ALL}

Works With The Last Page Of Memory
    Requires                        SingleMMU
    Define Typed Window Using CPU API  0x0  0x100000000  0x0  ${PRIV_EXEC_ONLY}  ${PRIV_EXEC_ONLY}
    Execute Command                 sysbus ReadWord 0xFFFFFFFF
