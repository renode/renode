*** Keywords **

Create Platform
             Execute Command          mach create
             Execute Command          using sysbus
             Execute Command          machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32gc\\"; timeProvider: empty }"
             Execute Command          machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
             Execute Command          machine LoadPlatformDescriptionFromString "uart: UART.LiteX_UART @ sysbus 0x2000"
             Execute Command          machine LoadPlatformDescriptionFromString "radio: Wireless.NRF52840_Radio @ sysbus 0x3000"

Should Throw Python Syntax Exception
             [Arguments]    ${command}
    ${out}=  Run Keyword And Expect Error  KeywordException:*
             ...                      Execute Command          ${command}
             Should Contain           ${out}      [FatalError] unexpected EOF while parsing (Line 1, Column 9)

*** Test Cases ***

Should Return Syntax Error
             Create Platform

             # BlockPythonEngine
             Should Throw Python Syntax Exception
             ...                      cpu AddHook 0xC0FFEE "if error"

             # InterruptPythonEngine
             Should Throw Python Syntax Exception
             ...                      cpu AddHookAtInterruptBegin "if error"

             # BusPeripheralsHooksPythonEngine
             Should Throw Python Syntax Exception
             ...                      sysbus SetHookAfterPeripheralRead uart "if error"

             # WatchpointHookPythonEngine
             Should Throw Python Syntax Exception
             ...                      sysbus AddWatchpointHook 0xC0FFEE Byte Read "if error"

             # PacketInterceptionPythonEngine
             Execute Command          emulation CreateIEEE802_15_4Medium "wireless"
             Should Throw Python Syntax Exception
             ...                      wireless SetPacketHookFromScript radio "if error"

             # UartPythonEngine
             Should Throw Python Syntax Exception
             ...                      uart AddLineHook "foobar" "if error"

             # UserStatePythonEngine
             Should Throw Python Syntax Exception
             ...                      machine AddUserStateHook "foobar" "if error"

Should Abort On Runtime Error
             Create Platform
             Create Log Tester        1

             Execute Command          logLevel -1 cpu
             Execute Command          cpu InstallCustomInstructionHandlerFromString "11111111111111111111111100001011" "a = b"
             Execute Command          sysbus WriteDoubleWord 0x00000000 0xffffff0b
             Execute Command          cpu ExecutionMode SingleStepBlocking
             Execute Command          cpu PC 0x00000000

             Start Emulation
             Execute Command          cpu Step
             Wait For Log Entry       Python runtime error: name 'b' is not defined
             Wait For Log Entry       CPU abort detected, halting.
