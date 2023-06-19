*** Settings ***
Suite Setup                         Setup
Suite Teardown                      Teardown
Test Setup                          Reset Emulation
Test Teardown                       Test Teardown
Resource                            ${RENODEKEYWORDS}

*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN_DEMO}                         ${URI}/zephyr--verilated_liteuart--shell.elf-s_864780-63c7e83fb01451ac6683434997f6f03c6a8f9079
${LITEUART_NATIVE_LINUX}            ${URI}/libVliteuart-Linux-x86_64-1116123840.so-s_2040888-d31aa31e74329fc50e5e36ca0540de2571b8e3de
${LITEUART_NATIVE_WINDOWS}          ${URI}/libVliteuart-Windows-x86_64-1116123840.dll-s_14824753-d84d662cba6d457d55ac8b17bc6cd473d6d553ca
${LITEUART_NATIVE_MACOS}            ${URI}/libVliteuart-macOS-x86_64-1116123840.dylib-s_213784-da6594d7f7a5ef6fd3d52a9a64d6fcfe3d91d935
${LOCAL_FILENAME}                   liteuart
${UART}                             sysbus.uart
${PLATFORM}                         @platforms/cpus/verilated/litex_vexriscv_verilated_liteuart.repl
${LOG_TIMEOUT}                      1  # virtual seconds

*** Keywords ***
Create Machine
    [Arguments]                     ${vliteuart_linux}  ${vliteuart_windows}  ${vliteuart_macos}
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 sysbus LoadELF ${BIN_DEMO}
    Execute Command                 uart SimulationFilePathLinux ${vliteuart_linux}
    Execute Command                 uart SimulationFilePathWindows ${vliteuart_windows}
    Execute Command                 uart SimulationFilePathMacOS ${vliteuart_macos}

*** Test Cases ***
# Starting emulation without SimulationFilePath(Linux|MacOS|Windows) set
Should Handle Empty LiteUART Binary
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 showAnalyzer sysbus.uart
    Execute Command                 sysbus LoadELF ${BIN_DEMO}
    Run Keyword And Expect Error    *Cannot start emulation. Set SimulationFilePath or connect to a simulator first!*  Start Emulation

Should Run LiteUART Binary
    Set Test Variable               ${uartLinux}  ${LITEUART_NATIVE_LINUX}
    Set Test Variable               ${uartWindows}  ${LITEUART_NATIVE_WINDOWS}
    Set Test Variable               ${uartMacOS}  ${LITEUART_NATIVE_MACOS}
    Create Machine                  ${uartLinux}  ${uartWindows}  ${uartMacOS}
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Prompt On Uart         uart:~$

# Starting emulation without SimulationFilePath(Linux|MacOS|Windows) set

Should Handle Empty LiteUART Binary
    Create Log Tester               ${LOG_TIMEOUT}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription ${PLATFORM}
    Execute Command                 sysbus LoadELF ${BIN_DEMO}
    Run Keyword And Expect Error    *Cannot start emulation. Set SimulationFilePath or connect to a simulator first!*  Start Emulation

# File Doesn't Exist

Should Handle Nonexistent LiteUART Binary
    Create Log Tester               ${LOG_TIMEOUT}
    Run Keyword And Expect Error    *Error starting verilated peripheral!*  Create Machine  nonexistent-uart-binary  nonexistent-uart-binary  nonexistent-uart-binary
