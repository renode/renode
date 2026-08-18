*** Variables ***
${PC}                                   0x80000000
${SYNCHRONIZATION_PERIPHERAL_ADDRESS}   0x40000000

*** Keywords ***
Create Basic Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "ddr: Memory.MappedMemory @ sysbus 0x80000000 { size: 0x80000000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "synchronizationPeripheral: Mocks.SynchronizationPeripheral @ sysbus ${SYNCHRONIZATION_PERIPHERAL_ADDRESS}"
    Create Log Tester               0
    Execute Command                 logLevel 0

Add CPU ${core}
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu_${core}: CPU.RiscV64 @ sysbus { timeProvider: empty; cpuType: \\"rv64gc\\"}"
    Execute Command                 cpu_${core} ExecutionMode SingleStep
    Execute Command                 cpu_${core} PC ${PC}
    Execute Command                 cpu_${core} SetRegister "A2" ${SYNCHRONIZATION_PERIPHERAL_ADDRESS}

*** Test Cases ***
Should Precisely Pause From MMIO While Another CPU Runs The Same Access
    Create Basic Machine
    Add CPU 0
    Add CPU 1
    Execute Command                 cpu_0 SetRegister "A3" ${{ord("A")}}
    Execute Command                 cpu_1 SetRegister "A3" ${{ord("B")}}

    ${code}=                        catenate  SEPARATOR=${\n}
    ...                             sw a3, 0(a2);
    ...                             j .;
    Execute Command                 cpu_0 AssembleBlock ${PC} """${code}"""
    Execute Command                 cpu_0 ExecutionMode Continuous
    Execute Command                 cpu_1 ExecutionMode Continuous
    Execute Command                 cpu_1 IsHalted true
    Create Terminal Tester          sysbus.synchronizationPeripheral  timeout=2

    Execute Command                 synchronizationPeripheral UnhaltCpuOnAccess "cpu_0" "cpu_1"
    Execute Command                 synchronizationPeripheral ReleaseCpuOnAccess "cpu_0" "cpu_1"
    Execute Command                 synchronizationPeripheral ReleaseCpuOnAccess "cpu_0" "cpu_0"
    Wait For Line On Uart           A  includeUnfinishedLine=true  pauseEmulation=true

    ${started}=                     Execute Command  emulation IsStarted
    Should Contain                  ${started}  False
    Execute Command                 synchronizationPeripheral ReleaseCpu "cpu_1"
