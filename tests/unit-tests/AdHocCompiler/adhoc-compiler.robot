*** Variables ***
${SIMPLE_PLATFORM}=     SEPARATOR=
...  """                                                        ${\n}
...  simple: SimplePeripheral @ sysbus 0x0                      ${\n}
...  """

${COMPLEX_PLATFORM}=     SEPARATOR=
...  """                                                        ${\n}
...  simple: ReferencingPeripheral @ sysbus 0x0                 ${\n}
...  """

${UNSAFE_PLATFORM}=     SEPARATOR=
...  """                                                        ${\n}
...  simple: UnsafePeripheral @ sysbus 0x0                      ${\n}
...  """

# SimplePeripheral2 to avoid assembly reuse because all test cases run in the same Renode instance.
# See the comment above `Should Compile Multiple Files Referencing Each Other` for more details.
${SIMPLE_PLATFORM_WITH_PREINIT}=     SEPARATOR=
...  """                                                        ${\n}
...  simple: SimplePeripheral2 @ sysbus 0x0                     ${\n}
...  ${SPACE*4}preinit:                                         ${\n}
...  ${SPACE*8}include '${CURDIR}/SimplePeripheral2.cs'         ${\n}
...  """

# Init is used because dependency cycles are not allowed in platform descriptions.
${MUTUALLY_REFERENCING_PLATFORM_WITH_PREINIT}=     SEPARATOR=
...  """                                                                                                            ${\n}
...  peri1: MutuallyReferencingPeripheral1 @ sysbus 0x0                                                             ${\n}
...  ${SPACE*4}Other: peri2                                                                                         ${\n}
...  peri2: MutuallyReferencingPeripheral2 @ sysbus 0x100                                                           ${\n}
...  ${SPACE*4}init:                                                                                                ${\n}
...  ${SPACE*8}Other peri1                                                                                          ${\n}
...  sysbus:                                                                                                        ${\n}
...  ${SPACE*4}preinit add:                                                                                         ${\n}
...  ${SPACE*8}include '${CURDIR}/MutuallyReferencingPeripheral1.cs' '${CURDIR}/MutuallyReferencingPeripheral2.cs'  ${\n}
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

Use Nested Peripheral
        ${r}=  Execute Command   sysbus ReadDoubleWord 0x10c
        Should Be Equal As Numbers   ${r}  1

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
Should Compile Multiple Files With One Referencing The Other
        Execute Command          include "${CURDIR}/ReferencedType.cs"
        Execute Command          include "${CURDIR}/ReferencingPeripheral.cs"

        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${COMPLEX_PLATFORM}

        Use Peripheral

Should Compile Unsafe Peripheral
        Execute Command          include "${CURDIR}/UnsafePeripheral.cs"

        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${UNSAFE_PLATFORM}

        Use Peripheral

Should Compile Simple Peripheral Through Preinit
        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${SIMPLE_PLATFORM_WITH_PREINIT}

        Use Peripheral

Should Compile Two Peripherals Referencing Each Other Through Preinit
        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${MUTUALLY_REFERENCING_PLATFORM_WITH_PREINIT}

        Execute Command          sysbus WriteDoubleWord 0x0 0x859
        Execute Command          sysbus WriteDoubleWord 0x4 0x314

        ${r}=  Execute Command   sysbus ReadDoubleWord 0x100
        Should Be Equal As Numbers   ${r}  0x314
        ${r}=  Execute Command   sysbus ReadDoubleWord 0x104
        Should Be Equal As Numbers   ${r}  0x859

Should Compile Simple Peripherals Through Preinit In Repl File With Relative Path Lookup
        Execute Command         include "${CURDIR}/adhoc-compiler.repl"

        Use Peripheral
        Use Nested Peripheral

Should Find Simple Peripherals Through Preinit In Repl File With Origin Path Lookup
        # If this test case runs after one that has already used SimplePeripheral3.cs, like
        # `Should Compile Simple Peripherals Through Preinit In Repl File With Relative Path Lookup`, then
        # the preinit block will not actually compile the peripheral as it will have already been compiled,
        # but the important part of this test is to test the $ORIGIN-based path lookup
        Execute Script          ${CURDIR}/adhoc-compiler.resc

        Use Peripheral
        Use Nested Peripheral

EnsureTypeIsLoaded Should Throw Type Not Found
        ${TEST_TYPE}             SetVariable    Antmicro.NotExistingType
        Run Keyword And Expect Error    *Given type ${TEST_TYPE} was not found*    Execute Command         EnsureTypeIsLoaded "${TEST_TYPE}"
