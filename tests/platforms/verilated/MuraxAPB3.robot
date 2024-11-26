*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN}                              murax--demo.elf-s_26952-7635fc30d0a3ed10c5b7cba622131b02d103f629
${UART}                             sysbus.uart

// Binaries from https://github.com/antmicro/renode-verilator-integration, rev. f9b4139
${APB3UART_SOCKET_LINUX}            @${URI}/Vapb3uart-Linux-x86_64-12048046797-s_1620824-032429468be6348953be4dee1dd58f207de7ef7a
${APB3UART_SOCKET_WINDOWS}          @${URI}/Vapb3uart-Windows-x86_64-12048046797.exe-s_3231205-a5ad3f3c2fbae644ea6a60c137bf24f039a901a0
${APB3UART_SOCKET_MACOS}            @${URI}/Vapb3uart-macOS-x86_64-12048046797-s_220504-de2a1d717d2b072c80946f3a8787b7b73c00d7a4
${APB3UART_NATIVE_LINUX}            @${URI}/libVapb3uart-Linux-x86_64-12048046797.so-s_2075112-e22c7625fe6f6f43157c23e7100df3ae0612d4cf
${APB3UART_NATIVE_WINDOWS}          @${URI}/libVapb3uart-Windows-x86_64-12048046797.dll-s_3237057-f212c564b7875695fa5de4059f66f64489e04c3c
${APB3UART_NATIVE_MACOS}            @${URI}/libVapb3uart-macOS-x86_64-12048046797.dylib-s_220448-1fc9bbfc2c7403cf9560c2a752cc96369b92d2e0

${PLATFORM}=     SEPARATOR=
...  """                                                                        ${\n}
...  using "platforms/cpus/verilated/murax_vexriscv_verilated_uart.repl"        ${\n}
...                                                                             ${\n}
...  uart:                                                                      ${\n}
...  ${SPACE*4}address: "127.0.0.1"                                             ${\n}
...  """


*** Keywords ***
Create Machine
    [Arguments]         ${apb3uart_linux}    ${apb3uart_windows}    ${apb3uart_macos}    ${repl}
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescription ${repl}

    Execute Command            sysbus LoadELF ${URI}/${BIN}
    Execute Command            uart SimulationFilePathLinux ${apb3uart_linux}
    Execute Command            uart SimulationFilePathWindows ${apb3uart_windows}
    Execute Command            uart SimulationFilePathMacOS ${apb3uart_macos}

    Machine Config

Create Machine With Platform Description From String
    [Arguments]         ${apb3uart_linux}    ${apb3uart_windows}    ${apb3uart_macos}    ${repl}
    Execute Command            using sysbus
    Execute Command            mach create
    Execute Command            machine LoadPlatformDescriptionFromString ${repl}

    Execute Command            sysbus LoadELF ${URI}/${BIN}
    Execute Command            uart SimulationFilePathLinux ${apb3uart_linux}
    Execute Command            uart SimulationFilePathWindows ${apb3uart_windows}
    Execute Command            uart SimulationFilePathMacOS ${apb3uart_macos}

    Machine Config

Machine Config
    Execute Command            sysbus.cpu MTVEC 0x80000020

    # this is a hack to allow handling interrupts at all; this should be fixed after #13326
    Execute Command            sysbus.cpu SetMachineIrqMask 0xffffffff

    # set frame length in UART's FrameCongfig register (0xC)
    Execute Command            sysbus WriteDoubleWord 0xF001000C 0x000F

Handle UART Input
    # After the initial 'A' char, value 255 is sent to UART which affects the input.
    # First three chars are consumed by the 255, and then printed together, so if the input would be 'a', 'b' and 'c', then on the UART
    # would appear "�abc". After that the UART is echoing any input normally.
    Write Char On Uart         .
    Write Char On Uart         .
    Write Char On Uart         .

    Write Char On Uart         A
    Write Char On Uart         n
    Write Char On Uart         t


*** Test Cases ***
Echo On Uart With Native Communication
    [Tags]                          skip_osx
    Create Machine             ${APB3UART_NATIVE_LINUX}  ${APB3UART_NATIVE_WINDOWS}  ${APB3UART_NATIVE_MACOS}  @platforms/cpus/verilated/murax_vexriscv_verilated_uart.repl
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Handle UART Input

    Wait For Prompt On Uart    Ant

Echo On Uart With Socket Based Communication
    Create Machine With Platform Description From String  ${APB3UART_SOCKET_LINUX}  ${APB3UART_SOCKET_WINDOWS}  ${APB3UART_SOCKET_MACOS}  ${PLATFORM}
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Handle UART Input

    Wait For Prompt On Uart    Ant
