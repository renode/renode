*** Settings ***
Library                             ${CURDIR}/gdb_library.py

*** Variables ***
${GDB_REMOTE_PORT}                  3338

*** Keywords ***
Check And Run Gdb
    [Arguments]                     ${name}
    ${res}=                         Start Gdb  ${name}
    IF  '${res}' != 'OK'  Fail  ${name} not found  skipped

    Command Gdb                     target remote :${GDB_REMOTE_PORT}  timeout=10

Cortex-R52 Should Have Readable Register ${register}
    Execute Command                 i @platforms/cpus/cortex-r52.repl

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}
    Check and Run Gdb               arm-zephyr-eabi-gdb

    Should Have Register ${register}
    ${register} Should Be Readable

Cortex-R52 Should Have Read/Writable Register ${register}
    Cortex-R52 Should Have Readable Register ${register}
    ${register} Should Be Writable

Cortex-R52 Should Have Readonly Register ${register}
    Cortex-R52 Should Have Readable Register ${register}

    # Try to write to the register, and verify that its contents remain unchanged.
    ${old_value}=                   Get Value Of ${register}
    Set GDB Register Value Of ${register} To 0xdeadbeef
    ${current_value}=               Get Value Of ${register}
    Should Be Equal As Integers     ${old_value}  ${current_value}  Expected register value to remain unchanged (old value was `${old_value}`) but it was changed to `${current_value}`

Should Have Register ${register}
    ${registers}=                   Command GDB  info all-registers
    Should Contain                  ${registers}  ${register}  Register `${register}` did not show up in `info all-registers`  ignore_case=True

${register} Should Be Readable
    ${expected_value}=              Get Value Of ${register}
    ${value}=                       Get GDB Register Value Of ${register}
    Should Be Equal As Integers     ${value}  ${expected_value}  Expected register `${register}` to contain `${expected_value}` but it contains `${value}`

${register} Should Be Writable
    ${current_value}=               Get GDB Register Value Of ${register}  pad=True
    ${current_hex_chars}=           Set Variable  ${current_value}[2:]
    ${number_of_hex_chars}=         Get Length  ${current_hex_chars}
    IF  ${number_of_hex_chars} == 16
        ${new_value}=                   Set Variable  0xdeadbeef1badb002
    ELSE
        ${new_value}=                   Set Variable  0xdeadbeef
    END
    Set GDB Register Value Of ${register} To ${new_value}
    ${value}=                       Get Value Of ${register}
    Should Be Equal As Integers     ${value}  ${new_value}  Expected register `${register}` to contain `${new_value}` but it contains `${value}`

Get GDB Register Value Of ${register}
    [Arguments]                     ${pad}=False
    ${format}=                      Set Variable If  ${pad}
    ...                             z  # hexadecimal, padded to register width
    ...                             x  # hexadecimal
    ${output}=                      Command GDB  print/${format} $${register}
    # Output is in the format $1 = 0x3010006
    ${value}=                       Fetch From Right  ${output}  =
    ${stripped}=                    Set Variable  ${value.strip()}
    IF  '${stripped}' == 'void'
        Fail                            GDB could not fetch value for register ${register}
    END
    RETURN                          ${stripped}

Set GDB Register Value Of ${register} To ${value}
    Command GDB                     set $${register} = ${value}

Get Value Of ${register}
    TRY
        ${value}=                       Execute Command  cpu GetSystemRegisterValue "${register}"
    EXCEPT
        ${value}=                       Execute Command  cpu GetRegister "${register.upper()}"
    END
    RETURN                          ${value}

*** Test Cases ***
Cortex-R52 General Purpose Register Should Show Up In GDB
    Cortex-R52 Should Have Read/Writable Register r5

Cortex-R52 ID Register Should Show Up In GDB
    Cortex-R52 Should Have Readonly Register ID_DFR0

Cortex-R52 System Control Register Should Show Up In GDB
    Cortex-R52 Should Have Read/Writable Register HSCTLR

Cortex-R52 Debug Register Should Show Up In GDB
    Cortex-R52 Should Have Read/Writable Register HDCR

Cortex-R52 Performance Monitor Register Should Show Up In GDB
    Cortex-R52 Should Have Read/Writable Register PMCR

Cortex-R52 Implementation-Defined Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register IMP_CTCMREGIONR

Cortex-R52 64-Bit Register Should Show Up In GDB
    Cortex-R52 Should Have Read/Writable Register PAR

Cortex-R52 System Timer Register Should Show Up In GDB
    Cortex-R52 Should Have Readonly Register CNTVCT

Cortex-R52 GIC Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register ICC_BPR0
