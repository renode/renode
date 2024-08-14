*** Variables ***
${starting_pc}                  0x1000

*** Keywords ***
Create Machine
    Execute Command             using sysbus
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescriptionFromString 'clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x02000000 { frequency: 1000000 }'
    Execute Command             machine LoadPlatformDescriptionFromString 'cpu: CPU.RiscV32 @ sysbus { cpuType: "rv32ic"; timeProvider: clint }'
    Execute Command             machine LoadPlatformDescriptionFromString 'clint: { [0,1] -> cpu@[3,7] }'
    Execute Command             machine LoadPlatformDescriptionFromString 'mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x1000000 }'

    Execute Command             cpu PerformanceInMips 1
    Execute Command             cpu PC ${starting_pc}
    Execute Command             cpu SetRegister 1 0x02004000  # address of MTimeCmpHart0Lo register
    Execute Command             cpu SetRegister 3 0x02004004  # address of MTimeCmpHart0Hi register

    Execute Command             cpu SetHookAtBlockEnd "self.DebugLog('block ended: ' + 'PC '+ str(self.PC))"
    Execute Command             cpu SetHookAtBlockBegin "self.DebugLog('block started: ' + 'PC '+ str(self.PC))"

    # setting compare value surrounded by nop instructions
    Execute Command             sysbus WriteDoubleWord 0x1000 0x00000013 # nop
    Execute Command             sysbus WriteDoubleWord 0x1004 0x00000013 # nop
    # set Compare to the value that is in x2 register
    Execute Command             sysbus WriteDoubleWord 0x1008 0x0020A023 # sw x2, 0(x1)
    Execute Command             sysbus WriteDoubleWord 0x100C 0x0001A023 # sw x0, 0(x3)
    Execute Command             sysbus WriteDoubleWord 0x1010 0x00000013 # nop
    Execute Command             sysbus WriteDoubleWord 0x1014 0x00000013 # nop
    Execute Command             sysbus WriteDoubleWord 0x1018 0x00000013 # nop
    Execute Command             sysbus WriteDoubleWord 0x101C 0x00000013 # nop
    Execute Command             sysbus WriteDoubleWord 0x1020 0x00000013 # nop
    Execute Command             sysbus WriteDoubleWord 0x1024 0x00000013 # nop
    Execute Command             sysbus WriteDoubleWord 0x1028 0x00000013 # nop
    Execute Command             sysbus WriteDoubleWord 0x102C 0x00000013 # nop

    Create Log Tester           0.01  defaultPauseEmulation=true
    Execute Command             logLevel -1

*** Test Cases ***
Should Tick Between Chained Blocks
    Create Machine
    Execute Command             cpu MaximumBlockSize 1
    Execute Command             cpu SetRegister 2 5  # new Compare value = 5

    Execute Command             emulation RunFor "0.000012"
    Wait For Log Entry          block ended: PC 0x1014  timeout=0
    Wait For Log Entry          IRQ  timeout=0
    Wait For Log Entry          block started: PC 0x1014  timeout=0

Should Tick In The Same Block
    Create Machine
    Execute Command             cpu MaximumBlockSize 8
    Execute Command             cpu SetRegister 2 6  # new Compare value = 6

    Execute Command             emulation RunFor "0.000008"
    Wait For Log Entry          block started: PC 0x1000  timeout=0
    Should Not Be In Log        block ended: PC 0x100  timeout=0
    Should Not Be In Log        block ended: PC 0x101  timeout=0
    Wait For Log Entry          IRQ  timeout=0
    Wait For Log Entry          block ended: PC 0x1020  timeout=0

Should Tick At Exact Time
    Create Machine
    Execute Command             cpu MaximumBlockSize 8
    Execute Command             cpu SetRegister 2 6  # new Compare value = 6

    Execute Command             emulation RunFor "0.000005"
    Should Not Be In Log        IRQ  timeout=0
    Execute Command             emulation RunFor "0.000001"
    Wait For Log Entry          IRQ  timeout=0
