*** Variables ***
${SIMPLE_PLATFORM}=     SEPARATOR=
...  """                                                        ${\n}
...  simple: SimplePeripheral @ sysbus 0x0                      ${\n}
...  """

${COMPLEX_PLATFORM}=     SEPARATOR=
...  """                                                        ${\n}
...  simple: ReferencingPeripheral @ sysbus 0x0                 ${\n}
...  """

*** Keywords ***
Use Peripheral
        ${r}=  Execute Command   sysbus ReadDoubleWord 0x4
        Should Be Equal As Numbers   ${r}  0x0

        ${r}=  Execute Command   sysbus ReadDoubleWord 0x8
        Should Be Equal As Numbers   ${r}  0x0

        Execute Command          sysbus WriteDoubleWord 0x0 0x147

        ${r}=  Execute Command   sysbus ReadDoubleWord 0x4
        Should Be Equal As Numbers   ${r}  0x28e

        ${r}=  Execute Command   sysbus ReadDoubleWord 0x8
        Should Be Equal As Numbers   ${r}  5

*** Test Cases ***
Should Compile Simple Peripheral
        Execute Command          include "${CURDIR}/SimplePeripheral.cs"

        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${SIMPLE_PLATFORM}

        Use Peripheral

# We load dynamically compiled assemblies right away after the compilation,
# so type dependencies can be resolved automatically between separate assemblies.
# In the past we had a call to 'EnsureTypeIsLoaded "Antmicro.Renode.Peripherals.ReferencedType"'.
# 'EnsureTypeIsLoaded' is no longer necessary when files are referencing each other,
# but can still be called explicitly if needed (e.g. there is no reference to the type in any of the loaded libraries).
# To test both cases (with and without 'EnsureTypeIsLoaded') we would need to have a separate robot file
# and to run this test in a different process to make it isolated, because in .NET Framework
# there is no way to unload an individual assembly without unloading all of the application domains that contain it.
# See: https://github.com/dotnet/docs/blob/376d4347ab1d83256c81d2427051e6ff705bcd30/docs/standard/assembly/load-unload.md
# It isn't worth the effort, so legacy command was just removed.
Should Compile Multiple Files Referencing Each Other
        Execute Command          include "${CURDIR}/ReferencedType.cs"
        Execute Command          include "${CURDIR}/ReferencingPeripheral.cs"

        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${COMPLEX_PLATFORM}

        Use Peripheral

EnsureTypeIsLoaded Should Throw Type Not Found
        ${TEST_TYPE}             SetVariable    Antmicro.NotExistingType
        Run Keyword And Expect Error    *Given type ${TEST_TYPE} was not found*    Execute Command         EnsureTypeIsLoaded "${TEST_TYPE}"
