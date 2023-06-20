*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN}                              uartlite--custom_uart_demo--zephyr.elf-s_184340-129eb92404f437a466cd8700f6743b1c5b0da912
${UARTLITE_NATIVE_LINUX}            ${URI}/Vuartlite-Linux-x86_64-1116123840-s_1599680-83f742bb0978fd3b9baf62e0374f155a739d51bd
${UARTLITE_SOCKET_LINUX}            ???
${UARTLITE_NATIVE_WINDOWS}          ${URI}/Vuartlite-Windows-x86_64-1116123840.exe-s_14818278-68fb417a3d93d490c2e123530e6554e4f424303a
${UARTLITE_SOCKET_WINDOWS}          ???
${UARTLITE_NATIVE_MACOS}            ${URI}/Vuartlite-macOS-x86_64-1116123840-s_213728-7c628488f7e7a6f2dcf191f205d64faca8840d3d
${UARTLITE_SOCKET_MACOS}            ???
${UARTLITE_WRONG_PORTS_LINUX}       ${URI}/Vwrong-ports-Linux-x86_64-1116123840-s_1599680-0469cc78da4e7c471b0b2aa8b5043ae067cddc38
${UARTLITE_WRONG_PORTS_WINDOWS}     ${URI}/Vwrong-ports-Windows-x86_64-1116123840.exe-s_14818278-8eef4d621983ba0488432b211531b986919d07b5
${UARTLITE_WRONG_PORTS_MACOS}       ${URI}/Vwrong-ports-macOS-x86_64-1116123840-s_213728-86dca75acae23752583ae12a28bede927eba1434
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_LINUX}  ???
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_WINDOWS}  ???
${UARTLITE_SLEEP_AFTER_1000_ITERS_SOCKET_MACOS}  ???
${UARTLITE_WRONG_SECOND_PORT_LINUX}  ${URI}/Vwrong-second-port-Linux-x86_64-1116123840-s_1599680-2641eb4ae0d6a5b3ef09ad1d4b0e8c3797c08d47
${UARTLITE_WRONG_SECOND_PORT_WINDOWS}  ${URI}/Vwrong-second-port-Windows-x86_64-1116123840.exe-s_14818278-e2c4f51c6e0a0ffafbb8ad36e03b5afca4566f12
${UARTLITE_WRONG_SECOND_PORT_MACOS}  ${URI}/Vwrong-second-port-macOS-x86_64-1116123840-s_213728-4c921bbdb3fabf4f3b7a74848f92adf8e56bc225
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
Create Machine With Native Based Communication
    [Arguments]         ${vuartlite_linux}      ${vuartlite_windows}    ${vuartlite_macos}
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/verilated/riscv_verilated_uartlite.repl
    Execute Command                 sysbus LoadELF ${URI}/${BIN}
    Execute Command                 cpu PC `sysbus GetSymbolAddress "vinit"`
    Execute Command                 uart SimulationFilePathLinux ${vuartlite_linux}
    Execute Command                 uart SimulationFilePathWindows ${vuartlite_windows}
    Execute Command                 uart SimulationFilePathMacOS ${vuartlite_macos}

Create Machine With Socket Based Communication
    [Arguments]         ${vuartlite_linux}      ${vuartlite_windows}    ${vuartlite_macos}
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus LoadELF ${URI}/${BIN}
    Execute Command                 cpu PC `sysbus GetSymbolAddress "vinit"`
    Execute Command                 uart SimulationFilePathLinux ${vuartlite_linux}
    Execute Command                 uart SimulationFilePathWindows ${vuartlite_windows}
    Execute Command                 uart SimulationFilePathMacOS ${vuartlite_macos}

*** Test Cases ***
Should Run UARTLite Binary
    [Tags]                          skip_osx

    Create Machine With Native Based Communication  ${UARTLITE_NATIVE_LINUX}  ${UARTLITE_NATIVE_WINDOWS}  ${UARTLITE_NATIVE_MACOS}
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
