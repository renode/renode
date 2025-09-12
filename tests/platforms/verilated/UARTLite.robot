*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN}                              uartlite--custom_uart_demo--zephyr.elf-s_184340-129eb92404f437a466cd8700f6743b1c5b0da912
${UARTLITE_NATIVE_LINUX}            ${URI}/libVuartlite-Linux-x86_64-12904733885.so-s_2087832-2d689c6c42723282e927d1b21140476d001b9db9
${UARTLITE_NATIVE_WINDOWS}          ${URI}/libVuartlite-Windows-x86_64-12904733885.dll-s_3250805-26fbac48b0f6e366e6d2efd53bcafe899cfe3bed
${UARTLITE_NATIVE_MACOS}            ${URI}/libVuartlite-macOS-x86_64-12904733885.dylib-s_222512-aa60e4266c82f43805fc2bd4c023daa3f666fdf0
${UARTLITE_SOCKET_LINUX}            ${URI}/Vuartlite-Linux-x86_64-12904733885-s_1634440-1fca77dcce5b8d477afe39d588e2b15d58408faf
${UARTLITE_SOCKET_WINDOWS}          ${URI}/Vuartlite-Windows-x86_64-12904733885.exe-s_3244916-368deeb3e38ff16907f89f71142a26c245f6ee41
${UARTLITE_SOCKET_MACOS}            ${URI}/Vuartlite-macOS-x86_64-12904733885-s_222576-005efcfa289330c23a3eb67058ef1d204d901f63
${UARTLITE_WRONG_PORTS_LINUX}       ${URI}/Vuartlite_wrong_ports-Linux-x86_64-12904733885-s_1634440-4fbae470afd67def8c5561afcd3981155b34bebf
${UARTLITE_WRONG_PORTS_WINDOWS}     ${URI}/Vuartlite_wrong_ports-Windows-x86_64-12904733885.exe-s_3244916-911bee45eb4e21227ccd1c2581f5d77ae96eaf56
${UARTLITE_WRONG_PORTS_MACOS}       ${URI}/Vuartlite_wrong_ports-macOS-x86_64-12904733885-s_222576-7f0a02b68b87328b836291dd3afb21c6fa17d3e1
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_LINUX}  ${URI}/Vuartlite_sleep_after_1000_iters-Linux-x86_64-12904733885-s_1634488-1f4f250dd973f0f5e67c4b2e222856acdf011781
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_WINDOWS}  ${URI}/Vuartlite_sleep_after_1000_iters-Windows-x86_64-12904733885.exe-s_3245968-4d0307f72d0293defa20516ad60517a307421d25
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_MACOS}  ${URI}/Vuartlite_sleep_after_1000_iters-macOS-x86_64-12904733885-s_222616-590a3b5a44836bb8a6e7b27d53e677ce7f406fd0
${UARTLITE_WRONG_SECOND_PORT_LINUX}  ${URI}/Vuartlite_wrong_second_port-Linux-x86_64-12904733885-s_1634440-9555b3643f1399aac5278c72404b97dbea14e250
${UARTLITE_WRONG_SECOND_PORT_WINDOWS}  ${URI}/Vuartlite_wrong_second_port-Windows-x86_64-12904733885.exe-s_3244916-c2d450fff739bbb6ba43d56a42f1f444733a9dc6
${UARTLITE_WRONG_SECOND_PORT_MACOS}  ${URI}/Vuartlite_wrong_second_port-macOS-x86_64-12904733885-s_222576-fa829c3e617c9506c178ef4d2c5388b1cd9fc2d1
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
    Run Keyword And Expect Error    *Error starting cosimulated peripheral!*    Create Machine With Socket Based Communication  @nonexistent-uart-binary  @nonexistent-uart-binary  @nonexistent-uart-binary
