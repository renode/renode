*** Settings ***
Test Setup                          Create HiFive1 Demo
Library                             ${CURDIR}/gdb_library.py

*** Variables ***
${GDB_REMOTE_PORT}                  3339

${ENTRYPOINT}                       0x80000000
${ASSEMBLY}                         SEPARATOR=\n
...                                 .equ UART0_BASE, 0x10013000
...                                 .equ UART_TXDATA, 0x00
...                                 .equ UART_TXCTRL, 0x08
...
...                                 li sp, 0x80004000 // +0
...                                 li t3, 0x123  // +4
...                                 li t4, 0x456  // +8
...
...                                 // UART
...                                 li t0, UART0_BASE  // +0c
...                                 li t1, 1  // +0e
...                                 sw t1, UART_TXCTRL(t0)  // +12
...
...                                 call putc  // +12, +16
...
...                                 hang:
...                                 j hang  // +1c
...
...                                 putc:
...                                 li a0, '*'  // +20
...                                 sw a0, UART_TXDATA(t0)  // +24
...                                 ret  // +28

*** Keywords ***
Create HiFive1 Demo
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/sifive-fe310.repl
    Execute Command                 cpu AssembleBlock ${ENTRYPOINT} "${ASSEMBLY}"
    Execute Command                 cpu PC ${ENTRYPOINT}
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Check And Run Gdb
    [Arguments]                     ${name}
    ${res}=                         Start Gdb  ${name}
    Run Keyword If                  '${res}' != 'OK'
    ...                             Fail  ${name} not found  skipped

    Command Gdb                     target remote :${GDB_REMOTE_PORT}  timeout=10

Compare Register
    [Arguments]                     ${cpu}  ${reg}

    ${g_x0}=                        Command Gdb  p/x $x${reg}
    ${r_x0}=                        Execute Command  ${cpu} GetRegisterUnsafe ${reg}

    Should Be Equal As Integers     ${g_x0.split('=')[1].strip()}  ${r_x0.strip()}

Compare General Registers
    [Arguments]                     ${cpu}

    ${g_r}=                         Command Gdb  info registers
    ${r_r}=                         Execute Command  ${cpu} GetRegistersValues

    FOR  ${idx}  IN RANGE  32
        Compare Register                ${cpu}  ${idx}
    END

*** Test Cases ***
Should Set Registers Properly
    [Tags]                          skip_windows
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Execute Command                 reverseExecMode true

    ${expected_regs}=               Execute Command  sysbus.cpu GetRegistersValues
    Command Gdb                     stepi
    ${other_regs}=                  Execute Command  sysbus.cpu GetRegistersValues
    Command Gdb                     reverse-stepi
    ${result_regs}=                 Execute Command  sysbus.cpu GetRegistersValues
    Should Be Equal As Strings      ${expected_regs}  ${result_regs}
    Should Not Be Equal As Strings  ${expected_regs}  ${other_regs}

    Compare General Registers       sysbus.cpu

Should Revert To Jump
    [Tags]                          skip_windows
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Execute Command                 reverseExecMode true

    Command Gdb                     break *${ENTRYPOINT}+0x16
    Command Gdb                     continue
    ${expected_pc}=                 Execute Command  sysbus.cpu PC
    Command Gdb                     stepi
    Command Gdb                     reverse-stepi
    ${result_pc}=                   Execute Command  sysbus.cpu PC

    Should Be Equal As Numbers      ${expected_pc}  ${result_pc}

Should Stop At Breakpoint After Stepping Back
    [Tags]                          skip_windows
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Execute Command                 reverseExecMode true

    Command Gdb                     break *${ENTRYPOINT}+0x08
    Command Gdb                     break *${ENTRYPOINT}+0x0c
    Command Gdb                     continue

    Command Gdb                     continue
    ${expected_pc}=                 Execute Command  sysbus.cpu PC
    ${expected_icount}=             Execute Command  sysbus.cpu GetCurrentInstructionsCount
    Command Gdb                     reverse-stepi
    ${x}=                           Command Gdb  continue  timeout=5
    Should Contain                  ${x}  Breakpoint 2

    ${result_pc}=                   Execute Command  sysbus.cpu PC
    ${result_icount}=               Execute Command  sysbus.cpu GetCurrentInstructionsCount

    Should Be Equal As Numbers      ${expected_pc}  ${result_pc}
    Should Be Equal As Numbers      ${expected_icount}  ${result_icount}

Should Log Warning When No Snapshots Taken
    [Tags]                          skip_windows
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Create Log Tester               1

    Command Gdb                     stepi
    ${expected_pc}=                 Execute Command  sysbus.cpu PC
    Command Gdb                     reverse-stepi
    Wait For Log Entry              There are no snapshots taken before this timestamp.
    ${result_pc}=                   Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers      ${expected_pc}  ${result_pc}

Should Preserve Peripheral Logging Level
    [Tags]                          skip_windows
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Create Log Tester               1
    Execute Command                 reverseExecMode true
    Execute Command                 logLevel -1 cpu

    Command Gdb                     stepi
    Wait For Log Entry              cpu: Stepping 1 step(s)
    Command Gdb                     reverse-stepi
    Command Gdb                     stepi
    Wait For Log Entry              cpu: Stepping 1 step(s)

Should Preserve Peripheral Access Logging
    [Tags]                          skip_windows
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Create Log Tester               1
    Execute Command                 reverseExecMode true
    Execute Command                 sysbus LogPeripheralAccess sysbus.uart0

    Command Gdb                     break *${ENTRYPOINT}+0x24
    Command Gdb                     continue
    Command Gdb                     stepi
    Wait For Log Entry              uart0: [cpu: 0x80000024] WriteUInt32 to 0x0 (TransmitData), value 0x2A
    Command Gdb                     reverse-stepi
    Command Gdb                     stepi
    Wait For Log Entry              uart0: [cpu: 0x80000024] WriteUInt32 to 0x0 (TransmitData), value 0x2A

Should Preserve Gdb Logging
    [Tags]                          skip_windows
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Create Log Tester               1
    Execute Command                 reverseExecMode true
    Execute Command                 machine EnableGdbLogging ${GDB_REMOTE_PORT} true

    Command Gdb                     stepi
    Command Gdb                     reverse-stepi
    Execute Command                 logLevel 0
    Command Gdb                     stepi
    Wait For Log Entry              cpu: GDB packet received

Should Preserve Function Names Logging
    [Tags]                          skip_windows
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Create Log Tester               1
    Execute Command                 reverseExecMode true
    Execute Command                 sysbus.cpu LogFunctionNames true

    Command Gdb                     stepi
    Wait For Log Entry              cpu: Entering function
    Command Gdb                     reverse-stepi
    Command Gdb                     stepi
    Wait For Log Entry              cpu: Entering function

Should Step Three Steps Back
    [Tags]                          skip_windows
    Check And Run GDB               riscv64-zephyr-elf-gdb
    Execute Command                 reverseExecMode true

    ${expected_pc}=                 Execute Command  sysbus.cpu PC
    ${expected_icount}=             Execute Command  sysbus.cpu GetCurrentInstructionsCount

    Command GDB                     stepi 3

    ${intermediate_pc}=             Execute Command  sysbus.cpu PC
    Should Not Be Equal             ${expected_pc}  ${intermediate_pc}

    Command GDB                     reverse-stepi 3
    ${result_pc}=                   Execute Command  sysbus.cpu PC
    ${result_icount}=               Execute Command  sysbus.cpu GetCurrentInstructionsCount

    Should Be Equal As Numbers      ${expected_pc}  ${result_pc}
    Should Be Equal As Numbers      ${expected_icount}  ${result_icount}
