*** Keywords ***
Prepare Machine
    Execute Command           using sysbus
    Execute Command           mach create "ARM"

    Execute Command           machine LoadPlatformDescriptionFromString "rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.Arm @ sysbus { cpuType: \\"cortex-a9\\" }"

    Execute Command           cpu PC 0x0
    Execute Command           cpu ExecutionMode SingleStepBlocking

Thumb State Should Be Equal
    [Arguments]  ${state}
    ${cpsr}=  Execute Command  cpu GetRegisterUnsafe 25
    ${t}=     Evaluate  bool(${cpsr.strip()} & (1<<5))
    Should Be Equal As Strings  ${t}  ${state}

Load Program
    # nop (ARM)
    Execute Command           sysbus WriteDoubleWord 0x00000000 0xe1a00000
    # blx 0xc
    Execute Command           sysbus WriteDoubleWord 0x00000004 0xfa000000
    # nop (ARM)
    Execute Command           sysbus WriteDoubleWord 0x00000008 0xe1a00000
    # 2x nop (Thumb)
    Execute Command           sysbus WriteDoubleWord 0x0000000c 0x46c046c0
    # nop; bx lr (Thumb)
    Execute Command           sysbus WriteDoubleWord 0x00000010 0x477046c0

*** Test Cases ***
Should Expose Thumb State In CPSR
    Prepare Machine
    Load Program

    Start Emulation
    PC Should Be Equal        0x00000000
    Thumb State Should Be Equal  False

    Execute Command           cpu Step 1
    PC Should Be Equal        0x00000004
    Thumb State Should Be Equal  False

    Execute Command           cpu Step 1
    PC Should Be Equal        0x0000000c
    Thumb State Should Be Equal  True

    Execute Command           cpu Step 1
    PC Should Be Equal        0x0000000e
    Thumb State Should Be Equal  True

    Execute Command           cpu Step 1
    PC Should Be Equal        0x00000010
    Thumb State Should Be Equal  True

    Execute Command           cpu Step 1
    PC Should Be Equal        0x000000012
    Thumb State Should Be Equal  True

    Execute Command           cpu Step 1
    PC Should Be Equal        0x00000008
    Thumb State Should Be Equal  False
