*** Settings ***
Test Teardown                       Custom Teardown
Library                             ${CURDIR}/gdb_library.py
Library                             OperatingSystem

*** Variables ***
${GDB_REMOTE_PORT}                  3342
${MEMORY_START}                     0x80000000
${EXCEPTION_MESSAGE}                Example Exception

${PLATFORM}                         SEPARATOR=\n
...                                 faulty_memory: Python.PythonPeripheral @ sysbus ${MEMORY_START}
...                                 ${SPACE*4}size: 0x4
...                                 ${SPACE*4}initable: false
...                                 ${SPACE*4}script: "raise Exception('${EXCEPTION_MESSAGE}')"
...
...                                 cpu: CPU.RiscV32 @ sysbus {
...                                 ${SPACE*4}cpuType: "rv32g"
...                                 }

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString """${PLATFORM}"""
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}
    Execute Command                 cpu PC ${MEMORY_START}

Check And Run Gdb
    [Arguments]                     ${name}
    ${res}=                         Start Gdb  ${name}
    IF  '${res}' != 'OK'  Fail  ${name} not found  skipped

    Command Gdb                     target remote :${GDB_REMOTE_PORT}  timeout=10

Assert CI Mode
    ${InCIMode}=                    Execute Python  Antmicro.Renode.Emulator.InCIMode
    Should Be True                  ${InCIMode}

Get Log File
    [Arguments]                     ${suffix}
    ${test_name}=                   Set Variable  ${RESULTS_DIRECTORY}/logs/${SUITE_NAME}.renode_${suffix}.log

    RETURN                          ${test_name}

Custom Teardown
    Stop Gdb

*** Test Cases ***
Should Crash Renode
    Assert CI Mode

    Create Machine
    Create Log Tester               0
    Execute Command                 machine EnableGdbLogging ${GDB_REMOTE_PORT} true

    Check And Run Gdb               riscv64-zephyr-elf-gdb

    Command Gdb                     monitor sysbus ReadWord ${MEMORY_START}
    Run Keyword And Expect Error    Connection to remote server broken*  Execute Command  version

    ${log_filename}=                Get Log File  stderr
    ${log_output}=                  Get File  ${log_filename}
    Should Contain                  ${log_output}  ${EXCEPTION_MESSAGE}
