*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    Execute Command                             using sysbus
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString 'cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32imaf"; timeProvider: empty }'
    Execute Command                             machine LoadPlatformDescriptionFromString 'dma: Verilated.BaseDoubleWordVerilatedPeripheral @ sysbus <0x10000000, +0x100> { frequency: 100000; limitBuffer: 100000; timeout: 10 }'
    Execute Command                             machine LoadPlatformDescriptionFromString 'mem: Verilated.BaseDoubleWordVerilatedPeripheral @ sysbus <0x20000000, +0x100000> { frequency: 100000; limitBuffer: 100000; timeout: 10 }'
    Execute Command                             machine LoadPlatformDescriptionFromString 'ram: Memory.MappedMemory @ sysbus 0xA0000000 { size: 0x06400000 }'
    Execute Command                             sysbus WriteDoubleWord 0xA2000000 0x10500073   # wfi
    Execute Command                             cpu PC 0xA2000000
    Execute Command                             dma SimulationFilePathLinux ${URI}/VDMATop-s_269080-93368781745a8c9f1784ea8270acba20dd13f8d5
    Execute Command                             dma SimulationFilePathWindows ${URI}/VDMATop.exe-s_1222075-9d070008ee63358b84ff356e137f0d544a3db817
    Execute Command                             mem SimulationFilePathLinux ${URI}/Vaxi_ram-s_243384-6aa796a28cbe3fe89e19c0f01b3e8df4b77aa89f
    Execute Command                             mem SimulationFilePathWindows ${URI}/Vaxi_ram.exe-s_1170346-a9e68ab0d037c4625d72b9e4f6e35652a23158fd


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


*** Test Cases ***
Should Read Write Verilated Memory
    [Tags]                          skip_osx  skip_windows
    Create Machine

    Ensure Memory Is Clear                      mem

    # Write to memory
    Prepare Data                                0x20000000

    Ensure Memory Is Written                    mem


Should Run DMA Transaction From Mapped Memory to Mapped Memory
    [Tags]                          skip_osx  skip_windows
    Create Machine

    Prepare Data                                0xA1000000

    Configure DMA                               0xA1000000  0xA0000000

    Ensure Memory Is Clear                      ram

    Execute Command                             emulation RunFor "00:00:05.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    ram


Should Run DMA Transaction From Mapped Memory to Verilated Memory
    [Tags]                          skip_osx  skip_windows
    Create Machine

    Prepare Data                                0xA1000000

    Configure DMA                               0xA1000000  0x20000000

    Ensure Memory Is Clear                      mem

    Execute Command                             emulation RunFor "00:00:05.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    mem


Should Run DMA Transaction From Verilated Memory to Mapped Memory
    [Tags]                          skip_osx  skip_windows
    Create Machine

    Prepare Data                                0x20080000

    Configure DMA                               0x20080000  0xA0000000

    Ensure Memory Is Clear                      ram

    Execute Command                             emulation RunFor "00:00:05.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    ram


Should Run DMA Transaction From Verilated Memory to Verilated Memory
    [Tags]                          skip_osx  skip_windows
    Create Machine

    Prepare Data                                0x20080000

    Configure DMA                               0x20080000  0x20000000

    Ensure Memory Is Clear                      mem

    Execute Command                             emulation RunFor "00:00:05.000000"
    Transaction Should Finish

    Ensure Memory Is Written                    mem
