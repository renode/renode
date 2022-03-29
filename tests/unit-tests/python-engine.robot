*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Keywords **

Load Platform
            Execute Command           include @scripts/single-node/nrf52840.resc

Should Throw Python Syntax Exception
             [Arguments]    ${command}
    ${out}=  Run Keyword And Expect Error  KeywordException:*
             ...                      Execute Command          ${command}
             Should Contain           ${out}      [FatalError] unexpected EOF while parsing (Line 1, Column 9)

*** Test Cases ***

Should Return Syntax Error
             Load Platform

             # BlockPythonEngine
             Should Throw Python Syntax Exception
             ...                      cpu AddHook 0xC0FFEE "if error"

             # InterruptPythonEngine
             Should Throw Python Syntax Exception
             ...                      cpu AddHookAtInterruptBegin "if error"

             # BusPeripheralsHooksPythonEngine
             Should Throw Python Syntax Exception
             ...                      sysbus SetHookAfterPeripheralRead uart0 "if error"

             # WatchpointHookPythonEngine
             Should Throw Python Syntax Exception
             ...                      sysbus AddWatchpointHook 0xC0FFEE Byte Read "if error"

             # PacketInterceptionPythonEngine
             Execute Command          emulation CreateWirelessMedium "wireless"
             Should Throw Python Syntax Exception
             ...                      wireless SetPacketHookFromScript radio "if error"

             # UartPythonEngine
             Should Throw Python Syntax Exception
             ...                      uart0 AddLineHook "foobar" "if error"

             # UserStatePythonEngine
             Should Throw Python Syntax Exception
             ...                           machine AddUserStateHook "foobar" "if error"

Should Return Runtime Error
             Create Log Tester        1

             Execute Command          mach create
             Execute Command          machine LoadPlatformDescriptionFromString "cpu: CPU.Arm @ sysbus { cpuType: \\"cortex-a9\\" }"
             Execute Command          machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
             Execute Command          sysbus AddWatchpointHook 0x1000 Byte Read "a = b"
             Start Emulation
             Wait For Log Entry       Python runtime error: name 'b' is not defined
