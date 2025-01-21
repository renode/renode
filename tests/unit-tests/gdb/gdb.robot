*** Settings ***
Library                             ${CURDIR}/gdb_library.py

*** Variables ***
${GDB_REMOTE_PORT}                  3334
${VM_DEMO_URL}                      https://dl.antmicro.com/projects/renode/sifive-fe310--vm-demo.elf-s_10440-fbc6e11346ef9e43047beb299daaaaa7eb6b0ce2
${VM_DEMO}                          None
${PAGETABLE}                        @https://dl.antmicro.com/projects/renode/sifive-fe310--page_table.bin-s_16384-3641a5434787756cd2f017d4df9775f16951a655
${UNLEASHED_BIN}                    @https://dl.antmicro.com/projects/renode/hifive-unleashed--bbl.elf-s_17219640-c7e1b920bf81be4062f467d9ecf689dbf7f29c7a
${UNLEASHED_FDT}                    @https://dl.antmicro.com/projects/renode/hifive-unleashed--devicetree.dtb-s_10532-70cd4fc9f3b4df929eba6e6f22d02e6ce4c17bd1
${UNLEASHED_VMINUX}                 @https://dl.antmicro.com/projects/renode/hifive-unleashed--vmlinux.elf-s_80421976-46788813c50dc7eb1a1a33c1730ca633616f75f5

*** Keywords ***
Create Versatile Express
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/boards/vexpress.repl
    Execute Command
    ...                             machine LoadPlatformDescriptionFromString "fake_memory: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command                 machine PyDevFromFile @scripts/pydev/repeater.py 0xf0000000 0x4 True
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Create Versatile
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/versatile.repl
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Create Leon3
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/leon3.repl
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Create MPC5567
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/mpc5567.repl
    Execute Command                 sysbus.cpu PC 0
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Create Microwatt
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/microwatt.repl
    Execute Command
    ...                             machine LoadPlatformDescriptionFromString "fake_memory: Memory.MappedMemory @ sysbus 0x40000000 { size: 0x1000 }"
    Execute Command                 sysbus.cpu PC 0
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Create VM Demo
    # We need to download this to pass it to gdb as a `file`
    ${x}=                           Download File  ${VM_DEMO_URL}
    Set Suite Variable              ${VM_DEMO}  ${x}

    Execute Command                 mach create
    Execute Command                 using sysbus
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/sifive-fe310.repl
    # PAGETABLE is a raw binary representation of page table[s] (max 3), it's in RISC-V spec.
    ${macro_reset}=                 catenate  SEPARATOR=
    ...                             macro reset  ${\n}
    ...                             """  ${\n}
    ...                             sysbus LoadELF @${VM_DEMO}  ${\n}
    ...                             sysbus LoadBinary @${PAGETABLE} 0x80000000  ${\n}
    ...                             """  ${\n}
    Execute Command                 ${macro_reset}

    Execute Command                 runMacro $reset
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Create Machine With PythonPeripheral
    Execute Command                 mach create
    Execute Command                 using sysbus

    # Minimal Cortex-M platform with PythonPeripheral
    ${platform}=                    catenate
    ...                             SEPARATOR=
    ...                             nvic: IRQControllers.NVIC @ sysbus 0xe000e000 { -> cpu@0 }
    ...                             ${\n}
    ...                             cpu: CPU.CortexM @ sysbus { cpuType: \\"cortex-m0\\"; nvic: nvic }
    ...                             ${\n}
    ...                             flash: Memory.MappedMemory @ sysbus 0x8000000 { size: 0x10000 }
    ...                             ${\n}
    ...                             rcc: Python.PythonPeripheral @ sysbus 0x40000000 { size: 0x400; initable: true; filename: \\"scripts/pydev/rolling-bit.py\\" }
    ...                             ${\n}

    Execute Command                 machine LoadPlatformDescriptionFromString "${platform}"

    # This binary:
    # * Loads 0x40000000 to r3
    # * Loads 0xBAD to r2
    # * Stores r2 to an address pointed by r3 (PythonPeripheral access)
    # * Loops indefinetely
    Execute Command                 cpu PC 0x8000000

    # mov.w r3, 0x40000000
    Execute Command                 sysbus WriteWord 0x8000000 0xf04f
    Execute Command                 sysbus WriteWord 0x8000002 0x4380
    # movw r2, 0xBAD
    Execute Command                 sysbus WriteWord 0x8000004 0xf640
    Execute Command                 sysbus WriteWord 0x8000006 0x32ad
    # str r2, [r3, #0]
    Execute Command                 sysbus WriteDoubleWord 0x8000008 0x601a
    # b.n 8
    Execute Command                 sysbus WriteDoubleWord 0x800000a 0xe7fd

    # Start GDB server
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Create HiFive Unleashed
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/sifive-fu540.repl
    Execute Command                 sysbus LoadELF ${UNLEASHED_BIN}
    Execute Command                 sysbus LoadFdt ${UNLEASHED_FDT} 0x81000000 "earlyconsole mem=256M@0x80000000"
    Execute Command                 sysbus LoadSymbolsFrom ${UNLEASHED_VMINUX}
    Execute Command                 sysbus.e51 SetRegister 11 0x81000000

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} cpuCluster="all"

    Execute Command                 machine EnableGdbLogging ${GDB_REMOTE_PORT} true
    Execute Command                 logLevel 0 sysbus.e51
    Execute Command                 logLevel 0 sysbus.u54_1
    Execute Command                 logLevel 0 sysbus.u54_2
    Execute Command                 logLevel 0 sysbus.u54_3
    Execute Command                 logLevel 0 sysbus.u54_4

Add Per Core Memory Regions
    ${per_core_regions}=            catenate  SEPARATOR=
    ...                             u54_1_mem: Memory.MappedMemory @ {  ${\n}
    ...                             ${SPACE*4}sysbus new Bus.BusPointRegistration {  ${\n}
    ...                             ${SPACE*4}${SPACE*4}address: 0x4f00000000;  ${\n}
    ...                             ${SPACE*4}${SPACE*4}cpu: u54_1  ${\n}
    ...                             ${SPACE*4}}  ${\n}
    ...                             }  ${\n}
    ...                             ${SPACE*4}size: 0x1000  ${\n}
    ...                             ${\n}
    ...                             u54_2_mem: Memory.MappedMemory @ {  ${\n}
    ...                             ${SPACE*4}sysbus new Bus.BusPointRegistration {  ${\n}
    ...                             ${SPACE*4}${SPACE*4}address: 0x4f00000000;  ${\n}
    ...                             ${SPACE*4}${SPACE*4}cpu: u54_2  ${\n}
    ...                             ${SPACE*4}}  ${\n}
    ...                             }  ${\n}
    ...                             ${SPACE*4}size: 0x1000  ${\n}

    Execute Command                 machine LoadPlatformDescriptionFromString "${per_core_regions}"

Create RISC-V Vectored Machine
    Execute Command                 mach create
    Execute Command
    ...                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { timeProvider: empty; cpuType: \\"rv32imacv\\" }"

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}

Check And Run Gdb
    [Arguments]                     ${name}
    ${res}=                         Start Gdb  ${name}
    IF  '${res}' != 'OK'  Fail  ${name} not found  skipped

    Command Gdb                     target remote :${GDB_REMOTE_PORT}  timeout=10

Kill Gdb And Wait
    Stop GDB
    Wait For Process

Test Register By Id
    [Arguments]                     ${id}  ${gdb_name}  ${value}
    Execute Command                 sysbus.cpu SetRegister ${id} ${value}
    Test Register Common            ${gdb_name}  ${value}

Test Register By Name
    [Arguments]                     ${cpu_name}  ${gdb_name}  ${value}
    Execute Command                 sysbus.cpu ${cpu_name} ${value}
    Test Register Common            ${gdb_name}  ${value}

Test Register Common
    [Arguments]                     ${gdb_name}  ${value}
    Command Gdb                     flushregs
    ${v}=                           Command Gdb  p (void *) \$${gdb_name}
    Should Contain                  ${v}  = (void *)  ${value}

Test Memory
    [Arguments]                     ${address}  ${expected_value}
    ${actual_value}=                Execute Command  sysbus ReadDoubleWord ${address}
    Should Be Equal As Numbers      ${actual_value}  ${expected_value}

Test Number Of Differences
    [Arguments]                     ${data1}  ${data2}  ${expected_number_of_differences}
    ${ctr}=                         SetVariable  ${0}

    FOR  ${m1}  ${m2}  IN ZIP  ${data1}  ${data2}
        ${ctr}=                         Evaluate  ${ctr} + (1 if ${m1} != ${m2} else 0)
    END

    Should Be Equal As Numbers      ${expected_number_of_differences}  ${ctr}

Create Test File
    [Arguments]                     ${length}  ${file}
    ${string}=                      Set Variable  ${EMPTY}
    FOR  ${index}  IN RANGE  ${length}
        ${i}=                           Evaluate  ${index} % 0x80
        ${string}=                      Catenate  ${string}  ${i}
    END
    ${bytes}=                       Convert To Bytes  ${string}  int
    Create Binary File              ${file}  ${bytes}

Stepi And Check PC
    [Arguments]                     ${PC}
    ${res}=                         Command Gdb  stepi
    Should Contain                  ${res}  ${PC} in ?? ()

Compare Register
    [Arguments]                     ${cpu}  ${reg}

    ${g_x0}=                        Command GDB  p/x $x${reg}
    ${r_x0}=                        Execute Command  ${cpu} GetRegister ${reg}

    Should Be Equal As Integers     ${g_x0.split('=')[1].strip()}  ${r_x0.strip()}

Compare General Registers
    [Arguments]                     ${cpu}

    ${g_r}=                         Command GDB  info registers
    ${r_r}=                         Execute Command  ${cpu} GetRegistersValues

    FOR  ${idx}  IN RANGE  32
        Compare Register                ${cpu}  ${idx}
    END

*** Test Cases ***
Should Change Thread
    [Tags]                          skip_windows
    [Setup]                         Create HiFive Unleashed

    Create Log Tester               0
    Check And Run Gdb               riscv64-zephyr-elf-gdb

    ${x}=                           Command GDB  thread
    Should Contain                  ${x}  Thread 1
    ${x}=                           Command GDB  thread 2
    Should Contain                  ${x}  Thread 2

    # GDB internally changes thread even if it gets E9999 in response
    # to the 'Hg' command so let's make sure there was no failure.
    Should Not Be In Log            GDB 'Hg.' command failed  treatAsRegex=true

Should Step Instruction On Just One Thread
    [Tags]                          skip_windows
    [Setup]                         Create HiFive Unleashed

    Check And Run Gdb               riscv64-zephyr-elf-gdb

    Command GDB                     b *0x00000000802000e8
    Command GDB                     c
    ${threads_before}=              Command GDB  info threads
    Command GDB                     si
    ${threads_after}=               Command GDB  info threads
    ${address_pattern}=             SetVariable  0x[a-f0-9]+

    ${addresses_before}=            Get Regexp Matches  ${threads_before}  ${address_pattern}
    ${addresses_after}=             Get Regexp Matches  ${threads_after}  ${address_pattern}

    Test Number Of Differences      ${addresses_before}  ${addresses_after}  1

Should Step Instruction On All Threads At The Same Time
    [Tags]                          skip_windows
    [Setup]                         Create HiFive Unleashed

    Check And Run Gdb               riscv64-zephyr-elf-gdb

    ${threads_before}=              Command GDB  info threads
    Command GDB                     thread apply all si
    ${threads_after}=               Command GDB  info threads

    ${address_pattern}=             SetVariable  0x[a-f0-9]+

    ${addresses_before}=            Get Regexp Matches  ${threads_before}  ${address_pattern}
    ${addresses_after}=             Get Regexp Matches  ${threads_after}  ${address_pattern}

    Test Number Of Differences      ${addresses_before}  ${addresses_after}  5

Should Change Thread On Breakpoint
    [Tags]                          skip_windows
    [Setup]                         Create HiFive Unleashed

    Check And Run Gdb               riscv64-zephyr-elf-gdb

    # GDB starts o Thread 1 (e51)
    # but this address can be reached only by u54 threads
    Command GDB                     b *0x00000000802000e8
    ${x}=                           Command GDB  c
    Should Not Contain              ${x}  "Thread 1 "

Should Handle One Thread Connected
    [Tags]                          skip_windows
    [Setup]                         Create HiFive Unleashed

    Execute Command                 machine StopGdbServer
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} true sysbus.u54_1

    Check And Run Gdb               riscv64-zephyr-elf-gdb

    Command GDB                     b *0x000000008000029c
    Async Command GDB               c
    Sleep                           5s
    Send Signal To GDB              2
    ${x}=                           Read Async Command Output
    # u54_1 should never hit this address. Only e51 can get there
    ${ptrn}=                        SetVariable  0x[a-f0-9]+
    ${addr}=                        Should Match Regexp  ${x}  ${ptrn}
    Should Be True                  0x000000008000029c < ${addr}

Should Handle Subset Of Threads Connected
    [Tags]                          skip_windows
    [Setup]                         Create HiFive Unleashed

    Execute Command                 machine StopGdbServer
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} true sysbus.u54_1
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} true sysbus.u54_2
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} true sysbus.u54_3
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} true sysbus.u54_4

    Check And Run Gdb               riscv64-zephyr-elf-gdb

    # This address can be reached only by e51 core
    Command GDB                     b *0x000000008000029c
    Async Command GDB               c
    Sleep                           3s
    Send Signal To GDB              2
    ${x}=                           Read Async Command Output
    Should Not Contain              ${x}  "hit Breakpoint"

Should Exit Infinite Loop On Ctrl-C
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # b 0
    Execute Command                 sysbus WriteDoubleWord 0x8 0xeafffffe
    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Async Command GDB               c
    Sleep                           3s
    Send Signal To GDB              2
    ${x}=                           Read Async Command Output
    Should Contain                  ${x}  Program received signal SIGINT
    Should Contain                  ${x}  0x00000008 in ?? ()

    Async Command GDB               c
    Sleep                           3s
    Send Signal To GDB              2
    ${x}=                           Read Async Command Output
    Should Contain                  ${x}  Program received signal SIGINT
    Should Contain                  ${x}  0x00000008 in ?? ()

Should Write And Read Memory
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    ${x}=                           Execute Command  sysbus ReadByte 0x500
    Should Contain                  ${x}  0x00

    ${x}=                           Command GDB  x/1b 0x500
    Should Contain                  ${x}  0x500:\t0

    Command GDB                     set {char}0x500 = 127
    ${x}=                           Command GDB  x/1b 0x500
    Should Contain                  ${x}  0x500:\t127

    ${x}=                           Execute Command  sysbus ReadByte 0x500
    Should Contain                  ${x}  0x7F

    Execute Command                 sysbus WriteByte 0x500 0x37
    ${x}=                           Command GDB  x/1b 0x500
    Should Contain                  ${x}  0x500:\t55

Should Write And Read Peripheral Memory
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    ${timer_address}=               Set Variable  0x10011000
    ${x}=                           Execute Command  sysbus ReadDoubleWord ${timer_address}
    Should Contain                  ${x}  0xFFFFFFFF

    ${x}=                           Command GDB  x/1xw ${timer_address}
    Should Contain                  ${x}  ${timer_address}:\t0xffffffff

    Command GDB                     set {int}${timer_address} = 0xdeadc0de
    ${x}=                           Command GDB  x/1xw ${timer_address}
    Should Contain                  ${x}  ${timer_address}:\t0xdeadc0de

    ${x}=                           Execute Command  sysbus ReadDoubleWord ${timer_address}
    Should Contain                  ${x}  0xDEADC0DE

    Execute Command                 sysbus WriteDoubleWord ${timer_address} 0x12345678
    ${x}=                           Command GDB  x/1xw ${timer_address}
    Should Contain                  ${x}  ${timer_address}:\t0x12345678

Should Stop On Breakpoint
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     b *0x10
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Breakpoint 1, 0x00000010 in ?? ()

Should Step After Breakpoint
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     b *0x10
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Breakpoint 1, 0x00000010 in ?? ()
    ${x}=                           Command GDB  stepi
    Should Contain                  ${x}  0x00000014 in ?? ()

Should Handle Multiple Breakpoints
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     b *0x10
    Command GDB                     b *0x20
    Command GDB                     b *0x30
    Command GDB                     b *0x40

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Breakpoint 1, 0x00000010 in ?? ()

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Breakpoint 2, 0x00000020 in ?? ()

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Breakpoint 3, 0x00000030 in ?? ()

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Breakpoint 4, 0x00000040 in ?? ()

Should Disallow Setting Zero-Sized Watchpoint
    [Tags]                          skip_windows
    [Setup]                         Create VM Demo
    Check And Run Gdb               riscv64-zephyr-elf-gdb

    Command GDB                     file ${VM_DEMO}

    # Flush GDB stderr
    Read Async Command Error
    Read Async Command Error

    Command GDB                     watch *&pagesize
    Command GDB                     continue

    # Discard "Warning:" line
    Read Async Command Error        timeout=10

    ${x}=                           Read Async Command Error  timeout=10
    Should Contain                  ${x}  Could not insert hardware watchpoint 1

Should Stop On Write Watchpoint
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # mov r0, #1
    Execute Command                 sysbus WriteDoubleWord 0x10 0xe3a00001
    # mov r1, #0x00000100
    Execute Command                 sysbus WriteDoubleWord 0x14 0xe3a01c01
    # str r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x18 0xe5810000

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     watch *0x00000100
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware watchpoint 1: *0x00000100
    Should Contain                  ${x}  Old value = 0
    Should Contain                  ${x}  New value = 1
    Should Contain                  ${x}  0x0000001c in ?? ()

Should Stop On Write Watchpoint On Sparc
    [Tags]                          skip_windows
    [Setup]                         Create Leon3
    Check And Run Gdb               sparc-zephyr-elf-gdb

    # sethi  %hi(0x40000000), %g1
    Execute Command                 sysbus WriteDoubleWord 0x00000000 0x03100000
    # or  %g1, 0x104, %g1
    Execute Command                 sysbus WriteDoubleWord 0x00000004 0x82106104
    # sethi  %hi(0x12345400), %g2
    Execute Command                 sysbus WriteDoubleWord 0x00000008 0x05048d15
    # or  %g2, 0x278, %g2
    Execute Command                 sysbus WriteDoubleWord 0x0000000c 0x8410a278
    # st  %g2, [ %g1 ]
    Execute Command                 sysbus WriteDoubleWord 0x00000010 0xc4204000
    # b .
    Execute Command                 sysbus WriteDoubleWord 0x00000014 0x10bfffff
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x00000018 0x01000000

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     watch *0x40000104
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware watchpoint 1: *0x40000104
    Should Contain                  ${x}  Old value = 0
    Should Contain                  ${x}  New value = 305419896
    Should Contain                  ${x}  0x00000010 in ?? ()

Should Stop On Write Watchpoint On Big-Endian PowerPC
    [Tags]                          skip_windows
    [Setup]                         Create MPC5567
    Check And Run Gdb               powerpc-unknown-elf-gdb

    # lis r1, 0x4000
    Execute Command                 sysbus WriteDoubleWord 0x00000000 0x3c204000
    # ori r1, r1, 0x104
    Execute Command                 sysbus WriteDoubleWord 0x00000004 0x60210104
    # lis r2, 0x1234
    Execute Command                 sysbus WriteDoubleWord 0x00000008 0x3c401234
    # ori r2, r2, 0x5678
    Execute Command                 sysbus WriteDoubleWord 0x0000000c 0x60425678
    # stw r2, 0(r1)
    Execute Command                 sysbus WriteDoubleWord 0x00000010 0x90410000
    # b .-4
    Execute Command                 sysbus WriteDoubleWord 0x00000014 0x4bfffffc
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x00000018 0x60000000

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     watch *0x40000104
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware watchpoint 1: *0x40000104
    Should Contain                  ${x}  Old value = 0
    Should Contain                  ${x}  New value = 305419896
    Should Contain                  ${x}  0x00000014 in ?? ()

Should Stop On Write Watchpoint On Little-Endian PowerPC
    [Tags]                          skip_windows
    [Setup]                         Create Microwatt
    Check And Run Gdb               powerpc-unknown-elf-gdb

    # lis r1, 0x4000
    Execute Command                 sysbus WriteDoubleWord 0x00000000 0x3c204000
    # ori r1, r1, 0x104
    Execute Command                 sysbus WriteDoubleWord 0x00000004 0x60210104
    # lis r2, 0x1234
    Execute Command                 sysbus WriteDoubleWord 0x00000008 0x3c401234
    # ori r2, r2, 0x5678
    Execute Command                 sysbus WriteDoubleWord 0x0000000c 0x60425678
    # stw r2, 0(r1)
    Execute Command                 sysbus WriteDoubleWord 0x00000010 0x90410000
    # b .-4
    Execute Command                 sysbus WriteDoubleWord 0x00000014 0x4bfffffc
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x00000018 0x60000000

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     set endian little
    Command GDB                     watch *0x40000104
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware watchpoint 1: *0x40000104
    Should Contain                  ${x}  Old value = 0
    Should Contain                  ${x}  New value = 305419896
    Should Contain                  ${x}  0x0000000000000014 in ?? ()

Should Stop On Peripheral Read Watchpoint
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Test Memory                     0xf0000000  0x0
    Execute Command                 sysbus WriteDoubleWord 0xf0000000 0x147
    Test Memory                     0xf0000000  0x147

    # mov r1, #0xf0000000
    Execute Command                 sysbus WriteDoubleWord 0x10 0xe3a0120f
    # ldr r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x14 0xe5910000

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     rwatch *0xf0000000
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware read watchpoint 1: *0xf0000000
    Should Contain                  ${x}  0x00000018 in ?? ()

    ${val}=                         Execute Command  sysbus ReadDoubleWord 0xf0000000
    Should Be Equal As Numbers      ${val}  0x147

    # let's make sure that handling watchpoint didn't corrupt memory
    Command GDB                     s
    Test Memory                     0xf0000000  0x147
    Command GDB                     s
    Test Memory                     0xf0000000  0x147

Should Stop On Peripheral Write Watchpoint
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Test Memory                     0xf0000000  0x0
    Execute Command                 sysbus WriteDoubleWord 0xf0000000 0x147
    Test Memory                     0xf0000000  0x147

    # mov r0, #1
    Execute Command                 sysbus WriteDoubleWord 0x10 0xe3a00001
    # mov r1, #0xf0000000
    Execute Command                 sysbus WriteDoubleWord 0x14 0xe3a0120f
    # str r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x18 0xe5810000
    # b .
    Execute Command                 sysbus WriteDoubleWord 0x1c 0xEAFFFFFE

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     watch *0xf0000000
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware watchpoint 1: *0xf0000000
    Should Contain                  ${x}  0x0000001c in ?? ()

    # let's make sure that the memory is actually changed
    Test Memory                     0xf0000000  0x1

Should Handle Multiple Write Watchpoints
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # mov r0, #1
    Execute Command                 sysbus WriteDoubleWord 0x10 0xe3a00001
    # mov r1, #0x00000100
    Execute Command                 sysbus WriteDoubleWord 0x14 0xe3a01c01
    # str r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x18 0xe5810000

    # mov r0, #4
    Execute Command                 sysbus WriteDoubleWord 0x1C 0xe3a00004
    # str r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x20 0xe5810000

    # mov r0, #1
    Execute Command                 sysbus WriteDoubleWord 0x24 0xe3a00001
    # mov r1, #0x00000104
    Execute Command                 sysbus WriteDoubleWord 0x28 0xe3a01f41
    # str r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x2C 0xe5810000

    # wfi
    Execute Command                 sysbus WriteDoubleWord 0x30 0xe320f003

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     watch *0x00000100
    Command GDB                     watch *0x00000104

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware watchpoint 1: *0x00000100
    Should Contain                  ${x}  Old value = 0
    Should Contain                  ${x}  New value = 1
    Should Contain                  ${x}  0x0000001c in ?? ()

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware watchpoint 1: *0x00000100
    Should Contain                  ${x}  Old value = 1
    Should Contain                  ${x}  New value = 4
    Should Contain                  ${x}  0x00000024 in ?? ()

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware watchpoint 2: *0x00000104
    Should Contain                  ${x}  Old value = 0
    Should Contain                  ${x}  New value = 1
    Should Contain                  ${x}  0x00000030 in ?? ()

Should Stop On Read Watchpoint
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # mov r1, #0x00000100
    Execute Command                 sysbus WriteDoubleWord 0x10 0xe3a01c01
    # ldr r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x14 0xe5910000

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    ${x}=                           Command GDB  rwatch *0x00000100
    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware read watchpoint 1: *0x00000100
    Should Contain                  ${x}  Value = 0
    Should Contain                  ${x}  0x00000018 in ?? ()

Should Handle Multiple Read Watchpoints
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # mov r1, #0x00000100
    Execute Command                 sysbus WriteDoubleWord 0x10 0xe3a01c01
    # ldr r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x14 0xe5910000
    # mov r0, #1
    Execute Command                 sysbus WriteDoubleWord 0x18 0xe3a00001
    # str r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x1C 0xe5810000
    # ldr r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x20 0xe5910000
    # mov r1, #0x00000104
    Execute Command                 sysbus WriteDoubleWord 0x24 0xe3a01f41
    # ldr r0, [r1]
    Execute Command                 sysbus WriteDoubleWord 0x28 0xe5910000

    Execute Command                 sysbus.cpu MaximumBlockSize 1

    Command GDB                     rwatch *0x00000100
    Command GDB                     rwatch *0x00000104

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware read watchpoint 1: *0x00000100
    Should Contain                  ${x}  Value = 0
    Should Contain                  ${x}  0x00000018 in ?? ()

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware read watchpoint 1: *0x00000100
    Should Contain                  ${x}  Value = 1
    Should Contain                  ${x}  0x00000024 in ?? ()

    ${x}=                           Command GDB  c  timeout=30
    Should Contain                  ${x}  Hardware read watchpoint 2: *0x00000104
    Should Contain                  ${x}  Value = 0
    Should Contain                  ${x}  0x0000002c in ?? ()

Should Correctly Map ARM Registers
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # set registers: 0 -> 0x100, 1 -> 0x101, 2 -> 0x102, ...
    FOR  ${i}  IN RANGE  16
        ${v}=                           Evaluate  0x100 + ${i}
        ${V}=                           Convert To Hex  ${v}
        Test Register By Id             ${i}  r${i}  0x${V}
    END

    # values are chosen by random
    Test Register By Name           PC  pc  0x44
    Test Register By Name           SP  sp  0x56
    Test Register By Name           LR  lr  0x192
    Test Register By Name           CPSR  cpsr  0x1f

Should Handle 64-bit Registers
    [Tags]                          skip_windows
    [Setup]                         Create HiFive Unleashed

    Check And Run Gdb               riscv64-zephyr-elf-gdb

    ${r}=                           Command GDB  p $t0
    Should Contain                  ${r}  $1 = 0
    Command GDB                     set $t0 = 0xda7ada7aa7ada7ad
    ${r}=                           Command GDB  p/x $t0
    Should Contain                  ${r}  $2 = 0xda7ada7aa7ada7ad

Should Step When Paused In Block End Hook
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Execute Command                 sysbus.cpu SetHookAtBlockEnd "self.Pause()"

    ${x}=                           Command GDB  p/x $pc
    Should Contain                  ${x}  0x0
    ${x}=                           Command GDB  si

    ${x}=                           Command GDB  p/x $pc
    Should Contain                  ${x}  0x4
    ${x}=                           Command GDB  si

    ${x}=                           Command GDB  p/x $pc
    Should Contain                  ${x}  0x8
    ${x}=                           Command GDB  si

Should Continue When Paused In Block End Hook
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Execute Command                 sysbus.cpu SetHookAtBlockEnd "self.Pause()"
    Execute Command                 sysbus.cpu MaximumBlockSize 1

    ${x}=                           Command GDB  p/x $pc
    Should Contain                  ${x}  0x0
    ${x}=                           Command GDB  c

    ${x}=                           Command GDB  p/x $pc
    Should Contain                  ${x}  0x4
    ${x}=                           Command GDB  c

    ${x}=                           Command GDB  p/x $pc
    Should Contain                  ${x}  0x8
    ${x}=                           Command GDB  c

Handle Long Command
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Async Command GDB
    ...                             mon echo "this is some very long command that is definitely longer then usually expected when sending commands via gdb remote protocol"

    ${x}=                           Read Async Command Error  timeout=5
    Should Contain                  ${x}  warning: No executable has been specified
    ${x}=                           Read Async Command Error  timeout=5
    Should Contain                  ${x}  Try using the "file" command

    # output from the monitor will be printed on stderr in GDB
    ${x}=                           Read Async Command Error  timeout=5
    Should Contain
    ...                             ${x}
    ...                             this is some very long command that is definitely longer then usually expected when sending commands via gdb remote protocol

Should Dump Memory Across Pages
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    Set Global Variable             ${test_file}  ${TEMPDIR}/memory_test_file.bin
    Set Global Variable             ${dump_file}  ${TEMPDIR}/memory_dump.bin

    Create Test File                0x1800  ${test_file}
    Execute Command                 sysbus LoadBinary @${test_file} 0x80000800
    Command GDB                     dump binary memory ${dump_file} 0x80000800 0x80002000  timeout=1
    ${diff}=                        Run Process  diff  ${dump_file}  ${test_file}
    Should Be Equal As Numbers      ${diff.rc}  0

Should Break In Virtual Addressing
    [Tags]                          skip_windows
    [Setup]                         Create VM Demo

    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Command GDB                     file ${VM_DEMO}

    ${result}=                      Command GDB  break main
    ${result}                       ${expected_pc}=  Should Match Regexp  ${result}  Breakpoint \\d+ at (0x[0-9a-f]{8}):

    Command GDB                     continue  timeout=1

    ${result}=                      Command Gdb  p $pc
    Should Contain                  ${result}  ${expected_pc}

Should Display Proper Instructions In Virtual Addressing
    [Tags]                          skip_windows
    [Setup]                         Create VM Demo

    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Command GDB                     file ${VM_DEMO}

    ${result}=                      Command GDB  x/i main - _vmoffset
    ${result}                       ${instruction}=  Should Match Regexp  ${result}  :\\t(.*)$

    Command GDB                     break main
    Command GDB                     continue  timeout=1

    ${result}=                      Command Gdb  x/i main
    Should Contain                  ${result}  ${instruction}

Should Write To Memory In Virtual Addressing
    [Tags]                          skip_windows
    [Setup]                         Create VM Demo

    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Command GDB                     file ${VM_DEMO}

    Command GDB                     break main
    Command GDB                     continue  timeout=1

    # address ($sp - 0x500) is in virtual memory, it's part of stack space
    ${result}=                      Command GDB  x/x $sp - 0x500
    ${result}                       ${vaddr}  ${vdata_old}=  Should Match Regexp  ${result}  (0x[0-9a-f]{8}):\\t(0x[0-9a-f]{8})
    ${paddr}=                       Execute Command  cpu TranslateAddress ${vaddr} Write

    ${pdata_old}=                   Execute Command  sysbus ReadDoubleWord ${paddr}
    Should Be Equal As Numbers      ${vdata_old}  ${pdata_old}

    # calculate new data so as not to assume the memory state
    ${data_new}=                    Evaluate  hex(${vdata_old} ^ 0x80808080)
    Command GDB                     set *((unsigned*) ${vaddr}) = ${data_new}

    ${result}=                      Command GDB  x/x ${vaddr}
    ${result}                       ${vdata_new}=  Should Match Regexp  ${result}  0x[0-9a-f]{8}:\\t(0x[0-9a-f]{8})
    Should Be Equal As Numbers      ${data_new}  ${vdata_new}
    ${pdata_new}=                   Execute Command  sysbus ReadDoubleWord ${paddr}
    Should Be Equal As Numbers      ${data_new}  ${pdata_new}

Should Step Over Wfi In Debug Mode
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # nop
    Execute Command                 sysbus WriteDoubleWord 0x14 0xe1a00000
    # nop
    Execute Command                 sysbus WriteDoubleWord 0x18 0xe1a00000

    # wfi
    Execute Command                 sysbus WriteDoubleWord 0x10 0xe320f003

    Execute Command                 sysbus.cpu ShouldEnterDebugMode True
    Execute Command                 sysbus.cpu PC 0x10

    Stepi And Check PC              0x00000014
    Stepi And Check PC              0x00000018
    # note that after wfi it always should point to the next instruction address, so we do stepi twice, to see if it proceeds through

Should Wait On Wfi
    [Tags]                          skip_windows
    [Setup]                         Create Versatile Express
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # nop
    Execute Command                 sysbus WriteDoubleWord 0x14 0xe1a00000

    # wfi
    Execute Command                 sysbus WriteDoubleWord 0x10 0xe320f003

    Execute Command                 sysbus.cpu ShouldEnterDebugMode False
    Execute Command                 sysbus.cpu PC 0x10

    Stepi And Check PC              0x00000014
    Stepi And Check PC              0x00000014

Should Ignore External Interrupts In Debug Mode
    [Tags]                          skip_windows
    [Setup]                         Create Versatile
    Create Terminal Tester          sysbus.uart0
    Check And Run Gdb               arm-zephyr-eabi-gdb

    # enable interrupts is ARM cpsr
    # MRS r1, cpsr
    Execute Command                 sysbus WriteDoubleWord 0x110 0xE10F1000
    # BIC r1, r1, #0x80
    Execute Command                 sysbus WriteDoubleWord 0x114 0xE3C11080
    # MSR cpsr, r1
    Execute Command                 sysbus WriteDoubleWord 0x118 0xE121F001

    # wfi
    Execute Command                 sysbus WriteDoubleWord 0x11c 0xe320f003
    Execute Command                 sysbus WriteDoubleWord 0x120 0xe320f003

    # Debug Mode
    Execute Command                 sysbus.cpu ShouldEnterDebugMode True
    Execute Command                 sysbus.cpu PC 0x110
    # enable interrupt handling for line 12
    Execute Command                 sysbus.pic WriteDoubleWord 0x10 0x1000

    # step through interrupt enable instructions
    Stepi And Check PC              0x00000114
    Stepi And Check PC              0x00000118
    Stepi And Check PC              0x0000011c

    # simulate uart0 interrupt
    Execute Command                 sysbus.pic OnGPIO 12 True

    Stepi And Check PC              0x00000120

    # simulate uart0 interrupt
    Execute Command                 sysbus.pic OnGPIO 12 False

    Stepi And Check PC              0x00000124

Should Remember Breakpoint After Reset
    [Tags]                          skip_windows
    [Setup]                         Create VM Demo

    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Command GDB                     file ${VM_DEMO}

    ${result}=                      Command GDB  break main
    ${result}                       ${expected_pc}=  Should Match Regexp  ${result}  Breakpoint \\d+ at (0x[0-9a-f]{8}):

    Execute Command                 machine Reset
    Command GDB                     continue  timeout=1

    ${result}=                      Command Gdb  p $pc
    Should Contain                  ${result}  ${expected_pc}

Should Remember New Breakpoint After Reset
    [Tags]                          skip_windows
    [Setup]                         Create VM Demo

    Check And Run Gdb               riscv64-zephyr-elf-gdb
    Command GDB                     file ${VM_DEMO}

    ${result}=                      Command GDB  break factorial
    ${result}                       ${expected_pc}=  Should Match Regexp  ${result}  Breakpoint \\d+ at (0x[0-9a-f]{8}):

    Command GDB                     continue  timeout=1

    ${result}=                      Command Gdb  p $pc
    Should Contain                  ${result}  ${expected_pc}
    Command GDB                     del 1

    ${result}=                      Command GDB  break main
    ${result}                       ${expected_pc}=  Should Match Regexp  ${result}  Breakpoint \\d+ at (0x[0-9a-f]{8}):

    Execute Command                 machine Reset
    Command GDB                     continue  timeout=1

    ${result}=                      Command Gdb  p $pc
    Should Contain                  ${result}  ${expected_pc}

Registers Should Be Consistent
    [Tags]                          skip_windows
    [Setup]                         Create HiFive Unleashed

    Check And Run Gdb               riscv64-zephyr-elf-gdb

    FOR  ${x}  IN RANGE  100
        Command GDB                     thread 1
        Compare General Registers       sysbus.e51

        Command GDB                     thread 2
        Compare General Registers       sysbus.u54_1

        Command GDB                     thread 3
        Compare General Registers       sysbus.u54_2

        Command GDB                     thread 4
        Compare General Registers       sysbus.u54_3

        Command GDB                     thread 5
        Compare General Registers       sysbus.u54_4

        Command GDB                     step
    END

Should Handle Vector Registers
    [Tags]                          skip_windows
    [Setup]                         Create RISC-V Vectored Machine
    Check And Run Gdb               riscv64-zephyr-elf-gdb

    ${res}=                         Command GDB  info registers v
    Should Contain                  ${res}  v0
    Should Contain                  ${res}  v31

Should Access Vector Elements
    [Tags]                          skip_windows
    [Setup]                         Create RISC-V Vectored Machine
    Check And Run Gdb               riscv64-zephyr-elf-gdb

    ${res}=                         Command GDB  p/x $v0.b[0]
    Should Contain                  ${res}  $1 = 0x0
    Command GDB                     set $v0.b[0] = 0xde
    ${res}=                         Command GDB  p/x $v0.b[0]
    Should Contain                  ${res}  $2 = 0xde

    ${res}=                         Command GDB  p/x $v8.s[31]
    Should Contain                  ${res}  $3 = 0x0
    Command GDB                     set $v8.s[31] = 0xc0de
    ${res}=                         Command GDB  p/x $v8.s[31]
    Should Contain                  ${res}  $4 = 0xc0de

    ${res}=                         Command GDB  p/x $v16.w[15]
    Should Contain                  ${res}  $5 = 0x0
    Command GDB                     set $v16.w[15] = 0xdeadc0de
    ${res}=                         Command GDB  p/x $v16.w[15]
    Should Contain                  ${res}  $6 = 0xdeadc0de

    ${res}=                         Command GDB  p/x $v24.l[5]
    Should Contain                  ${res}  $7 = 0x0
    Command GDB                     set $v24.l[5] = 0xdeadc0dedeadc0de
    ${res}=                         Command GDB  p/x $v24.l[5]
    Should Contain                  ${res}  $8 = 0xdeadc0dedeadc0de

    ${res}=                         Command GDB  p/x $v31.q[3]
    Should Contain                  ${res}  $9 = 0x0
    Command GDB                     set $v31.q[3] = 0xdeadc0dedeadc0de
    ${res}=                         Command GDB  p/x $v31.q[3]
    Should Contain                  ${res}  $10 = 0xffffffffffffffffdeadc0dedeadc0de

Should Access Whole Vector Registers
    [Tags]                          skip_windows
    [Setup]                         Create RISC-V Vectored Machine
    Check And Run Gdb               riscv64-zephyr-elf-gdb

    Command GDB                     set $v0.l[0] = 0xdeadc0dedeadc0de
    Command GDB                     set $v0.l[1] = 0xabcdef0123456789
    Command GDB                     set $v0.l[2] = 0x3333333355555555
    Command GDB                     set $v0.l[7] = 0xffffffffaaaaaaaa
    Command GDB                     set $v31.l[5] = 0xaaaaaaaaffffffff

    Command GDB                     set $v31 = $v0

    ${res}=                         Command GDB  p/x $v31.l[0]
    Should Contain                  ${res}  $1 = 0xdeadc0dedeadc0de
    ${res}=                         Command GDB  p/x $v31.l[1]
    Should Contain                  ${res}  $2 = 0xabcdef0123456789
    ${res}=                         Command GDB  p/x $v31.l[2]
    Should Contain                  ${res}  $3 = 0x3333333355555555
    ${res}=                         Command GDB  p/x $v31.l[7]
    Should Contain                  ${res}  $4 = 0xffffffffaaaaaaaa
    ${res}=                         Command GDB  p/x $v31.l[5]
    Should Contain                  ${res}  $5 = 0x0

Should Read Per Core Memory
    [Setup]                         Create HiFive Unleashed
    Add Per Core Memory Regions
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    # flush GDB stderr
    Read Async Command Error
    Read Async Command Error
    Read Async Command Error

    Execute Command                 sysbus WriteDoubleWord 0x4f00000000 0xdeadc1de sysbus.u54_1
    Execute Command                 sysbus WriteDoubleWord 0x4f00000000 0xdeadc2de sysbus.u54_2

    Execute Command                 machine EnableGdbLogging ${GDB_REMOTE_PORT} true
    Execute Command                 logLevel 0 sysbus.e51

    # e51 should return error as there is no memory allocated under 0x4f00000000 for this thread
    Command GDB                     thread 1
    Async Command GDB               x 0x4f00000000
    ${res}=                         Read Async Command Error
    Should Contain                  ${res}  Cannot access memory at address 0x4f00000000

    Command GDB                     thread 2
    ${res}=                         Command GDB  x 0x4f00000000
    Should Contain                  ${res}  0xdeadc1de

    Command GDB                     thread 3
    ${res}=                         Command GDB  x 0x4f00000000
    Should Contain                  ${res}  0xdeadc2de

Should Write Per Core Memory
    [Setup]                         Create HiFive Unleashed
    Add Per Core Memory Regions
    Check And Run Gdb               riscv64-zephyr-elf-gdb
    # flush GDB stderr
    Read Async Command Error
    Read Async Command Error
    Read Async Command Error

    # e51 should return error as there is no memory allocated under 0x4f00000000 for this thread
    Command GDB                     thread 1
    Async Command GDB               x 0x4f00000000
    ${res}=                         Read Async Command Error
    Should Contain                  ${res}  Cannot access memory at address 0x4f00000000

    Command GDB                     thread 2
    ${res}=                         Command GDB  x 0x4f00000000
    Should Contain                  ${res}  0x0

    Command GDB                     thread 3
    ${res}=                         Command GDB  x 0x4f00000000
    Should Contain                  ${res}  0x0

    Command GDB                     thread 1
    Command GDB                     set {int}0x4f00000000 = 0xdeadc0de
    Command GDB                     thread 2
    Command GDB                     set {int}0x4f00000000 = 0xdeadc1de
    Command GDB                     thread 3
    Command GDB                     set {int}0x4f00000000 = 0xdeadc2de

    Command GDB                     thread 1
    Async Command GDB               x 0x4f00000000
    ${res}=                         Read Async Command Error
    Should Contain                  ${res}  Cannot access memory at address 0x4f00000000

    Command GDB                     thread 2
    ${res}=                         Command GDB  x 0x4f00000000
    Should Contain                  ${res}  0xdeadc1de

    Command GDB                     thread 3
    ${res}=                         Command GDB  x 0x4f00000000
    Should Contain                  ${res}  0xdeadc2de

# Some commands send packets with mnemonic followed by an address in hex format with no space in between, which makes parsing tricky.

Commands Should Work Properly With High Addresses
    [Setup]                         Create Versatile

    Execute Command
    ...                             machine LoadPlatformDescriptionFromString "test_mem: Memory.MappedMemory @ sysbus 0xf0000000 { size: 0x1000 }"
    Check and Run Gdb               arm-zephyr-eabi-gdb
    Command GDB                     set *((long *)0xf0000000) = 0xdead2bad
    ${readvalue}=                   Command GDB  x 0xf0000000
    Should Contain                  ${readvalue}  0xdead2bad

Should Not Pause Machine Upon Python Peripheral Access
    [Setup]                         Create Machine With PythonPeripheral
    Check and Run Gdb               arm-zephyr-eabi-gdb

    # Set a breakpoint after a python peripheral access
    # Will not trigger if an spurious event pauses the machine, instead the GDB will stop with SIGTRAP
    Command GDB                     b *0x800000a
    Async Command GDB               c
    Sleep                           5s
    ${x}=                           Read Async Command Output
    Should Not Contain              ${x}  SIGTRAP
    Should Contain                  ${x}  Breakpoint 1, 0x0800000a in ?? ()

## Regression tests for simple CPU clustering for GDB stub

Clustering Should Fail On CPUs With Different Archs
    Execute Command                 i @platforms/cpus/zynqmp.repl

    Run Keyword And Expect Error    *CPUs of different architectures are present in this platform*
    ...                             Execute Command  machine StartGdbServer ${GDB_REMOTE_PORT}

Clustering Should Load Arch Cluster
    Execute Command                 i @platforms/cpus/zynqmp.repl

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} cpuCluster="cortex-r5f"
    Check and Run Gdb               aarch64-zephyr-elf-gdb
    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1 "machine-0.rpu0"
    Should Contain                  ${x}  Thread 2 "machine-0.rpu1"

Clustering Should Load Arch Cluster And Then Another Cluster
    Execute Command                 i @platforms/cpus/zynqmp.repl

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} false cpuCluster="cortex-r5f"
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} false cpuCluster="cortex-a53"
    Check and Run Gdb               aarch64-zephyr-elf-gdb
    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1 "machine-0.rpu0"
    Should Contain                  ${x}  Thread 2 "machine-0.rpu1"
    Should Contain                  ${x}  Thread 3 "machine-0.apu0"
    Should Contain                  ${x}  Thread 4 "machine-0.apu1"
    Should Contain                  ${x}  Thread 5 "machine-0.apu2"
    Should Contain                  ${x}  Thread 6 "machine-0.apu3"

Clustering Should Load Arch Cluster And Then CPU
    Execute Command                 i @platforms/cpus/zynqmp.repl

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} false cpuCluster="cortex-r5f"
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} false cpu=sysbus.cluster0.apu2
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} false cpu=sysbus.cluster0.apu0
    Check and Run Gdb               aarch64-zephyr-elf-gdb
    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1 "machine-0.rpu0"
    Should Contain                  ${x}  Thread 2 "machine-0.rpu1"
    Should Contain                  ${x}  Thread 3 "machine-0.apu2"
    Should Contain                  ${x}  Thread 4 "machine-0.apu0"

Clustering Should Load CPU And Then Another CPU
    Execute Command                 i @platforms/cpus/zynqmp.repl

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} false cpu=sysbus.cluster0.apu2
    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} false cpu=sysbus.cluster1.rpu0
    Check and Run Gdb               aarch64-zephyr-elf-gdb
    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1 "machine-0.apu2"
    Should Contain                  ${x}  Thread 2 "machine-0.rpu0"

Clustering Should Load All Cpus By Force
    Execute Command                 i @platforms/cpus/zynqmp.repl

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT} cpuCluster="all"
    Check and Run Gdb               aarch64-zephyr-elf-gdb
    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1 "machine-0.apu0"
    Should Contain                  ${x}  Thread 2 "machine-0.apu1"
    Should Contain                  ${x}  Thread 3 "machine-0.apu2"
    Should Contain                  ${x}  Thread 4 "machine-0.apu3"
    Should Contain                  ${x}  Thread 5 "machine-0.rpu0"
    Should Contain                  ${x}  Thread 6 "machine-0.rpu1"

Clustering Should Load All Cpus If Only One Arch
    Execute Command                 i @platforms/cpus/cortex-r52_smp_4.repl

    Execute Command                 machine StartGdbServer ${GDB_REMOTE_PORT}
    Check and Run Gdb               aarch64-zephyr-elf-gdb
    ${x}=                           Command GDB  info threads
    Should Contain                  ${x}  Thread 1 "machine-0.cpu"
    Should Contain                  ${x}  Thread 2 "machine-0.cpu1"
    Should Contain                  ${x}  Thread 3 "machine-0.cpu2"
    Should Contain                  ${x}  Thread 4 "machine-0.cpu3"

##
