*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${URI}                              https://dl.antmicro.com/projects/renode
${VFASTDMA_SOCKET_LINUX}            ${URI}/Vfastvdma-Linux-x86_64-1004737087-s_1610976-9a3aebf888b533a2c4abc716d623da74f9c2a062
${VFASTDMA_SOCKET_WINDOWS}          ${URI}/Vfastvdma-Windows-x86_64-1004737087.exe-s_14830615-67051627396e3c946cc11e8e6ad97a9658fde073
${VFASTDMA_SOCKET_MACOS}            ${URI}/Vfastvdma-macOS-x86_64-1004737087-s_229664-1ba599fd629690039ee032d909ea7804ebadf3b0
${VFASTDMA_NATIVE_LINUX}            ${URI}/libVfastvdma-Linux-x86_64-1004737087.so-s_2051936-f283ee6491652bed6cba9ac6a9092eb438fb92cf
${VFASTDMA_NATIVE_WINDOWS}          ${URI}/libVfastvdma-Windows-x86_64-1004737087.dll-s_14834447-475a6e320c9d2a7031db581163fec4ec0ba658f7
${VFASTDMA_NATIVE_MACOS}            ${URI}/libVfastvdma-macOS-x86_64-1004737087.dylib-s_229600-177cdbf7c06f3d356c0acf9deef5159d3194e30f
${VRAM_SOCKET_LINUX}                ${URI}/Vram-Linux-x86_64-1004737087-s_1598728-6b7c76e4ea7114f09775cc6553bdce8656d95fb5
${VRAM_SOCKET_WINDOWS}              ${URI}/Vram-Windows-x86_64-1004737087.exe-s_14816687-f3e74e4af2b81dfcf1bbf40dd18c8b37f444ffcf
${VRAM_SOCKET_MACOS}                ${URI}/Vram-macOS-x86_64-1004737087-s_213288-09959d79fe588cdf068353528be9bb61a1a9255b
${VRAM_NATIVE_LINUX}                ${URI}/libVram-Linux-x86_64-1004737087.so-s_2039688-f1043f1459ac7e721f342ebd55af0d057b685fba
${VRAM_NATIVE_WINDOWS}              ${URI}/libVram-Windows-x86_64-1004737087.dll-s_14820520-ee7f798b302c0923b70b9b705dda79f112c0e9bb
${VRAM_NATIVE_MACOS}                ${URI}/libVram-macOS-x86_64-1004737087.dylib-s_213232-fda23af62856ea0520e0586336a68efee5099de2

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
