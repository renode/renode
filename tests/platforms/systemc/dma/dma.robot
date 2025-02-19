*** Variables ***
${SYSTEMC_BINARY}                    @https://dl.antmicro.com/projects/renode/x64-systemc--dma.elf-s_943520-d936f6165ff706163a1d722c301a11a55672c365
${PLATFORM}=    SEPARATOR=
...  """                                                                        ${\n}
...  memory: Memory.MappedMemory @ sysbus 0x20000000                            ${\n}
...  ${SPACE*4}size: 0x1000000                                                  ${\n}
...                                                                             ${\n}
...  dma_systemc: SystemC.SystemCPeripheral @ sysbus <0x9000000, +0xffffff>     ${\n}
...  ${SPACE*4}address: "127.0.0.1"                                             ${\n}
...  ${SPACE*4}timeSyncPeriodUS: 5000                                           ${\n}
...  """

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus.dma_systemc SystemCExecutablePath ${SYSTEMC_BINARY}

Memory Should Be Equal To
    [Arguments]                     ${address}  ${value}
    ${res}=                         Execute Command  sysbus ReadByte ${address}
    Should Be Equal As Numbers      ${res}  ${value}

*** Test Cases ***
Should Perform Memory-To-Memory Transfer
    [Tags]                          skip_windows    skip_osx   skip_host_arm
    Create Machine
    Start Emulation

    # Initialize memory
    Execute Command                 sysbus.memory WriteString 0 "Hello"

    # Make sure memory destination is initialized to 0
    Memory Should Be Equal To       0x20000010  0
    Memory Should Be Equal To       0x20000011  0
    Memory Should Be Equal To       0x20000012  0
    Memory Should Be Equal To       0x20000013  0
    Memory Should Be Equal To       0x20000014  0

    # Set source address register in dma_systemc.
    Execute Command                 sysbus WriteDoubleWord 0x9000004 0x20000000

    # Set destination address register in dma_systemc.
    Execute Command                 sysbus WriteDoubleWord 0x9000008 0x20000010

    # Set data length register (in bytes) in dma_systemc.
    Execute Command                 sysbus WriteDoubleWord 0x900000C 5

    # Start memory-to-memory transfer in dma_systemc
    Execute Command                 sysbus WriteDoubleWord 0x9000010 0x1

    # Signal "bus free" to notify DMAC it can use the bus now.
    Execute Command                 sysbus.dma_systemc OnGPIO 2 True

    # Verify the memory was copied correctly.
    # "H"
    Memory Should Be Equal To       0x20000010  0x48
    # "e"
    Memory Should Be Equal To       0x20000011  0x65
    # "l"
    Memory Should Be Equal To       0x20000012  0x6C
    # "l"
    Memory Should Be Equal To       0x20000013  0x6C
    # "o"
    Memory Should Be Equal To       0x20000014  0x6F
