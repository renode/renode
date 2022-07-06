*** Keywords ***
Create Machine With Dummy Sensor
    [Arguments]     ${sensorName}
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "${sensorName}: Sensors.DummySensor @ sysbus <0x0, +0x4>"

Create Machine With Multiple Dummy Sensors
    [Arguments]     ${sensorName1}  ${sensorName2}
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "${sensorName1}: Sensors.DummySensor @ sysbus <0x0, +0x4>"
    Execute Command                             machine LoadPlatformDescriptionFromString "${sensorName2}: Sensors.DummySensor @ sysbus <0x4, +0x4>"

Should List Sensor In Environment Once
    [Arguments]     ${env}          ${sensorName}
    ${lines}=   Execute Command                 ${env} GetRegisteredSensorsNames
    ${result}=  Get Lines Containing String     ${lines}    ${sensorName}
    ${count}=   Get Line Count                  ${result}
    Should Be Equal As Integers                 ${count}    1

*** Test Cases ***
Should List Sensor Once
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    Should List Sensor In Environment Once      env1        machine-0:sysbus.dummySensor1

Should Set Temperature On Single Sensor
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             env1 Temperature 36.6
    Execute Command                             machine SetEnvironment env1
    ${temperature}=     Execute Command         sysbus.dummySensor1 Temperature
    Should Contain                              ${temperature}    36.6

Should Set Temperature On Single Sensor Twice
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             env1 Temperature 36.6
    Execute Command                             machine SetEnvironment env1
    ${temperature}=     Execute Command         sysbus.dummySensor1 Temperature
    Should Contain                              ${temperature}    36.6
    Execute Command                             env1 Temperature 38.1
    ${temperature}=     Execute Command         sysbus.dummySensor1 Temperature
    Should Contain                              ${temperature}    38.1

Should Set Temperature And Humidity On Single Sensor
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             env1 Temperature 36.6
    Execute Command                             env1 Humidity 89.5
    Execute Command                             machine SetEnvironment env1
    ${temperature}=     Execute Command         sysbus.dummySensor1 Temperature
    Should Contain                              ${temperature}    36.6
    ${humidity}=        Execute Command         sysbus.dummySensor1 Humidity
    Should Contain                              ${humidity}    89.5

Should List Sensor Once If Machine Was Added To Environment Twice
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    Execute Command                             machine SetEnvironment env1
    Should List Sensor In Environment Once      env1        machine-0:sysbus.dummySensor1

Should Update Sensor Once If Machine Was Added To Environment Twice
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    ${count}=    Execute Command                sysbus.dummySensor1 TemperatureUpdateCounter
    Should Contain                              ${count}    0x00000001
    Execute Command                             machine SetEnvironment env1
    ${count}=    Execute Command                sysbus.dummySensor1 TemperatureUpdateCounter
    Should Contain                              ${count}    0x00000001





Should List Two Sensors
    Create Machine With Multiple Dummy Sensors      dummySensor1    dummySensor2
    Execute Command                                 emulation CreateEnvironment "env1"
    Execute Command                                 machine SetEnvironment env1
    ${lines}=   Execute Command                     env1 GetRegisteredSensorsNames
    Should Contain                                  ${lines}    machine-0:sysbus.dummySensor1
    Should Contain                                  ${lines}    machine-0:sysbus.dummySensor2

Should Set Temperature After Machine Reset
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    Execute Command                             env1 Temperature 55.5
    Execute Command                             s
    Execute Command                             machine Reset   #Reset requires the machine to be started
    Execute Command                             p
    ${temperature}=    Execute Command          sysbus.dummySensor1 Temperature
    Should Contain                              ${temperature}    55.5

Should List Two Sensors In Different Environments
    Create Machine With Multiple Dummy Sensors      dummySensor1    dummySensor2
    Execute Command                                 emulation CreateEnvironment "env1"
    Execute Command                                 machine SetEnvironment env1
    Execute Command                                 emulation CreateEnvironment "env2"
    Execute Command                                 sysbus.dummySensor2 SetEnvironment env2
    Should List Sensor In Environment Once          env1        machine-0:sysbus.dummySensor1
    ${lines}=   Execute Command                     env1 GetRegisteredSensorsNames
    Should Not Contain                              ${lines}    machine-0:sysbus.dummySensor2

    Should List Sensor In Environment Once          env2        machine-0:sysbus.dummySensor2
    ${lines}=   Execute Command                     env2 GetRegisteredSensorsNames
    Should Not Contain                              ${lines}    machine-0:sysbus.dummySensor1

Should Set Temperature On Two Sensors In Different Environments
    Create Machine With Multiple Dummy Sensors      dummySensor1    dummySensor2
    Execute Command                                 emulation CreateEnvironment "env1"
    Execute Command                                 env1 Temperature 36.6
    Execute Command                                 machine SetEnvironment env1
    ${temperature}=    Execute Command              sysbus.dummySensor1 Temperature
    Should Contain                                  ${temperature}    36.6
    ${temperature}=    Execute Command              sysbus.dummySensor2 Temperature
    Should Contain                                  ${temperature}    36.6
    Execute Command                                 emulation CreateEnvironment "env2"
    Execute Command                                 env2 Temperature 40.5
    Execute Command                                 sysbus.dummySensor2 SetEnvironment env2
    ${temperature}=    Execute command              sysbus.dummySensor2 Temperature
    Should Contain                                  ${temperature}    40.5
    ${temperature}=    Execute Command              sysbus.dummySensor1 Temperature
    Should Contain                                  ${temperature}    36.6

Should Set Temperature On Two Sensors In Different Environments After Reset
    Create Machine With Multiple Dummy Sensors      dummySensor1    dummySensor2
    Execute Command                                 emulation CreateEnvironment "env1"
    Execute Command                                 env1 Temperature 36.6
    Execute Command                                 machine SetEnvironment env1
    ${temperature}=    Execute Command              sysbus.dummySensor1 Temperature
    Should Contain                                  ${temperature}    36.6
    ${temperature}=    Execute Command              sysbus.dummySensor2 Temperature
    Should Contain                                  ${temperature}    36.6
    Execute Command                                 emulation CreateEnvironment "env2"
    Execute Command                                 env2 Temperature 40.5
    Execute Command                                 sysbus.dummySensor2 SetEnvironment env2
    Execute Command                                 s
    Execute command                                 machine Reset
    Execute Command                                 p
    ${temperature}=    Execute command              sysbus.dummySensor2 Temperature
    Should Contain                                  ${temperature}    40.5
    ${temperature}=    Execute Command              sysbus.dummySensor1 Temperature
    Should Contain                                  ${temperature}    36.6





Should Set Temperature On Sensors Added After Registering An Environment
    Execute Command                             mach create
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             env1 Temperature 36.6
    Execute Command                             machine SetEnvironment env1
    Execute Command                             machine LoadPlatformDescriptionFromString "dummySensor1: Sensors.DummySensor @ sysbus <0x4, +0x4>"
    ${temperature}=     Execute Command         sysbus.dummySensor1 Temperature
    Should Contain                              ${temperature}    36.6

Should Move Sensors Between Environments
    Create Machine With Multiple Dummy Sensors      dummySensor1    dummySensor2
    Execute Command                                 emulation CreateEnvironment "env1"
    Execute Command                                 emulation CreateEnvironment "env2"

    Execute Command                                 machine SetEnvironment env1
    ${lines}=   Execute Command                     env1 GetRegisteredSensorsNames
    Should Contain                                  ${lines}    machine-0:sysbus.dummySensor1
    Should Contain                                  ${lines}    machine-0:sysbus.dummySensor2
    
    Execute Command                                 machine SetEnvironment env2
    ${lines}=   Execute Command                     env2 GetRegisteredSensorsNames
    Should Contain                                  ${lines}    machine-0:sysbus.dummySensor1
    Should Contain                                  ${lines}    machine-0:sysbus.dummySensor2
 
    ${lines}=   Execute Command                     env1 GetRegisteredSensorsNames
    Should Not Contain                              ${lines}    machine-0:sysbus.dummySensor1
    Should Not Contain                              ${lines}    machine-0:sysbus.dummySensor2

Should Move Sensor With The Machine
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             emulation CreateEnvironment "env2"
    Execute Command                             emulation CreateEnvironment "env3"
    Execute Command                             machine SetEnvironment env1
    Execute Command                             sysbus.dummySensor1 SetEnvironment env2
    Execute Command                             machine SetEnvironment env3
    ${lines}=   Execute Command                 env2 GetRegisteredSensorsNames
    Should Not Contain                          ${lines}    machine-0:sysbus.dummySensor1

Should Move Added Sensor Between Environments
    Execute Command                             mach create
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             emulation CreateEnvironment "env2"
    Execute Command                             machine SetEnvironment env1
    Execute Command                             machine LoadPlatformDescriptionFromString "dummySensor1: Sensors.DummySensor @ sysbus <0x0, +0x4>"
    Execute Command                             machine SetEnvironment env2

    ${lines}=   Execute Command                 env1 GetRegisteredSensorsNames
    Should Not Contain                          ${lines}    machine-0:sysbus.dummySensor1

    ${lines}=   Execute Command                 env2 GetRegisteredSensorsNames
    Should Contain                              ${lines}    machine-0:sysbus.dummySensor1





Should Not List Removed Sensor
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    Execute Command                             machine UnregisterFromParent sysbus.dummySensor1
    ${lines}=   Execute Command                 env1 GetRegisteredSensorsNames
    Should Not Contain                          ${lines}    machine-0:sysbus.dummySensor1

Should Not List Sensors From Removed Machine
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    Execute Command                             emulation RemoveMachine "machine-0"
    ${lines}=   Execute Command                 env1 GetRegisteredSensorsNames
    Should Not Contain                          ${lines}    machine-0:sysbus.dummySensor1

Should Not List Removed Machine
    Execute Command                             mach create
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    Execute Command                             emulation RemoveMachine "machine-0"
    ${lines}=   Execute Command                 env1 GetRegisteredMachineNames
    Should Not Contain                          ${lines}    machine-0

Should Not List Sensors From Removed Machine In Different Environment
    Create Machine With Multiple Dummy Sensors      dummySensor1    dummySensor2
    Execute Command                                 emulation CreateEnvironment "env1"
    Execute Command                                 emulation CreateEnvironment "env2"
    Execute Command                                 machine SetEnvironment env1
    Execute Command                                 sysbus.dummySensor2 SetEnvironment env2
    Execute Command                                 emulation RemoveMachine "machine-0"
    ${lines}=   Execute Command                     env2 GetRegisteredMachineNames
    Should Not Contain                              ${lines}    machine-0:sysbus.dummySensor2

Should Set Temperature After Sensor Removal
    Create Machine With Multiple Dummy Sensors      dummySensor1    dummySensor2
    Execute Command                                 emulation CreateEnvironment "env1"
    Execute Command                                 machine SetEnvironment env1
    Execute Command                                 machine UnregisterFromParent sysbus.dummySensor1
    Execute Command                                 env1 Temperature 55.5
    ${temperature}=     Execute Command             sysbus.dummySensor2 Temperature
    Should Contain                                  ${temperature}    55.5

Should Set Temperature On Readded Sensor
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    Execute Command                             env1 Temperature 55.5
    Execute Command                             machine UnregisterFromParent sysbus.dummySensor1
    Execute Command                             machine LoadPlatformDescriptionFromString "dummySensor1: Sensors.DummySensor @ sysbus <0x0, +0x4>"
    ${temperature}=     Execute Command         sysbus.dummySensor1 Temperature
    Should Contain                              ${temperature}    55.5

Should Serialize And Set Temperature On Single Sensor
    Create Machine With Dummy Sensor            dummySensor1
    Execute Command                             emulation CreateEnvironment "env1"
    Execute Command                             machine SetEnvironment env1
    Handle Hot Spot                             Serialize
    Execute Command                             mach set 0
    Execute Command                             env1 Temperature 55.5
    ${temperature}=     Execute Command         sysbus.dummySensor1 Temperature
    Should Contain                              ${temperature}    55.5
