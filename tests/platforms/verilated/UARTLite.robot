*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN}                              uartlite--custom_uart_demo--zephyr.elf-s_184340-129eb92404f437a466cd8700f6743b1c5b0da912
${UARTLITE_NATIVE_LINUX}            ${URI}/libVuartlite-Linux-x86_64-12746432362.so-s_2065720-1c7a212b50fdb10a90b5be713b106a49d3d81c2e
${UARTLITE_NATIVE_WINDOWS}          ${URI}/libVuartlite-Windows-x86_64-12746432362.dll-s_3233193-267d2ef5f2f89c78bbe931d861b530c5bb461ab6
${UARTLITE_NATIVE_MACOS}            ${URI}/libVuartlite-macOS-x86_64-12746432362.dylib-s_219096-1d5ef6dee55d7c7068de26a134b347ffbcd2fd5f
${UARTLITE_SOCKET_LINUX}            ${URI}/Vuartlite-Linux-x86_64-12746432362-s_1615544-80ed7f1f2e199e126edab922ff60ce9dfdea7542
${UARTLITE_SOCKET_WINDOWS}          ${URI}/Vuartlite-Windows-x86_64-12746432362.exe-s_3229352-2a74383782f0e3ab98ada9fa86d69d3ca3547b21
${UARTLITE_SOCKET_MACOS}            ${URI}/Vuartlite-macOS-x86_64-12746432362-s_219160-846dd871bc9acf4b8d9dc7ab620d564db0dde997
${UARTLITE_WRONG_PORTS_LINUX}       ${URI}/Vuartlite_wrong_ports-Linux-x86_64-12746432362-s_1615544-9ccf2c91496ab15625ff4041627b277155ca3622
${UARTLITE_WRONG_PORTS_WINDOWS}     ${URI}/Vuartlite_wrong_ports-Windows-x86_64-12746432362.exe-s_3229352-fd4b60679d126fcc2e7012f5b901a67a60625b5b
${UARTLITE_WRONG_PORTS_MACOS}       ${URI}/Vuartlite_wrong_ports-macOS-x86_64-12746432362-s_219160-d2959692c91a01c30e1b91b2b8d494117dbd91f4
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_LINUX}  ${URI}/Vuartlite_sleep_after_1000_iters-Linux-x86_64-12746432362-s_1615592-25efbdf580d989c6758a6355c1f9d373370a9e98
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_WINDOWS}  ${URI}/Vuartlite_sleep_after_1000_iters-Windows-x86_64-12746432362.exe-s_3230404-2b4e36be6145700d9ae1bbd909a640ec3bfd9e21
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_MACOS}  ${URI}/Vuartlite_sleep_after_1000_iters-macOS-x86_64-12746432362-s_219200-ae789951fedfa78e67a0cd334abae7a3cda3cadf
${UARTLITE_WRONG_SECOND_PORT_LINUX}  ${URI}/Vuartlite_wrong_second_port-Linux-x86_64-12746432362-s_1615544-61f1fba591613c62689cbac0aa7644926467f821
${UARTLITE_WRONG_SECOND_PORT_WINDOWS}  ${URI}/Vuartlite_wrong_second_port-Windows-x86_64-12746432362.exe-s_3229352-ed2ce28c1a43357b63da1b5a98ee9c1a61cefbf7
${UARTLITE_WRONG_SECOND_PORT_MACOS}  ${URI}/Vuartlite_wrong_second_port-macOS-x86_64-12746432362-s_219160-01cb460ddd062fdc0f52e698e70220cbf6bc5f44
${LOCAL_FILENAME}                   uartlite
${UART}                             sysbus.uart
${UARTLITE_SCRIPT}                  scripts/single-node/riscv_verilated_uartlite.resc
${LOG_TIMEOUT}                      1  # virtual seconds

# same as riscv_verilated_uartlite.repl, but adds address for uart
${PLATFORM}=     SEPARATOR=${\n}
...  """
...  cpu: CPU.RiscV32 @ sysbus
...  ${SPACE*4}cpuType: "rv32g"
...  ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.Priv1_09
...  ${SPACE*4}timeProvider: clint
...
...  plic: IRQControllers.PlatformLevelInterruptController @ sysbus 0x40000000
...  ${SPACE*4}0 -> cpu@11
...  ${SPACE*4}numberOfSources: 31
...  ${SPACE*4}numberOfContexts: 1
...  ${SPACE*4}prioritiesEnabled : false
...
...  clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000
...  ${SPACE*4}frequency: 66000000
...  ${SPACE*4}\[0, 1\] -> cpu@\[3, 7\]
...
...  ram: Memory.MappedMemory @ sysbus 0x60000000
...  ${SPACE*4}size: 0x06400000
...
...  uart: CoSimulated.CoSimulatedUART @ sysbus <0x70000000, +0x100>
...  ${SPACE*4}frequency: 100000000
...  ${SPACE*4}address: "127.0.0.1"
...  """

*** Keywords ***
Create Machine With Socket Based Communication
    [Arguments]         ${vuartlite_linux}      ${vuartlite_windows}    ${vuartlite_macos}
    Execute Command                             using sysbus
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                             sysbus LoadELF ${URI}/${BIN}
    Execute Command                             cpu PC `sysbus GetSymbolAddress "vinit"`
    Execute Command                             uart SimulationFilePathLinux ${vuartlite_linux}
    Execute Command                             uart SimulationFilePathWindows ${vuartlite_windows}
    Execute Command                             uart SimulationFilePathMacOS ${vuartlite_macos}

*** Test Cases ***
Should Run UARTLite Binary From Script
    [Tags]                          skip_osx  skip_host_arm

    Execute Command                 \$uartLinux?=${UARTLITE_NATIVE_LINUX}
    Execute Command                 \$uartWindows?=${UARTLITE_NATIVE_WINDOWS}
    Execute Script                  ${UARTLITE_SCRIPT}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 10

# Starting emulation without SimulationFilePath(Linux|MacOS|Windows) set
Should Handle Empty UARTLite Binary
    [Tags]                          skip_host_arm
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/verilated/riscv_verilated_uartlite.repl
    Execute Command                 showAnalyzer sysbus.uart
    Execute Command                 sysbus LoadELF ${URI}/${BIN}
    Execute Command                 sysbus.cpu PC `sysbus GetSymbolAddress "vinit"`
    Wait For Log Entry              Set SimulationFilePath or connect to a simulator first!

# File Doesn't Exist
Should Handle Nonexistent UARTLite Binary
    [Tags]                          skip_osx  skip_host_arm

    Execute Command                 $uartLinux = @nonexistent-uart-binary
    Execute Command                 $uartWindows = @nonexistent-uart-binary
    Execute Command                 $uartMacOS = @nonexistent-uart-binary
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Error starting cosimulated peripheral!*    Execute Script  ${UARTLITE_SCRIPT}


# Following tests use socket based communication

Should Run UARTLite Binary Using Socket
    [Tags]                          skip_host_arm
    Create Machine With Socket Based Communication  ${UARTLITE_SOCKET_LINUX}  ${UARTLITE_SOCKET_WINDOWS}  ${UARTLITE_SOCKET_MACOS}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 10

# Sleep after 1000 iterations in "simulate" loop (renode.cpp)
Should Handle Connection Timeout
    [Tags]                          skip_host_arm
    Set Test Variable               ${uartLinux}    ${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_LINUX}
    Set Test Variable               ${uartWindows}  ${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_WINDOWS}
    Set Test Variable               ${uartMacOS}    ${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_MACOS}
    Create Machine With Socket Based Communication  ${uartLinux}    ${uartWindows}      ${uartMacOS}
    Create Log Tester               ${LOG_TIMEOUT}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 9
    Wait For Log Entry              Receive error!

# Both ports wrong when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Not Connecting
    [Tags]                          skip_host_arm
    Set Test Variable               ${uartLinux}    ${UARTLITE_WRONG_PORTS_LINUX}
    Set Test Variable               ${uartWindows}  ${UARTLITE_WRONG_PORTS_WINDOWS}
    Set Test Variable               ${uartMacOS}    ${UARTLITE_WRONG_PORTS_MACOS}
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the cosimulated peripheral failed!*    Create Machine With Socket Based Communication  ${uartLinux}  ${uartWindows}  ${uartMacOS}

# Wrong "second" port when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Partly Connecting
    [Tags]                          skip_host_arm
    Set Test Variable               ${uartLinux}    ${UARTLITE_WRONG_SECOND_PORT_LINUX}
    Set Test Variable               ${uartWindows}  ${UARTLITE_WRONG_SECOND_PORT_WINDOWS}
    Set Test Variable               ${uartMacOS}    ${UARTLITE_WRONG_SECOND_PORT_MACOS}
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the cosimulated peripheral failed!*    Create Machine With Socket Based Communication  ${uartLinux}  ${uartWindows}  ${uartMacOS}

# Starting emulation without SimulationFilePath(Linux|MacOS|Windows) set
Should Handle Empty UARTLite Binary With Socket Based Communication
    [Tags]                          skip_host_arm
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus LoadELF ${URI}/${BIN}
    Execute Command                 sysbus.cpu PC `sysbus GetSymbolAddress "vinit"`
    Wait For Log Entry              Set SimulationFilePath or connect to a simulator first!

# File Doesn't Exist
Should Handle Nonexistent UARTLite Binary With Socket Based Communication
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Error starting cosimulated peripheral!*    Create Machine With Socket Based Communication  nonexistent-uart-binary  nonexistent-uart-binary  nonexistent-uart-binary
