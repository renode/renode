*** Variables ***
${SYSTEMC_BINARY}                    @https://dl.antmicro.com/projects/renode/x64-systemc--test-synchronization.elf-s_606984-4b970b9b9da67d412220cc827634accb89619139
${EXECUTE_IN_LOCK_PERIPHERAL}        @tests/platforms/systemc/test-synchronization/ExecuteInLockPeripheral.cs
${PLATFORM}=     SEPARATOR=
...  """                                                                            ${\n}
...  test: Test.ExecuteInLockPeripheral @ sysbus 0x1000000                          ${\n}
...                                                                                 ${\n} 
...  writer_systemc: SystemC.SystemCPeripheral @ sysbus <0x9000000, +0xffffff>      ${\n}
...  ${SPACE*4}address: "127.0.0.1"                                                       ${\n}
...  ${SPACE*4}timeSyncPeriodUS: 5000                                                     ${\n}
...  """ 

*** Test Cases ***
Should Not Deadlock Writing To ExecuteInLockPeripheral
    [Tags]                          skip_windows    skip_osx    skip_host_arm
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 include ${EXECUTE_IN_LOCK_PERIPHERAL}
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM} 
    Execute Command                 sysbus.writer_systemc SystemCExecutablePath ${SYSTEMC_BINARY}
    Create Log Tester               1
    Start Emulation

    Wait For Log Entry              Got write request with value 0xAB
