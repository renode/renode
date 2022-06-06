*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

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
        # Escape space in windows path
        ${TEST_DIR}=             Evaluate  r"${CURDIR}".replace(" ", "\\ ")
        Execute Command          include @${TEST_DIR}${/}SimplePeripheral.cs

        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${SIMPLE_PLATFORM}

        Use Peripheral

Should Compile Multiple Files Referencing Each Other
        # Escape space in windows path
        ${TEST_DIR}=             Evaluate  r"${CURDIR}".replace(" ", "\\ ")
        Execute Command          include @${TEST_DIR}${/}ReferencedType.cs
        Execute Command          EnsureTypeIsLoaded "Antmicro.Renode.Peripherals.ReferencedType"
        Execute Command          include @${TEST_DIR}${/}ReferencingPeripheral.cs

        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${COMPLEX_PLATFORM}

        Use Peripheral

EnsureTypeIsLoaded Should Throw Type Not Found
        ${TEST_TYPE}             SetVariable    Antmicro.NotExistingType
        Run Keyword And Expect Error    *Given type ${TEST_TYPE} was not found*    Execute Command         EnsureTypeIsLoaded "${TEST_TYPE}"
