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

Should Have Register ${register}
    ${registers}=                   Command GDB  info all-registers
    Should Contain                  ${registers}  ${register}  Register `${register}` did not show up in `info all-registers`  ignore_case=True

${register} Should Be Readable
    ${expected_value}=              Get Value Of ${register}
    ${value}=                       Get GDB Register Value Of ${register}
    Should Be Equal As Integers     ${value}  ${expected_value}  Expected register `${register}` to contain `${expected_value}` but it contains `${value}`

Get GDB Register Value Of ${register}
    ${output}=                      Command GDB  print/x $${register}
    # Output is in the format $1 = 0x3010006
    ${value}=                       Fetch From Right  ${output}  =
    ${stripped}=                    Set Variable  ${value.strip()}
    IF  '${stripped}' == 'void'
        Fail                            GDB could not fetch value for register ${register}
    END
    RETURN                          ${stripped}

Get Value Of ${register}
    TRY
        ${value}=                       Execute Command  cpu GetSystemRegisterValue "${register}"
    EXCEPT
        ${value}=                       Execute Command  cpu GetRegister "${register.upper()}"
    END
    RETURN                          ${value}

*** Test Cases ***
Cortex-R52 General Purpose Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register r5

Cortex-R52 ID Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register ID_DFR0

Cortex-R52 System Control Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register HSCTLR

Cortex-R52 Debug Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register HDCR

Cortex-R52 Performance Monitor Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register PMCR

Cortex-R52 Implementation-Defined Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register IMP_CTCMREGIONR

Cortex-R52 64-Bit Register Should Show Up In GDB
    Cortex-R52 Should Have Readable Register PAR
