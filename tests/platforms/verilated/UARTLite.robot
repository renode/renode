*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN}                              uartlite--custom_uart_demo--zephyr.elf-s_184340-129eb92404f437a466cd8700f6743b1c5b0da912
${UARTLITE_NATIVE_LINUX}            ${URI}/libVuartlite-Linux-x86_64-6585534489.so-s_2065712-ad517d8e2b23842752ef0312a4ef91f84d760c29
${UARTLITE_SOCKET_LINUX}            ${URI}/Vuartlite-Linux-x86_64-6585534489-s_1615536-258c6921413c4d0231a86b30779e38ebd485e44d
${UARTLITE_NATIVE_WINDOWS}          ${URI}/libVuartlite-Windows-x86_64-6585534489.dll-s_3120162-a9f05d5b5c8c4a28dbb5a7dea4cb568287c2cf5a
${UARTLITE_SOCKET_WINDOWS}          ${URI}/Vuartlite-Windows-x86_64-6585534489.exe-s_3111169-de391155b540aa0f35986c1bf98c3504b8e87ee5
${UARTLITE_NATIVE_MACOS}            ${URI}/libVuartlite-macOS-x86_64-6585534489.dylib-s_216728-0ac50938c9b43c97f133372ffe3842a28a047dcb
${UARTLITE_SOCKET_MACOS}            ${URI}/Vuartlite-macOS-x86_64-6585534489-s_217568-53c098deb3bb84f0fc614448f514754a2069fd67
${UARTLITE_WRONG_PORTS_LINUX}       ${URI}/Vuartlite_wrong_ports-Linux-x86_64-6585534489-s_1615536-b31bc852d5c35f75a7b26fa04da2d5cb657275e7
${UARTLITE_WRONG_PORTS_WINDOWS}     ${URI}/Vuartlite_wrong_ports-Windows-x86_64-6585534489.exe-s_3111169-54324bde16d2d6d59f77509fc8dac9d402489e65
${UARTLITE_WRONG_PORTS_MACOS}       ${URI}/Vuartlite_wrong_ports-macOS-x86_64-6585534489-s_217568-5e35e2180a043dc077490ff1c702b64e124c6314
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_LINUX}  ${URI}/Vuartlite_sleep_after_1000_iters-Linux-x86_64-6585534489-s_1615576-5650af9b947560e121f07a62ca50bd8b1ce68a05
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_WINDOWS}  ${URI}/Vuartlite_sleep_after_1000_iters-Windows-x86_64-6585534489.exe-s_3114269-bfcb0661daa31b57c77ed3674fdee980acf487d6
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_MACOS}  ${URI}/Vuartlite_sleep_after_1000_iters-macOS-x86_64-6585534489-s_217608-f620f1032858cfd72a2886886e5844c3fcd623ea
${UARTLITE_WRONG_SECOND_PORT_LINUX}  ${URI}/Vuartlite_wrong_second_port-Linux-x86_64-6585534489-s_1615536-572eff3c2886bd192a47a86969210362f3f97e04
${UARTLITE_WRONG_SECOND_PORT_WINDOWS}  ${URI}/Vuartlite_wrong_second_port-Windows-x86_64-6585534489.exe-s_3111169-87d77ac7a42ff87038f1abaf74519b1b9db15638
${UARTLITE_WRONG_SECOND_PORT_MACOS}  ${URI}/Vuartlite_wrong_second_port-macOS-x86_64-6585534489-s_217568-db79061d6a865807f5bb569fa9879384e2d717f4
${LOCAL_FILENAME}                   uartlite
${UART}                             sysbus.uart
${UARTLITE_SCRIPT}                  scripts/single-node/riscv_verilated_uartlite.resc
${LOG_TIMEOUT}                      1  # virtual seconds

# same as riscv_verilated_uartlite.repl, but adds address for uart
${PLATFORM}=     SEPARATOR=
...  """                                                                        ${\n}
...  cpu: CPU.RiscV32 @ sysbus                                                  ${\n}
...  ${SPACE*4}cpuType: "rv32g"                                                 ${\n}
...  ${SPACE*4}privilegeArchitecture: PrivilegeArchitecture.Priv1_09            ${\n}
...  ${SPACE*4}timeProvider: clint                                              ${\n}
...                                                                             ${\n}
...  plic: IRQControllers.PlatformLevelInterruptController @ sysbus 0x40000000  ${\n}
...  ${SPACE*4}0 -> cpu@11                                                      ${\n}
...  ${SPACE*4}numberOfSources: 31                                              ${\n}
...  ${SPACE*4}numberOfContexts: 1                                              ${\n}
...  ${SPACE*4}prioritiesEnabled : false                                        ${\n}
...                                                                             ${\n}
...  clint: IRQControllers.CoreLevelInterruptor  @ sysbus 0x44000000            ${\n}
...  ${SPACE*4}frequency: 66000000                                              ${\n}
...  ${SPACE*4}\[0, 1\] -> cpu@\[3, 7\]                                         ${\n}
...                                                                             ${\n}
...  ram: Memory.MappedMemory @ sysbus 0x60000000                               ${\n}
...  ${SPACE*4}size: 0x06400000                                                 ${\n}
...                                                                             ${\n}
...  uart: Verilated.VerilatedUART @ sysbus <0x70000000, +0x100>                ${\n}
...  ${SPACE*4}frequency: 100000000                                             ${\n}
...  ${SPACE*4}address: "127.0.0.1"                                             ${\n}
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
    Run Keyword And Expect Error    *Error starting verilated peripheral!*    Execute Script  ${UARTLITE_SCRIPT}


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
    Run Keyword And Expect Error    *Connection to the verilated peripheral failed!*    Create Machine With Socket Based Communication  ${uartLinux}  ${uartWindows}  ${uartMacOS}

# Wrong "second" port when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Partly Connecting
    Set Test Variable               ${uartLinux}    ${UARTLITE_WRONG_SECOND_PORT_LINUX}
    Set Test Variable               ${uartWindows}  ${UARTLITE_WRONG_SECOND_PORT_WINDOWS}
    Set Test Variable               ${uartMacOS}    ${UARTLITE_WRONG_SECOND_PORT_MACOS}
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the verilated peripheral failed!*    Create Machine With Socket Based Communication  ${uartLinux}  ${uartWindows}  ${uartMacOS}

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
    Run Keyword And Expect Error    *Error starting verilated peripheral!*    Create Machine With Socket Based Communication  nonexistent-uart-binary  nonexistent-uart-binary  nonexistent-uart-binary
