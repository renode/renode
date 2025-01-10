*** Variables ***
${URI}                             @https://dl.antmicro.com/projects/renode
${FASTVDMA_SOCKET_LINUX}           ${URI}/Vfastvdma-Linux-x86_64-12746432362-s_1632096-8dff91a71b3d3f9a26ee98086a64a490b334cda1
${FASTVDMA_SOCKET_WINDOWS}         ${URI}/Vfastvdma-Windows-x86_64-12746432362.exe-s_3243873-4fe10ea4e863a62058169fd2164b66c93ef409f6
${FASTVDMA_SOCKET_MACOS}           ${URI}/Vfastvdma-macOS-x86_64-12746432362-s_235752-8591dd2649f88d0c4806ec4ae81207ae0cd046f3
${FASTVDMA_NATIVE_LINUX}           ${URI}/libVfastvdma-Linux-x86_64-12746432362.so-s_2078168-e066add0a343381e311b24264f5f700434601b50
${FASTVDMA_NATIVE_WINDOWS}         ${URI}/libVfastvdma-Windows-x86_64-12746432362.dll-s_3248733-b126ebbb295a6668560780c35b9f4652e2be833a
${FASTVDMA_NATIVE_MACOS}           ${URI}/libVfastvdma-macOS-x86_64-12746432362.dylib-s_235688-84b6822a41f9b46f9890284aa2129d90713fb4eb
${RAM_SOCKET_LINUX}                ${URI}/Vram-Linux-x86_64-12746432362-s_1615752-825d00f11e14adccdbe6b19771b7122c173b747c
${RAM_SOCKET_WINDOWS}              ${URI}/Vram-Windows-x86_64-12746432362.exe-s_3230933-8e3617a5ff81eab33729ec75f4fab1f7f827c84b
${RAM_SOCKET_MACOS}                ${URI}/Vram-macOS-x86_64-12746432362-s_219400-ce466212ec608abf9854c1ea70ca806b36605e82
${RAM_NATIVE_LINUX}                ${URI}/libVram-Linux-x86_64-12746432362.so-s_2065920-56f65549a9566ffbf86760c2752fb7917221351a
${RAM_NATIVE_WINDOWS}              ${URI}/libVram-Windows-x86_64-12746432362.dll-s_3235282-9e7c542f4c7777e1dd98f2ffbc8049d5e20f6619
${RAM_NATIVE_MACOS}                ${URI}/libVram-macOS-x86_64-12746432362.dylib-s_219336-ea431e001078485dfce84c0977a95008bf258fc6

*** Keywords ***
Create Machine
    [Arguments]         ${use_socket}
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
    Execute Command                             machine LoadPlatformDescriptionFromString 'dma: CoSimulated.CoSimulatedPeripheral @ sysbus <0x10000000, +0x100> { frequency: 100000; limitBuffer: 10000; timeout: 240000 ${dma_args} }'
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
