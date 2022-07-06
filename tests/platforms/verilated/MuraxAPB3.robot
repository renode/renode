*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode
${BIN}                              murax--demo.elf-s_26952-7635fc30d0a3ed10c5b7cba622131b02d103f629
${UART}                             sysbus.uart
${SOCKET_LINUX}                     ${URI}/Vapb3uart-Linux-x86_64-1116123840-s_1604688-cb9962289b326d8defc1f7abb4b293a0e71ef8aa
${SOCKET_WINDOWS}                   ${URI}/Vapb3uart-Windows-x86_64-1116123840.exe-s_14823704-16aec151000300b42efc759f325438c2aad77d6e
${SOCKET_MACOS}                     ${URI}/Vapb3uart-macOS-x86_64-1116123840-s_214928-b8cbb2c12d4bf367cf10ff1ad5db45238ad06f08
${NATIVE_LINUX}                     ${URI}/libVapb3uart-Linux-x86_64-1116123840.so-s_2049920-1bca4e9cf7f3465907cea32e2be7a176b78d97f3
${NATIVE_WINDOWS}                   ${URI}/libVapb3uart-Windows-x86_64-1116123840.dll-s_14829076-0f58c94cf875cf6ebe442dbe24426c9308eef3e7
${NATIVE_MACOS}                     ${URI}/libVapb3uart-macOS-x86_64-1116123840.dylib-s_214864-267618c5da753aa7c1629db0a518aea39fdf6ad0

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
    Create Machine             ${NATIVE_LINUX}  ${NATIVE_WINDOWS}  ${NATIVE_MACOS}  @platforms/cpus/verilated/murax_vexriscv_verilated_uart.repl
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Handle UART Input

    Wait For Prompt On Uart    Ant

Echo On Uart With Socket Based Communication
    Create Machine With Platform Description From String             ${SOCKET_LINUX}  ${SOCKET_WINDOWS}  ${SOCKET_MACOS}  ${PLATFORM}
    Create Terminal Tester     sysbus.uart
    Execute Command            showAnalyzer sysbus.uart

    Start Emulation

    Handle UART Input

    Wait For Prompt On Uart    Ant
