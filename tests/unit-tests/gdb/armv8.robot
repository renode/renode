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

Cortex-R52 Should Show Register ${register}
    Execute Command                 i @platforms/cpus/cortex-r52.repl

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}
    Check and Run Gdb               arm-zephyr-eabi-gdb

    ${registers}=                   Command GDB  info all-registers
    Should Contain                  ${registers}  ${register}

*** Test Cases ***
Cortex-R52 Current Program Status Register Should Show Up In GDB
    Cortex-R52 Should Show Register cpsr

Cortex-R52 General Purpose Register Should Show Up In GDB
    Cortex-R52 Should Show Register r5

Cortex-R52 ID Register Should Show Up In GDB
    Cortex-R52 Should Show Register ID_DFR0

Cortex-R52 System Control Register Should Show Up In GDB
    Cortex-R52 Should Show Register HSCTLR

Cortex-R52 Debug Register Should Show Up In GDB
    Cortex-R52 Should Show Register DSPSR

Cortex-R52 Performance Monitor Register Should Show Up In GDB
    Cortex-R52 Should Show Register PMCR

Cortex-R52 Implementation-Defined Register Should Show Up In GDB
    Cortex-R52 Should Show Register IMP_SLAVEPCTLR

Cortex-R52 64-Bit Register Should Show Up In GDB
    Cortex-R52 Should Show Register CPUACTLR
