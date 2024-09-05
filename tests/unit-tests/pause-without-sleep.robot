*** Variables ***
${URI}                   @https://dl.antmicro.com/projects/renode

${PLATFORM}=    SEPARATOR=
...  """                                                                ${\n}
...  mem: Memory.MappedMemory @sysbus 0x0                               ${\n}
...  ${SPACE*4}size: 0x1000                                             ${\n}
...                                                                     ${\n}
...  cpu: CPU.RiscV32 @ sysbus                                          ${\n}
...  ${SPACE*4}cpuType: "rv32imac_zicsr_zifencei"                       ${\n}
...  ${SPACE*4}privilegedArchitecture: PrivilegedArchitecture.Priv1_10  ${\n}
...  """                                                                ${\n}


*** Keywords ***
Create Machine
    Execute Command             using sysbus
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescriptionFromString ${PLATFORM}

    # Create loop
    # addi    s0, t2, 32
    Execute Command             sysbus WriteDoubleWord 0x0 0x02038413
    # addi    s0, t2, 32
    Execute Command             sysbus WriteDoubleWord 0x4 0x02038413
    # j       -8
    Execute Command             sysbus WriteDoubleWord 0x8 0xff9ff06f

    Execute Command             cpu PC 0x0

*** Test Cases ***
# This test verifies if Renode can be quickly paused when large quantum is set
Should Renode Pause In Short Time With Large Quantum Set
    # 10 seconds should be enough to pause the emulation
    [Timeout]                   10 seconds
    Create Machine

    Execute Command             emulation SetGlobalQuantum "1000000"
    Execute Command             start
    # wait few seconds to created larger difference between virtual and host time
    Sleep                       3s
    Execute Command             pause
