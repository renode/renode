*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN}                              uartlite--custom_uart_demo--zephyr.elf-s_184340-129eb92404f437a466cd8700f6743b1c5b0da912
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
    Run Keyword And Expect Error    *Cannot start emulation. Set SimulationFilePath first!*    Start Emulation

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
    Set Test Variable               ${uartLinux}    ${URI}/Vuartlite-Linux-x86_64-1004737087-s_1598528-2cdf75f092fd56012d3acd8020310ddf006b4719
    Set Test Variable               ${uartWindows}  ${URI}/Vuartlite-Windows-x86_64-1004737087.exe-s_14815636-e0f6234ce90eda767289f542e5f1022568eaf5ac
    Set Test Variable               ${uartMacOS}    ${URI}/Vuartlite-macOS-x86_64-1004737087-s_213064-0a6ebb5e43f9bb98342b586587a7f90a64211d41
    Create Machine With Socket Based Communication  ${uartLinux}    ${uartWindows}      ${uartMacOS}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 10

# Sleep after 1000 iterations in "simulate" loop (renode.cpp)
Should Handle Connection Timeout
    Set Test Variable               ${uartLinux}    ${URI}/Vsleep-after-1000-iters-Linux-x86_64-1004737087-s_1598568-e6e953774e934707416d0a896ebc0dd0d791f6c3
    Set Test Variable               ${uartWindows}  ${URI}/Vsleep-after-1000-iters-Windows-x86_64-1004737087.exe-s_14817164-5008b1ff8394b6602c2609178bae67b01ca438c5
    Set Test Variable               ${uartMacOS}    ${URI}/Vsleep-after-1000-iters-macOS-x86_64-1004737087-s_213104-abe2f6a1f9681d1a6654781be4ffd24ef432bbf7
    Create Machine With Socket Based Communication  ${uartLinux}    ${uartWindows}      ${uartMacOS}
    Create Log Tester               ${LOG_TIMEOUT}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           I'm alive! counter = 9
    Wait For Log Entry              Receive error!

# Both ports wrong when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Not Connecting
    Set Test Variable               ${uartLinux}    ${URI}/Vwrong-ports-Linux-x86_64-1004737087-s_1598528-22840f0f99c9f46ce964300c94119c4d5594365d
    Set Test Variable               ${uartWindows}  ${URI}/Vwrong-ports-Windows-x86_64-1004737087.exe-s_14815636-cfbfcf17dc6e3568b667649226736cc29b353964
    Set Test Variable               ${uartMacOS}    ${URI}/Vwrong-ports-macOS-x86_64-1004737087-s_213064-1fe5488d2059797593a6e3be943e5d40db0416c0
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the verilated peripheral (*) failed!*    Create Machine With Socket Based Communication  ${uartLinux}  ${uartWindows}  ${uartMacOS}

# Wrong "second" port when calling "simulate" (sim_main.cpp)
Should Handle UARTLite Binary Partly Connecting
    Set Test Variable               ${uartLinux}    ${URI}/Vwrong-second-port-Linux-x86_64-1004737087-s_1598528-ff16a918d22a9933d998a7a8d460a0e3acc5e480
    Set Test Variable               ${uartWindows}  ${URI}/Vwrong-second-port-Windows-x86_64-1004737087.exe-s_14815636-b635f35a5a7c79beaf27a82cb89e426dd2621332
    Set Test Variable               ${uartMacOS}    ${URI}/Vwrong-second-port-macOS-x86_64-1004737087-s_213064-8937d3450aafadf8aa2e25abebbb0c447e24d4a2
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Connection to the verilated peripheral (*) failed!*    Create Machine With Socket Based Communication  ${uartLinux}  ${uartWindows}  ${uartMacOS}

# Starting emulation without SimulationFilePath(Linux|MacOS|Windows) set
Should Handle Empty UARTLite Binary With Socket Based Communication
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus LoadELF ${URI}/${BIN}
    Execute Command                 sysbus.cpu PC `sysbus GetSymbolAddress "vinit"`
    Run Keyword And Expect Error    *Cannot start emulation. Set SimulationFilePath first!*    Start Emulation

# File Doesn't Exist
Should Handle Nonexistent UARTLite Binary With Socket Based Communication
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Error starting verilated peripheral!*    Create Machine With Socket Based Communication  nonexistent-uart-binary  nonexistent-uart-binary  nonexistent-uart-binary
