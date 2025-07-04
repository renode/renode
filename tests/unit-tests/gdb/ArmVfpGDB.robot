*** Settings ***
Suite Setup                         Setup
Suite Teardown                      Teardown
Library                             Process
Resource                            ${RENODEKEYWORDS}
Library                             ${CURDIR}/gdb_library.py

*** Variables ***
${BIN}                              https://dl.antmicro.com/projects/renode/cortex-v8m_tz-extended-frame-test.elf-s_92692-88fe4c7b72824b0d3700927033873924025c2b7d
${GDB_REMOTE_PORT}                  3337
${GDB_TIMEOUT}                      10

${PLATFORM}                         SEPARATOR=\n  """
...                                 mem: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x40000
...                                 uart: UART.NS16550 @ sysbus 0x80000
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m33"
...                                 ${SPACE*4}enableTrustZone: true
...                                 ${SPACE*4}nvic: nvic
...                                 nvic: IRQControllers.NVIC @ sysbus 0xe000e000
...                                 ${SPACE*4}-> cpu@0
...                                 """

*** Keywords ***
Prepare Platform
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus LoadELF @${BIN}
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Compare S Register
    [Arguments]                     ${number}  ${expected}

    ${regvalue}=                    Command Gdb  p $s${number}  timeout=${GDB_TIMEOUT}
    ${regvalue}=                    Evaluate  ${regvalue.split('=')[1].strip()}
    Should Be Equal                 ${regvalue}  ${expected}

Check And Run Gdb
    [Arguments]                     ${name}

    ${res}=                         Start Gdb  ${name}
    IF  '${res}' != 'OK'  Fail  ${name} not found  skipped

    Command Gdb                     target remote :${GDB_REMOTE_PORT}  timeout=${GDB_TIMEOUT}
    Command Gdb                     monitor start

*** Test Cases ***
# This test does the following:
# 1. Loads the binary that sets each of the s0 ... s31
#  registers to the value: s(n) = 100.0 + n
#
# 2. Stops execution right after the registers are set
#
# 3. Compares register values with ground truth

Test VFP registers
    [Tags]                          skip_windows
    [Setup]                         Prepare Platform
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Command Gdb                     break *0x00013a4  timeout=${GDB_TIMEOUT}
    Command Gdb                     continue

    # Check S0-S31 registers
    FOR  ${index}  IN RANGE  32
        ${expected}=                    Evaluate  100.0 + ${index}
        Compare S Register              ${index}  ${expected}
    END
