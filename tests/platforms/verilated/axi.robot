*** Variables ***
${URI}                              https://dl.antmicro.com/projects/renode
${VFASTDMA_SOCKET_LINUX}            ${URI}/Vfastvdma-Linux-x86_64-1116123840-s_1616232-37fd8031dec810475ac6abf68a789261ce6551b0
${VFASTDMA_SOCKET_WINDOWS}          ${URI}/Vfastvdma-Windows-x86_64-1116123840.exe-s_14833257-3a1fef7953686e58a00b09870c5a57e3ac91621d
${VFASTDMA_SOCKET_MACOS}            ${URI}/Vfastvdma-macOS-x86_64-1116123840-s_230336-8f69fd45aea5806309e9253bcca8b7e32a1d5544
${VFASTDMA_NATIVE_LINUX}            ${URI}/libVfastvdma-Linux-x86_64-1116123840.so-s_2057368-8e927ed058a025cf5c1d4d423336f830e9dc7734
${VFASTDMA_NATIVE_WINDOWS}          ${URI}/libVfastvdma-Windows-x86_64-1116123840.dll-s_14838113-a51512dd0c7c4b5f5d8e28aca2ce872a2c9c1edd
${VFASTDMA_NATIVE_MACOS}            ${URI}/libVfastvdma-macOS-x86_64-1116123840.dylib-s_230272-465727b67a3b37554b2a0e6fd36f9b73e5af015e
${VRAM_SOCKET_LINUX}                ${URI}/Vram-Linux-x86_64-1116123840-s_1599888-76d5965bf7e7e1c6b92a606c35cc9df818ac8f6f
${VRAM_SOCKET_WINDOWS}              ${URI}/Vram-Windows-x86_64-1116123840.exe-s_14819329-08c574a442749bff9e30de9e30323a0b730c64d2
${VRAM_SOCKET_MACOS}                ${URI}/Vram-macOS-x86_64-1116123840-s_213960-84c4147cb55aa7a77a33db111cf34bd2e684e370
${VRAM_NATIVE_LINUX}                ${URI}/libVram-Linux-x86_64-1116123840.so-s_2041000-dc075efcd97e2dc460660e26bcf34efe79f7da64
${VRAM_NATIVE_WINDOWS}              ${URI}/libVram-Windows-x86_64-1116123840.dll-s_14824186-efcb553f2f0a1d6aef13abedddec91d3613169fc
${VRAM_NATIVE_MACOS}                ${URI}/libVram-macOS-x86_64-1116123840.dylib-s_213904-bab67e73e73c7f3f9f3b8916d6df53294d9e337a

*** Keywords ***
Create Machine
    [Arguments]         ${use_socket}
    IF      ${use_socket}
        Set Test Variable   ${dma_args}             ; address: "127.0.0.1"
        Set Test Variable   ${vfastdma_linux}       ${VFASTDMA_SOCKET_LINUX}
        Set Test Variable   ${vfastdma_windows}     ${VFASTDMA_SOCKET_WINDOWS}
        Set Test Variable   ${vfastdma_macos}       ${VFASTDMA_SOCKET_MACOS}
        Set Test Variable   ${mem_args}             ; address: "127.0.0.1"
        Set Test Variable   ${vram_linux}           ${VRAM_SOCKET_LINUX}
        Set Test Variable   ${vram_windows}         ${VRAM_SOCKET_WINDOWS}
        Set Test Variable   ${vram_macos}           ${VRAM_SOCKET_MACOS}
    ELSE
        ${dma_args}=                                Evaluate  ""
        Set Test Variable   ${vfastdma_linux}       ${VFASTDMA_NATIVE_LINUX}
        Set Test Variable   ${vfastdma_windows}     ${VFASTDMA_NATIVE_WINDOWS}
        Set Test Variable   ${vfastdma_macos}       ${VFASTDMA_NATIVE_MACOS}
        ${mem_args}=                                Evaluate  ""
        Set Test Variable   ${vram_linux}           ${VRAM_NATIVE_LINUX}
        Set Test Variable   ${vram_windows}         ${VRAM_NATIVE_WINDOWS}
        Set Test Variable   ${vram_macos}           ${VRAM_NATIVE_MACOS}
    END

    Execute Command                             using sysbus
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString 'cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32imaf"; timeProvider: empty }'
    Execute Command                             machine LoadPlatformDescriptionFromString 'dma: Verilated.BaseDoubleWordVerilatedPeripheral @ sysbus <0x10000000, +0x100> { frequency: 100000; limitBuffer: 100000; timeout: 10000 ${dma_args} }'
    Execute Command                             machine LoadPlatformDescriptionFromString 'mem: Verilated.BaseDoubleWordVerilatedPeripheral @ sysbus <0x20000000, +0x100000> { frequency: 100000; limitBuffer: 100000; timeout: 10000 ${mem_args} }'
    Execute Command                             machine LoadPlatformDescriptionFromString 'ram: Memory.MappedMemory @ sysbus 0xA0000000 { size: 0x06400000 }'
    Execute Command                             sysbus WriteDoubleWord 0xA2000000 0x10500073   # wfi
    Execute Command                             cpu PC 0xA2000000
    Execute Command                             dma SimulationFilePathLinux @${vfastdma_linux}
    Execute Command                             dma SimulationFilePathWindows @${vfastdma_windows}
    Execute Command                             dma SimulationFilePathMacOS @${vfastdma_macos}
    Execute Command                             mem SimulationFilePathLinux @${vram_linux}
    Execute Command                             mem SimulationFilePathWindows @${vram_windows}
    Execute Command                             mem SimulationFilePathMacOS @${vram_macos}
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

Test Read Write Verilated Memory
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

Test DMA Transaction From Mapped Memory to Verilated Memory
    Prepare Data                                0xA1000000

    Configure DMA                               0xA1000000  0x20000000

    Ensure Memory Is Clear                      mem

    Execute Command                             emulation RunFor "00:00:10.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    mem

Test DMA Transaction From Verilated Memory to Mapped Memory
    Prepare Data                                0x20080000

    Configure DMA                               0x20080000  0xA0000000

    Ensure Memory Is Clear                      ram

    Execute Command                             emulation RunFor "00:00:10.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    ram

Test DMA Transaction From Verilated Memory to Verilated Memory
    Prepare Data                                0x20080000

    Configure DMA                               0x20080000  0x20000000

    Ensure Memory Is Clear                      mem

    Execute Command                             emulation RunFor "00:00:10.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    mem

*** Test Cases ***
Should Read Write Verilated Memory Using Socket
    Create Machine      True
    Test Read Write Verilated Memory

Should Run DMA Transaction From Mapped Memory to Mapped Memory Using Socket
    Create Machine      True
    Test DMA Transaction From Mapped Memory to Mapped Memory

Should Run DMA Transaction From Mapped Memory to Verilated Memory Using Socket
    Create Machine      True
    Test DMA Transaction From Mapped Memory to Verilated Memory

Should Run DMA Transaction From Verilated Memory to Mapped Memory Using Socket
    Create Machine      True
    Test DMA Transaction From Verilated Memory to Mapped Memory

Should Run DMA Transaction From Verilated Memory to Verilated Memory Using Socket
    Create Machine      True
    Test DMA Transaction From Verilated Memory to Verilated Memory

Should Read Write Verilated Memory
    [Tags]                          skip_osx
    Create Machine      False
    Test Read Write Verilated Memory

Should Run DMA Transaction From Mapped Memory to Mapped Memory
    [Tags]                          skip_osx
    Create Machine      False
    Test DMA Transaction From Mapped Memory to Mapped Memory

Should Run DMA Transaction From Mapped Memory to Verilated Memory
    [Tags]                          skip_osx
    Create Machine      False
    Test DMA Transaction From Mapped Memory to Verilated Memory

Should Run DMA Transaction From Verilated Memory to Mapped Memory
    [Tags]                          skip_osx
    Create Machine      False
    Test DMA Transaction From Verilated Memory to Mapped Memory

Should Run DMA Transaction From Verilated Memory to Verilated Memory
    [Tags]                          skip_osx
    Create Machine      False
    Test DMA Transaction From Verilated Memory to Verilated Memory
