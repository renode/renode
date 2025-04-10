*** Variables ***
${URI}                             @https://dl.antmicro.com/projects/renode
${FASTVDMA_SOCKET_LINUX}           ${URI}/Vfastvdma-Linux-x86_64-12904733885-s_1651016-da5e31f75673a48f4d6fbaa5b5f21fd9190df393
${FASTVDMA_SOCKET_WINDOWS}         ${URI}/Vfastvdma-Windows-x86_64-12904733885.exe-s_3259432-da445f10460a1d6f48d470a5c631e6339a589190
${FASTVDMA_SOCKET_MACOS}           ${URI}/Vfastvdma-macOS-x86_64-12904733885-s_239216-3c4f0c697d39916c5fc14ee560385336b4fcc062
${FASTVDMA_NATIVE_LINUX}           ${URI}/libVfastvdma-Linux-x86_64-12904733885.so-s_2104432-8ec57bdee00c76a044024158525d4130af0afc1a
${FASTVDMA_NATIVE_WINDOWS}         ${URI}/libVfastvdma-Windows-x86_64-12904733885.dll-s_3265828-0e1691527cfb633cf5d8865f3445529708e73f8f
${FASTVDMA_NATIVE_MACOS}           ${URI}/libVfastvdma-macOS-x86_64-12904733885.dylib-s_239144-ebd397eb4d74c08be26cec08c022e90b78f0e020
${RAM_SOCKET_LINUX}                ${URI}/Vram-Linux-x86_64-12904733885-s_1634672-820a0d6d950a74702808d07ad15a7f8a48f86fe0
${RAM_SOCKET_WINDOWS}              ${URI}/Vram-Windows-x86_64-12904733885.exe-s_3245365-7151d2803f710e3f411483352aa822f63a3f405a
${RAM_SOCKET_MACOS}                ${URI}/Vram-macOS-x86_64-12904733885-s_222840-ef7dd5bc27d5e7b13d0444491f2f1f0fb252052e
${RAM_NATIVE_LINUX}                ${URI}/libVram-Linux-x86_64-12904733885.so-s_2088056-004e8ca045d4505d42f552b12f0408c9eb951e8a
${RAM_NATIVE_WINDOWS}              ${URI}/libVram-Windows-x86_64-12904733885.dll-s_3252274-06f5f9b70593f9d57546c9be97791d70c9762129
${RAM_NATIVE_MACOS}                ${URI}/libVram-macOS-x86_64-12904733885.dylib-s_222776-56574ab2821c56a41486c0233d494d7e841c57df

${MAIN_LISTEN_PORT}         3335
${ASYNC_LISTEN_PORT}        3336

*** Keywords ***
Create Machine
    [Arguments]         ${use_socket}   ${custom_ports}=False
    IF      ${use_socket}
        Set Test Variable   ${dma_args}             ; address: "127.0.0.1"
        Set Test Variable   ${fastvdma_linux}       ${FASTVDMA_SOCKET_LINUX}
        Set Test Variable   ${fastvdma_windows}     ${FASTVDMA_SOCKET_WINDOWS}
        Set Test Variable   ${fastvdma_macos}       ${FASTVDMA_SOCKET_MACOS}
        Set Test Variable   ${mem_args}             ; address: "127.0.0.1"
        Set Test Variable   ${ram_linux}            ${RAM_SOCKET_LINUX}
        Set Test Variable   ${ram_windows}          ${RAM_SOCKET_WINDOWS}
        Set Test Variable   ${ram_macos}            ${RAM_SOCKET_MACOS}
    ELSE
        ${dma_args}=                                Evaluate  ""
        Set Test Variable   ${fastvdma_linux}       ${FASTVDMA_NATIVE_LINUX}
        Set Test Variable   ${fastvdma_windows}     ${FASTVDMA_NATIVE_WINDOWS}
        Set Test Variable   ${fastvdma_macos}       ${FASTVDMA_NATIVE_MACOS}
        ${mem_args}=                                Evaluate  ""
        Set Test Variable   ${ram_linux}            ${RAM_NATIVE_LINUX}
        Set Test Variable   ${ram_windows}          ${RAM_NATIVE_WINDOWS}
        Set Test Variable   ${ram_macos}            ${RAM_NATIVE_MACOS}
    END

    Execute Command                             using sysbus
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString 'cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32imaf"; timeProvider: empty }'
    IF      ${custom_ports}
        Execute Command                         machine LoadPlatformDescriptionFromString 'dma: CoSimulated.CoSimulatedPeripheral @ sysbus <0x10000000, +0x100> { frequency: 100000; limitBuffer: 10000; timeout: 240000 ${dma_args}; mainListenPort: ${MAIN_LISTEN_PORT}; asyncListenPort: ${ASYNC_LISTEN_PORT} }'
    ELSE
        Execute Command                         machine LoadPlatformDescriptionFromString 'dma: CoSimulated.CoSimulatedPeripheral @ sysbus <0x10000000, +0x100> { frequency: 100000; limitBuffer: 10000; timeout: 240000 ${dma_args} }'
    END
    Execute Command                             machine LoadPlatformDescriptionFromString 'mem: CoSimulated.CoSimulatedPeripheral @ sysbus <0x20000000, +0x100000> { frequency: 100000; limitBuffer: 10000; timeout: 240000 ${mem_args} }'
    Execute Command                             machine LoadPlatformDescriptionFromString 'ram: Memory.MappedMemory @ sysbus 0xA0000000 { size: 0x06400000 }'
    Execute Command                             sysbus WriteDoubleWord 0xA2000000 0x10500073   # wfi
    Execute Command                             cpu PC 0xA2000000
    Execute Command                             dma SimulationFilePathLinux ${fastvdma_linux}
    Execute Command                             dma SimulationFilePathWindows ${fastvdma_windows}
    Execute Command                             dma SimulationFilePathMacOS ${fastvdma_macos}
    Execute Command                             mem SimulationFilePathLinux ${ram_linux}
    Execute Command                             mem SimulationFilePathWindows ${ram_windows}
    Execute Command                             mem SimulationFilePathMacOS ${ram_macos}
Transaction Should Finish
    ${val} =            Execute Command         dma ReadDoubleWord 0x4
    Should Contain      ${val}                  0x00000000


Prepare Data
    [Arguments]         ${addr}

    # dummy data for verification
    ${addr} =                                   Evaluate  ${addr} + 0x0
    Execute Command                             sysbus WriteDoubleWord ${addr} 0xDEADBEA7
    ${addr} =                                   Evaluate  ${addr} + 0x4
    Execute Command                             sysbus WriteDoubleWord ${addr} 0xDEADC0DE
    ${addr} =                                   Evaluate  ${addr} + 0x4
    Execute Command                             sysbus WriteDoubleWord ${addr} 0xCAFEBABE
    ${addr} =                                   Evaluate  ${addr} + 0x4
    Execute Command                             sysbus WriteDoubleWord ${addr} 0x5555AAAA


Configure DMA
    [Arguments]         ${src}
    ...                 ${dst}
    # reader start address
    Execute Command                             dma WriteDoubleWord 0x10 ${src}
    # reader line length in 32-bit words
    Execute Command                             dma WriteDoubleWord 0x14 1024
    # number of lines to read
    Execute Command                             dma WriteDoubleWord 0x18 1
    # stride size between consecutive lines in 32-bit words
    Execute Command                             dma WriteDoubleWord 0x1c 0

    # writer start address
    Execute Command                             dma WriteDoubleWord 0x20 ${dst}
    # writer line length in 32-bit words
    Execute Command                             dma WriteDoubleWord 0x24 1024
    # number of lines to write
    Execute Command                             dma WriteDoubleWord 0x28 1
    # stride size between consecutive lines in 32-bit words
    Execute Command                             dma WriteDoubleWord 0x2c 0

    # do not wait fo external synchronization signal
    Execute Command                             dma WriteDoubleWord 0x00 0x0f


Ensure Memory Is Clear
    [Arguments]         ${periph}

    # Verify that there are 0's under the writer start address before starting the transaction
    Memory Should Contain                       ${periph}  0x0  0x00000000
    Memory Should Contain                       ${periph}  0x4  0x00000000
    Memory Should Contain                       ${periph}  0x8  0x00000000
    Memory Should Contain                       ${periph}  0xC  0x00000000


Ensure Memory Is Written
    [Arguments]         ${periph}

    # Verify data after the transaction
    Memory Should Contain                       ${periph}  0x0  0xDEADBEA7
    Memory Should Contain                       ${periph}  0x4  0xDEADC0DE
    Memory Should Contain                       ${periph}  0x8  0xCAFEBABE
    Memory Should Contain                       ${periph}  0xC  0x5555AAAA


Memory Should Contain
    [Arguments]         ${periph}
    ...                 ${addr}
    ...                 ${val}
    ${res}=             Execute Command         ${periph} ReadDoubleWord ${addr}
    Should Contain                              ${res}             ${val}

Test Read Write Co-simulated Memory
    Ensure Memory Is Clear                      mem

    # Write to memory
    Prepare Data                                0x20000000

    Ensure Memory Is Written                    mem

Test DMA Transaction From Mapped Memory to Mapped Memory
    Prepare Data                                0xA1000000

    Configure DMA                               0xA1000000  0xA0000000

    Ensure Memory Is Clear                      ram

    Execute Command                             emulation RunFor "00:00:10.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    ram

Test DMA Transaction From Mapped Memory to Co-simulated Memory
    Prepare Data                                0xA1000000

    Configure DMA                               0xA1000000  0x20000000

    Ensure Memory Is Clear                      mem

    Execute Command                             emulation RunFor "00:00:10.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    mem

Test DMA Transaction From Co-simulated Memory to Mapped Memory
    Prepare Data                                0x20080000

    Configure DMA                               0x20080000  0xA0000000

    Ensure Memory Is Clear                      ram

    Execute Command                             emulation RunFor "00:00:10.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    ram

Test DMA Transaction From Co-simulated Memory to Co-simulated Memory
    Prepare Data                                0x20080000

    Configure DMA                               0x20080000  0x20000000

    Ensure Memory Is Clear                      mem

    Execute Command                             emulation RunFor "00:00:10.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    mem

*** Test Cases ***
Should Read Write Co-simulated Memory Using Socket
    [Tags]                          skip_host_arm
    Create Machine      True
    Test Read Write Co-simulated Memory

Should Read Write Co-simulated Memory Using Socket With Custom Ports
    [Tags]                          skip_host_arm
    Create Machine      True    True
    Test Read Write Co-simulated Memory

Should Run DMA Transaction From Mapped Memory to Mapped Memory Using Socket
    [Tags]                          skip_host_arm
    Create Machine      True
    Test DMA Transaction From Mapped Memory to Mapped Memory

Should Run DMA Transaction From Mapped Memory to Co-simulated Memory Using Socket
    [Tags]                          skip_host_arm
    Create Machine      True
    Test DMA Transaction From Mapped Memory to Co-simulated Memory

Should Run DMA Transaction From Co-simulated Memory to Mapped Memory Using Socket
    [Tags]                          skip_host_arm
    Create Machine      True
    Test DMA Transaction From Co-simulated Memory to Mapped Memory

Should Run DMA Transaction From Co-simulated Memory to Co-simulated Memory Using Socket
    [Tags]                          skip_host_arm
    Create Machine      True
    Test DMA Transaction From Co-simulated Memory to Co-simulated Memory

Should Read Write Co-simulated Memory
    [Tags]                          skip_osx  skip_host_arm
    Create Machine      False
    Test Read Write Co-simulated Memory

Should Run DMA Transaction From Mapped Memory to Mapped Memory
    [Tags]                          skip_osx  skip_host_arm
    Create Machine      False
    Test DMA Transaction From Mapped Memory to Mapped Memory

Should Run DMA Transaction From Mapped Memory to Co-simulated Memory
    [Tags]                          skip_osx  skip_host_arm
    Create Machine      False
    Test DMA Transaction From Mapped Memory to Co-simulated Memory

Should Run DMA Transaction From Co-simulated Memory to Mapped Memory
    [Tags]                          skip_osx  skip_host_arm
    Create Machine      False
    Test DMA Transaction From Co-simulated Memory to Mapped Memory

Should Run DMA Transaction From Co-simulated Memory to Co-simulated Memory
    [Tags]                          skip_osx  skip_host_arm
    Create Machine      False
    Test DMA Transaction From Co-simulated Memory to Co-simulated Memory
