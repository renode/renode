*** Settings ***
Library                             ${CURDIR}/gdb_library.py

*** Variables ***
${GDB_REMOTE_PORT}                  3346
${IMXRT700_CPU0_URL}                https://dl.antmicro.com/projects/renode/mimxrt700_evk_mimxrt798s_cm33_cpu0--philosophers.elf-s_789720-6c27fd55c15eb9f986fcf654637b4046945d42cc
${IMXRT700_CPU1_URL}                https://dl.antmicro.com/projects/renode/mimxrt700_evk_mimxrt798s_cm33_cpu1--philosophers.elf-s_675736-cf65e9273232e7ab87557db5b6871772db82ddff
${MULTIARCH_REPL}                   SEPARATOR=${\n}
...                                 """
...                                 cpu_arm: CPU.ARMv7R @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-r5f"
...                                 cpu_riscv: CPU.RiscV64 @ sysbus
...                                 ${SPACE*4}cpuType: "rv64g"
...                                 """
${ZYNQMP_PHILOSOPHERS_ELF}          https://dl.antmicro.com/projects/renode/zephyr-philosophers-xilinx_zynqmp_r5.elf-s_515508-f1bcfa0adcf29714365ae53609420644614298c9

*** Keywords ***
Check And Run Gdb
    [Arguments]                     ${name}
    ${res}=                         Start Gdb  ${name}
    IF  '${res}' != 'OK'  Fail  ${name} not found  skipped

    Command Gdb                     target extended-remote :${GDB_REMOTE_PORT}  timeout=10

Create IMXRT700
    ${x}=                           Download File  ${IMXRT700_CPU0_URL}
    Set Suite Variable              ${IMXRT700_CPU0_ELF}  ${x}

    ${x}=                           Download File  ${IMXRT700_CPU1_URL}
    Set Suite Variable              ${IMXRT700_CPU1_ELF}  ${x}

    Execute Command                 i @platforms/boards/mimxrt700_evk.repl
    ${x}=                           Catenate  SEPARATOR=${\n}
    ...                             macro reset
    ...                             """
    ...                             sysbus LoadELF @${IMXRT700_CPU0_ELF} cpu=cpu0
    ...                             sysbus LoadELF @${IMXRT700_CPU1_ELF} cpu=cpu1
    ...                             cpu0 VectorTableOffset `sysbus GetSymbolAddress "_vector_table" context=cpu0`
    ...                             cpu1 VectorTableOffset `sysbus GetSymbolAddress "_vector_table" context=cpu1`
    ...                             """

    Execute Command                 ${x}
    Execute Command                 runMacro $reset
    Execute Command                 machine StartMultiprocessGdbServer ${GDB_REMOTE_PORT} [cpu0, cpu1]

*** Test Cases ***
Should Start Gdb Server With Multiple Processes
    Execute Command                 i @platforms/cpus/zynqmp.repl

    Execute Command                 machine StartMultiprocessGdbServer ${GDB_REMOTE_PORT} [cluster0, cluster1]
    Check and Run Gdb               aarch64-zephyr-elf-gdb

    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1.1 "machine-0.apu0" 0x0000000000000000 in ??
    Should Contain                  ${x}  Thread 1.2 "machine-0.apu1" 0x0000000000000000 in ??
    Should Contain                  ${x}  Thread 1.3 "machine-0.apu2" 0x0000000000000000 in ??
    Should Contain                  ${x}  Thread 1.4 "machine-0.apu3" 0x0000000000000000 in ??

    ${x}=                           Command GDB  show architecture
    Should Contain                  ${x}  aarch64

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2

    ${x}=                           Command GDB  show architecture
    Should Contain                  ${x}  arm

    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1.1 "machine-0.apu0" 0x0000000000000000 in ??
    Should Contain                  ${x}  Thread 1.2 "machine-0.apu1" 0x0000000000000000 in ??
    Should Contain                  ${x}  Thread 1.3 "machine-0.apu2" 0x0000000000000000 in ??
    Should Contain                  ${x}  Thread 1.4 "machine-0.apu3" 0x0000000000000000 in ??
    # RPUs are 32-bit so they should have shorter PCs
    Should Contain                  ${x}  Thread 2.5 "machine-0.rpu0" 0x00000000 in ??
    Should Contain                  ${x}  Thread 2.6 "machine-0.rpu1" 0x00000000 in ??

    Command GDB                     inferior 1
    # inferior 1 should still report aarch64
    ${x}=                           Command GDB  show architecture
    Should Contain                  ${x}  aarch64

Should Attach Another Process After Starting The First One
    Create IMXRT700

    Check and Run Gdb               arm-zephyr-eabi-gdb

    Command GDB                     symbol-file ${IMXRT700_CPU0_ELF}
    Command GDB                     b main

    ${x}=                           Command GDB  c  timeout=120
    Should Contain                  ${x}  Breakpoint 1, main

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2
    Command GDB                     symbol-file ${IMXRT700_CPU1_ELF}
    Command GDB                     b main inferior 2

    ${x}=                           Command GDB  c  timeout=120
    Should Contain                  ${x}  Thread 2.1 "machine-0.cpu1" hit Breakpoint 1, main

Should Attach To A Process Containing Halted CPUs
    Execute Command                 i @platforms/cpus/zynqmp.repl
    Execute Command                 machine StartMultiprocessGdbServer ${GDB_REMOTE_PORT} [cluster0, cluster1]

    ${elf_path}=                    Download File  ${ZYNQMP_PHILOSOPHERS_ELF}
    Execute Command                 cluster0 ForEach IsHalted true
    Execute Command                 cluster1.rpu0 IsHalted false
    Execute Command                 cluster1.rpu1 IsHalted true
    Execute Command                 sysbus LoadELF @${elf_path} cpu=cluster1.rpu0

    Check and Run Gdb               aarch64-zephyr-elf-gdb

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2
    Command GDB                     symbol-file ${elf_path}
    Command GDB                     b main

    Command GDB                     set schedule-multiple on

    # Switching to inferior 1 to test that the breakpoint from
    # inferior 2 switches the context in GDB correctly
    Command GDB                     inferior 1

    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  * 1.1 Thread 1.1 "machine-0.apu0"  collapse_spaces=${True}

    ${x}=                           Command GDB  c  timeout=120
    Should Contain                  ${x}  Thread 2.1 "machine-0.rpu0" hit Breakpoint 1, main

Should Connect To Processes With Unrelated Architectures
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${MULTIARCH_REPL}
    Execute Command                 machine StartMultiprocessGdbServer ${GDB_REMOTE_PORT} [cpu_arm, cpu_riscv]
    Check and Run Gdb               gdb-multiarch

    ${x}=                           Command GDB  show architecture
    Should Contain                  ${x}  arm

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2

    ${x}=                           Command GDB  show architecture
    Should Contain                  ${x}  riscv:rv64

    # inferior 1 should still report arm
    Command GDB                     inferior 1
    ${x}=                           Command GDB  show architecture
    Should Contain                  ${x}  arm

    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1.1 "machine-0.cpu_arm" 0x00000000 in ??  collapse_spaces=${True}
    Should Contain                  ${x}  Thread 2.2 "machine-0.cpu_riscv" 0x0000000000001000 in ??  collapse_spaces=${True}

Should Detach From A Process
    Create IMXRT700

    Check and Run Gdb               arm-zephyr-eabi-gdb

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2

    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1.1 "machine-0.cpu0"
    Should Contain                  ${x}  Thread 2.2 "machine-0.cpu1"

    Command GDB                     inferior 1
    Command GDB                     detach

    ${x}=                           Command GDB  info threads
    Should Not Contain              ${x}  Thread 1.1 "machine-0.cpu0"
    Should Contain                  ${x}  Thread 2.2 "machine-0.cpu1"

Should Report Breakpoints On Multiple Processes
    Create IMXRT700

    Check and Run Gdb               arm-zephyr-eabi-gdb

    Command GDB                     symbol-file ${IMXRT700_CPU0_ELF}

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2
    Command GDB                     symbol-file ${IMXRT700_CPU1_ELF}

    Command GDB                     inferior 1
    ${x}=                           Command GDB  b main
    Should Contain                  ${x}  2 locations

    ${cpu1_inst_before}=            Execute Command  cpu1 ExecutedInstructions

    ${x}=                           Command GDB  c  timeout=120
    Should Contain                  ${x}  Thread 1.1 "machine-0.cpu0" hit Breakpoint 1, main

    ${cpu1_inst_after}=             Execute Command  cpu1 ExecutedInstructions
    Should Be Equal As Integers     ${cpu1_inst_before.strip()}  ${cpu1_inst_after.strip()}

    Command GDB                     inferior 2

    ${x}=                           Command GDB  c  timeout=120
    Should Contain                  ${x}  Thread 2.1 "machine-0.cpu1" hit Breakpoint 1, main

Should Report Breakpoints On Multiple Processes With Schedule Multiple Enabled
    Create IMXRT700
    Execute Command                 emulation SetGlobalSerialExecution true

    Check and Run Gdb               arm-zephyr-eabi-gdb
    Command GDB                     set schedule-multiple on

    Command GDB                     symbol-file ${IMXRT700_CPU0_ELF}

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2
    Command GDB                     symbol-file ${IMXRT700_CPU1_ELF}

    Command GDB                     inferior 1

    ${x}=                           Command GDB  b main
    Should Contain                  ${x}  2 locations

    # Breakpoint from a different inferior process should be acknowledged
    ${x}=                           Command GDB  c  timeout=120
    Should Contain                  ${x}  Thread 2.1 "machine-0.cpu1" hit Breakpoint 1, main

    ${x}=                           Command GDB  c  timeout=120
    Should Contain                  ${x}  Thread 1.1 "machine-0.cpu0" hit Breakpoint 1, main

Ctrl-C Should Work With Multiple Processes
    Create IMXRT700
    Execute Command                 emulation SetGlobalSerialExecution true

    Check and Run Gdb               arm-zephyr-eabi-gdb
    Command GDB                     set schedule-multiple on

    Command GDB                     symbol-file ${IMXRT700_CPU0_ELF}

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2
    Command GDB                     symbol-file ${IMXRT700_CPU1_ELF}

    Command GDB                     inferior 1
    Async Command GDB               continue
    Sleep                           3s
    Send Signal To Gdb              2

    ${x}=                           Read Async Command Output  timeout=120
    Should Contain                  ${x}  Thread 1.1 "machine-0.cpu0" received signal SIGINT

    Command GDB                     inferior 2
    Async Command GDB               continue
    Sleep                           3s
    Send Signal To Gdb              2

    ${x}=                           Read Async Command Output  timeout=120
    Should Contain                  ${x}  Thread 2.1 "machine-0.cpu1" received signal SIGINT

Ctrl-C Should Work On A Process With Only Halted Cores
    Execute Command                 i @scripts/single-node/zynqmp_linux.resc

    Execute Command                 machine StartMultiprocessGdbServer ${GDB_REMOTE_PORT} [cluster0, cluster1]
    Check and Run Gdb               aarch64-zephyr-elf-gdb

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2

    Async Command Gdb               c
    Sleep                           3s
    Send Signal To Gdb              2

    ${x}=                           Read Async Command Output  timeout=120
    Should Contain                  ${x}  Thread 2.1 "ZynqUS+.rpu0" received signal SIGINT

    ${inst}=                        Execute Command  cluster1.rpu0 ExecutedInstructions
    Should Be Equal As Integers     ${inst}  0

Single Stepping Should Work With Multiple Processes
    Create IMXRT700
    # Quantum is lowered to test that single stepping over a quantum doesn't
    # deadlock the simulation
    Execute Command                 emulation SetGlobalQuantum "0.00000001"

    Check and Run Gdb               arm-zephyr-eabi-gdb

    Command GDB                     symbol-file ${IMXRT700_CPU0_ELF}

    Command GDB                     add-inferior
    Command GDB                     inferior 2
    Command GDB                     attach 2
    Command GDB                     symbol-file ${IMXRT700_CPU1_ELF}

    Command GDB                     inferior 1
    Command GDB                     stepi 100  timeout=120

    ${inst}=                        Execute Command  cpu0 ExecutedInstructions
    Should Be Equal As Integers     ${inst}  100  cpu0 executed an invalid amount of instructions

    # PID2 (cpu1) should not have moved while GDB was stepping PID1 (cpu0)
    ${inst}=                        Execute Command  cpu1 ExecutedInstructions
    Should Be Equal As Integers     ${inst}  0

    Command GDB                     inferior 2
    Command GDB                     stepi 100  timeout=120

    ${inst}=                        Execute Command  cpu1 ExecutedInstructions
    Should Be Equal As Integers     ${inst}  100  cpu1 executed an invalid amount of instructions

    # PID1 (cpu0) should not have moved while GDB was stepping PID2 (cpu1)
    ${inst}=                        Execute Command  cpu0 ExecutedInstructions
    Should Be Equal As Integers     ${inst}  100  cpu2 moved while cpu1 was stepping
