*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN}                              uartlite--custom_uart_demo--zephyr.elf-s_184340-129eb92404f437a466cd8700f6743b1c5b0da912
${UARTLITE_NATIVE_LINUX}            ${URI}/libVuartlite-Linux-x86_64-10267006380.so-s_2065720-519be7e5b796e7ad99629abc9d36e3f18dc08bc2
${UARTLITE_NATIVE_WINDOWS}          ${URI}/libVuartlite-Windows-x86_64-10267006380.dll-s_3224855-04c9e308827496aa54bf94cec7de76847ce99dad
${UARTLITE_NATIVE_MACOS}            ${URI}/libVuartlite-macOS-x86_64-10267006380.dylib-s_219096-a968243c6217cb48a72cd52cbe4d9f23dee95330
${UARTLITE_SOCKET_LINUX}            ${URI}/Vuartlite-Linux-x86_64-10267006380-s_1611448-773401854ebf17fe5a1456ad242b44d5b05e8ef9
${UARTLITE_SOCKET_WINDOWS}          ${URI}/Vuartlite-Windows-x86_64-10267006380.exe-s_3218934-20e04697fe8694d9f222892ade32c0bd857db961
${UARTLITE_SOCKET_MACOS}            ${URI}/Vuartlite-macOS-x86_64-10267006380-s_219160-0a03475b50f7e39d4b4ca3f456a2362c006ccc42
${UARTLITE_WRONG_PORTS_LINUX}       ${URI}/Vuartlite_wrong_ports-Linux-x86_64-10267006380-s_1611448-70386cf4fcc1e2535df5de2073fa3483f286fa64
${UARTLITE_WRONG_PORTS_WINDOWS}     ${URI}/Vuartlite_wrong_ports-Windows-x86_64-10267006380.exe-s_3218934-b3dc7da7b518b32922223a2630238f07d1f6759c
${UARTLITE_WRONG_PORTS_MACOS}       ${URI}/Vuartlite_wrong_ports-macOS-x86_64-10267006380-s_219160-854895976f3ea698445012adc661e12ca3a3afa0
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_LINUX}  ${URI}/Vuartlite_sleep_after_1000_iters-Linux-x86_64-10267006380-s_1611496-5901069b76bbf601c4f3426aa7027db964d0bf2b
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_WINDOWS}  ${URI}/Vuartlite_sleep_after_1000_iters-Windows-x86_64-10267006380.exe-s_3220498-88b24e18253a249e7f9f0001be45a02fbfce0c62
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_MACOS}  ${URI}/Vuartlite_sleep_after_1000_iters-macOS-x86_64-10267006380-s_219200-6f9b70c690bc6843b8df42c3d3fe9e42ad2e9665
${UARTLITE_WRONG_SECOND_PORT_LINUX}  ${URI}/Vuartlite_wrong_second_port-Linux-x86_64-10267006380-s_1611448-301b9c67d20c74d0f6cd3ec4af25e4168ccb557f
${UARTLITE_WRONG_SECOND_PORT_WINDOWS}  ${URI}/Vuartlite_wrong_second_port-Windows-x86_64-10267006380.exe-s_3218934-446c26d911e4516a94e5a0589ee8c77d339e536b
${UARTLITE_WRONG_SECOND_PORT_MACOS}  ${URI}/Vuartlite_wrong_second_port-macOS-x86_64-10267006380-s_219160-4a547ecf1daf2317fe4fb2f4b553137b787d7ab9
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
    [Tags]                          skip_osx

    Execute Command                 \$uartLinux?=${UARTLITE_NATIVE_LINUX}
    Execute Command                 \$uartWindows?=${UARTLITE_NATIVE_WINDOWS}
    Execute Script                  ${UARTLITE_SCRIPT}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 10

# Starting emulation without SimulationFilePath(Linux|MacOS|Windows) set
Should Handle Empty UARTLite Binary
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/verilated/riscv_verilated_uartlite.repl
    Execute Command                 showAnalyzer sysbus.uart
    Execute Command                 sysbus LoadELF ${URI}/${BIN}
    Execute Command                 sysbus.cpu PC `sysbus GetSymbolAddress "vinit"`
    Run Keyword And Expect Error    *Cannot start emulation. Set SimulationFilePath or connect to a simulator first!*    Start Emulation

# File Doesn't Exist
Should Handle Nonexistent UARTLite Binary
    [Tags]                          skip_osx

    Execute Command                 $uartLinux = @nonexistent-uart-binary
    Execute Command                 $uartWindows = @nonexistent-uart-binary
    Execute Command                 $uartMacOS = @nonexistent-uart-binary
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Error starting cosimulated peripheral!*    Execute Script  ${UARTLITE_SCRIPT}


# Following tests use socket based communication

Should Run UARTLite Binary Using Socket
    Create Machine With Socket Based Communication  ${UARTLITE_SOCKET_LINUX}  ${UARTLITE_SOCKET_WINDOWS}  ${UARTLITE_SOCKET_MACOS}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 10

# Sleep after 1000 iterations in "simulate" loop (renode.cpp)
Should Handle Connection Timeout
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
    Set Test Variable               ${uartLinux}    ${UARTLITE_WRONG_PORTS_LINUX}
    Set Test Variable               ${uartWindows}  ${UARTLITE_WRONG_PORTS_WINDOWS}
    Set Test Variable               ${uartMacOS}    ${UARTLITE_WRONG_PORTS_MACOS}
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the cosimulated peripheral failed!*    Create Machine With Socket Based Communication  ${uartLinux}  ${uartWindows}  ${uartMacOS}

# Wrong "second" port when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Partly Connecting
    Set Test Variable               ${uartLinux}    ${UARTLITE_WRONG_SECOND_PORT_LINUX}
    Set Test Variable               ${uartWindows}  ${UARTLITE_WRONG_SECOND_PORT_WINDOWS}
    Set Test Variable               ${uartMacOS}    ${UARTLITE_WRONG_SECOND_PORT_MACOS}
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the cosimulated peripheral failed!*    Create Machine With Socket Based Communication  ${uartLinux}  ${uartWindows}  ${uartMacOS}

# Starting emulation without SimulationFilePath(Linux|MacOS|Windows) set
Should Handle Empty UARTLite Binary With Socket Based Communication
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus LoadELF ${URI}/${BIN}
    Execute Command                 sysbus.cpu PC `sysbus GetSymbolAddress "vinit"`
    Run Keyword And Expect Error    *Cannot start emulation. Set SimulationFilePath or connect to a simulator first!*    Start Emulation

# File Doesn't Exist
Should Handle Nonexistent UARTLite Binary With Socket Based Communication
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Error starting cosimulated peripheral!*    Create Machine With Socket Based Communication  nonexistent-uart-binary  nonexistent-uart-binary  nonexistent-uart-binary
