*** Variables ***
${PRIV_ALL}                         0x3
${PRIV_WRITE}                       0x2
${PRIV_READ}                        0x1
${PRIV_NONE}                        0x0
${START_PC}                         0x0
${DMA_ADDR}                         0x45000000
${IOMMU_ADDR}                       0x46000000

*** Keywords ***
Create Platform
    Execute Command                 using sysbus
    Execute Command                 mach create "risc-v"

    Execute Command                 machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { timeProvider: clint; cpuType: \\"rv32gc\\" }"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x100000 }"    
    Execute Command                 machine LoadPlatformDescriptionFromString "iommu0: Miscellaneous.WindowIOMMU @ sysbus ${IOMMU_ADDR} { IRQ -> cpu@1 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "dma0: SimpleDMA @ { sysbus ${DMA_ADDR}; iommu0 0 }"

    Execute Command                 sysbus WriteDoubleWord ${START_PC} 0x000000ef  # jal  ra, 0
    Execute Command                 cpu PC ${START_PC} 

Write Range With Doublewords
    [Arguments]                     ${start_addr}  ${length}  ${value}
    ${end_addr}=                    Evaluate  ${start_addr}+${length}
    ${bytesPerDoubleword}=          Evaluate  4
    FOR   ${addr}  IN RANGE         ${start_addr}  ${end_addr}  ${bytesPerDoubleWord}
        Execute Command             sysbus WriteDoubleWord ${addr} ${value}
    END

Write To Address By DMA
    [Arguments]                     ${dma_addr_hex}  ${addr}  ${value}
    ${dma_addr}=                    Convert To Integer  ${dma_addr_hex}
    Execute Command                 sysbus WriteDoubleWord ${dma_addr+0} ${value}
    Execute Command                 sysbus WriteDoubleWord ${dma_addr+4} ${addr}

Read From Address By DMA
    [Arguments]                     ${dma_addr_hex}  ${addr}
    ${dma_addr}=                    Convert To Integer  ${dma_addr_hex}
    Execute Command                 sysbus WriteDoubleWord ${dma_addr+8} ${addr}
    ${read_value}=                  Execute Command  sysbus ReadDoubleWord ${dma_addr+0}
    [return]                        ${read_value}                   

Define Window
    [Arguments]                     ${window_index}  ${start_addr}  ${end_addr}  ${offset}  ${priv}
    
    ${window_register}=             Evaluate  4 * ${window_index} + ${IOMMU_ADDR}
    ${start_register}=              Evaluate  0x0 + ${window_register}
    ${end_register}=                Evaluate  0x400 + ${window_register}
    ${offset_register}=             Evaluate  0x800 + ${window_register}
    ${priv_register}=               Evaluate  0xC00 + ${window_register}

    Execute Command                 sysbus WriteDoubleWord ${start_register} ${start_addr}
    Execute Command                 sysbus WriteDoubleWord ${end_register} ${end_addr}
    Execute Command                 sysbus WriteDoubleWord ${offset_register} ${offset}
    Execute Command                 sysbus WriteDoubleWord ${priv_register} ${priv}

*** Test Cases ***
Simple DMA Should Read And Write
    Create Platform

    Write Range With Doublewords    0x100  0x110  0x01234567
    Define Window                   0  0x0  0x10000  0x0  ${PRIV_ALL}

    Write To Address By DMA         ${DMA_ADDR}  0x104  0x89abcdef
    ${written_value}=               Execute Command  sysbus ReadDoubleWord 0x104
    Should Be Equal As Integers     ${written_value}  0x89abcdef

    ${read_value}=                  Read From Address By DMA  ${DMA_ADDR}  0x100
    Should Be Equal As Integers     ${read_value}  0x01234567

    ${read_value}=                  Read From Address By DMA  ${DMA_ADDR}  0x104
    Should Be Equal As Integers     ${read_value}  0x89abcdef

Address Are Translated
    Create Platform

    Define Window                   0  0x1000  0x1100  256  ${PRIV_ALL}
    Define Window                   1  0x1200  0x1300  -256  ${PRIV_ALL}

    Write To Address By DMA         ${DMA_ADDR}  0x1000  0x01234567
    ${read_value}=                  Execute Command  sysbus ReadDoubleWord 0x1100
    Should Be Equal As Integers     ${read_value}  0x01234567
    ${read_value}=                  Execute Command  sysbus ReadDoubleWord 0x1000
    Should Be Equal As Integers     ${read_value}  0x0

    Write To Address By DMA         ${DMA_ADDR}  0x1200  0x89abcdef
    ${read_value}=                  Execute Command  sysbus ReadDoubleWord 0x1100
    Should Be Equal As Integers     ${read_value}  0x89abcdef
    ${read_value}=                  Execute Command  sysbus ReadDoubleWord 0x1000
    Should Be Equal As Integers     ${read_value}  0x0

IOMMU Fault Triggers IRQ    
    Create Platform
    Create Log Tester               0
    Execute Command                 logLevel -1

    Define Window                   0  0x0000  0x1000  0x0  ${PRIV_NONE}
    Start Emulation

    Read From Address By DMA        ${DMA_ADDR}  0x0FFA
    Wait For Log Entry              IOMMU fault at 0xFFA when trying to access as Read
    Wait For Log Entry              Setting the IRQ 
    Wait For Log Entry              Setting CPU IRQ #1

Permissions Are Respected
    Create Platform
    Create Log Tester               0
    Execute Command                 logLevel -1

    Define Window                   0  0x0000  0x1000  0x0  ${PRIV_NONE}
    Define Window                   1  0x1000  0x2000  0x0  ${PRIV_ALL}
    Write Range With Doublewords    0x1000  0x1FFF  0x01234567
    Define Window                   3  0x2000  0x3000  0x0  ${PRIV_NONE}
    Define Window                   5  0x3000  0x4000  0x0  ${PRIV_WRITE}
    Define Window                   6  0x4000  0x5000  0x0  ${PRIV_READ}

    Read From Address By DMA        ${DMA_ADDR}  0x0FFA
    Wait For Log Entry              IOMMU fault at 0xFFA

    Write To Address By DMA         ${DMA_ADDR}  0x0FFC  0x0
    Wait For Log Entry              IOMMU fault at 0xFFC
    
    Write To Address By DMA         ${DMA_ADDR}  0x1000  0x0
    Should Not Be In Log            IOMMU fault at 0x1000

    Write To Address By DMA         ${DMA_ADDR}  0x1FFF  0x0
    Read From Address By DMA        ${DMA_ADDR}  0x1FFF
    Should Not Be In Log            IOMMU fault at 0x1FFF

    Write To Address By DMA         ${DMA_ADDR}  0x2000  0x0
    Wait For Log Entry              IOMMU fault at 0x2000
    
    Write To Address By DMA         ${DMA_ADDR}  0x3000  0x0
    Should Not Be In Log            IOMMU fault at 0x3000

    Read From Address By DMA        ${DMA_ADDR}  0x3000
    Wait For Log Entry              IOMMU fault at 0x3000

    Read From Address By DMA        ${DMA_ADDR}  0x4000
    Should Not Be In Log            IOMMU fault at 0x4000

    Write To Address By DMA         ${DMA_ADDR}  0x4000  0x0
    Wait For Log Entry              IOMMU fault at 0x4000

Throws Error On Registering Two IOMMUs For One Peripheral
    Create Platform
    Create Log Tester               0

    Execute Command                 machine LoadPlatformDescriptionFromString "iommu1: Miscellaneous.WindowIOMMU @ sysbus 0x47000000"
    Run Keyword And Expect Error    *Trying to change the BusController from *  Execute Command  machine LoadPlatformDescriptionFromString "dma1: SimpleDMA @ { sysbus 0x48000000; iommu0 1; iommu1 0 }"

Defining Invalid Window Throws
    # This test case doesn't check 64-bit unsigned integer overflow
    Create Platform

    Define Window                   0  0x0  0xffffffff  0x7fffffff  ${PRIV_NONE}
    Define Window                   0  0x100  0x100  0x0  ${PRIV_NONE}
    Define Window                   0  0x101  0x100  0  ${PRIV_NONE}
    Wait For Log Entry              MMUWindow has start address .* grater than end address  treatAsRegex=true

    Define Window                   0  0x100  0x1000  -256  ${PRIV_NONE}
    Should Not Be In Log            MMUWindow has incorrect offset
    Define Window                   0  0x100  0x1000  -257  ${PRIV_ALL}
    Wait For Log Entry              MMUWindow has incorrect offset
    Write To Address By DMA         ${DMA_ADDR}  0x200  0x0
    Wait For Log Entry              The window at index .* match the address, but isn't validated sucesfully  treatAsRegex=true

    Define Window                   0  0x100  0x1000  0  ${PRIV_NONE}
    Define Window                   1  0x1000  0x1004  0  ${PRIV_NONE}
    Define Window                   1  0xFFF  0x1004  0  ${PRIV_NONE}
    Wait For Log Entry              MMUWindows .* overlap each other  treatAsRegex=true
    Define Window                   1  0x000  0x101  0  ${PRIV_NONE}
    Wait For Log Entry              MMUWindows .* overlap each other  treatAsRegex=true

Restrict Access From Two Peripherals
    Create Platform
    Execute Command                 machine LoadPlatformDescriptionFromString "dma1: SimpleDMA @ { sysbus 0x48000000; iommu0 1 }"
    Create Log Tester               0
    Execute Command                 logLevel -1

    Define Window                   0  0x0000  0x1000  0x0  ${PRIV_NONE}
    Define Window                   1  0x1000  0x2000  0x0  ${PRIV_ALL}
    Write Range With Doublewords    0x1000  0x1FFF  0x01234567    

    Write To Address By DMA         ${DMA_ADDR}  0x0FFC  0x0
    Wait For Log Entry              IOMMU fault at 0xFFC
    
    Write To Address By DMA         ${DMA_ADDR}  0x1000  0x0
    Should Not Be In Log            IOMMU fault at 0x1000

    Write To Address By DMA         0x48000000  0x0FFC  0x0
    Wait For Log Entry              IOMMU fault at 0xFFC

    Write To Address By DMA         0x48000000  0x1000  0x0
    Should Not Be In Log            IOMMU fault at 0x1000
