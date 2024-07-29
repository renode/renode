*** Keywords ***
Create Machine
    ${TEST_DIR}=                    Evaluate  r"${CURDIR}".replace(" ", "\\ ")

    Execute Command                 mach create
    Execute Command                 i @${TEST_DIR}/PeripheralWithAliases.cs
    Create Log Tester               0

Create Test Peripheral
    [Arguments]                     ${parameters}=${EMPTY}
    Execute Command                 machine LoadPlatformDescriptionFromString "test: Mocks.PeripheralWithAliases @ sysbus {${parameters}}"

*** Test Cases ***
Should Create Peripheral Without Using Aliases
    Create Machine
    Create Test Peripheral          normalParameter: 5; mode: PeripheralModes.Mode1; aliasedParameter: 10
    Wait For Log Entry              normalParameter = 5
    Wait For Log Entry              mode = Mode1
    Wait For Log Entry              aliasedParameter = 10
    Wait For Log Entry              aliasedParameterDefault = 0

Should Create Peripheral Using Aliases
    Create Machine
    Create Test Peripheral          normalParameter: -12; mode: Modes.Mode2; ctorAlias: 100; ctorAliasDefault: 15
    Wait For Log Entry              normalParameter = -12
    Wait For Log Entry              mode = Mode2
    Wait For Log Entry              aliasedParameter = 100
    Wait For Log Entry              aliasedParameterDefault = 15

Should Throw Recoverable Exception When Using Alias And Argument Name At The Same Time
    Create Machine
    Run Keyword And Expect Error    *Ambiguous choice between aliased and normal argument name*
    ...                             Create Test Peripheral  normalParameter: -12; mode: Modes.Mode2; ctorAlias: 100; aliasedParameter: 100

Should Warn When Using Aliases
    Create Machine
    Create Test Peripheral          normalParameter: 5; mode: Modes.Mode1; ctorAlias: 10; ctorAliasDefault: 15
    Wait For Log Entry              Using alias 'Modes' for type 'PeripheralModes'
    Wait For Log Entry              Using alias 'ctorAlias' for parameter 'aliasedParameter'
    Should Not Be In Log            Using alias 'ctorAliasDefault' for parameter 'aliasedParameterDefault'

Should Not Accept Invalid Aliases
    Create Machine
    Run Keyword And Expect Error    *Could not find corresponding attribute for parameter 'aliasedParameter'*
    ...                             Create Test Peripheral  normalParameter: 5; mode: Modes.Mode1; invalidParameter: 10
