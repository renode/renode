*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${PLATFORM}=     SEPARATOR=
...  """                                                        ${\n}
...  simple: SimplePeripheral @ sysbus 0x0                      ${\n}
...  """

*** Test Cases ***
Should Compile Simple Peripheral
        # Escape space in windows path
        ${TEST_DIR}=             Evaluate  r"${CURDIR}".replace(" ", "\\ ")
        Execute Command          include @${TEST_DIR}${/}SimplePeripheral.cs

        Execute Command          mach create
        Execute Command          machine LoadPlatformDescriptionFromString ${PLATFORM}

        ${r}=  Execute Command   sysbus ReadDoubleWord 0x4
        Should Be Equal As Numbers   ${r}  0x0

        ${r}=  Execute Command   sysbus ReadDoubleWord 0x8
        Should Be Equal As Numbers   ${r}  0x0

        Execute Command          sysbus WriteDoubleWord 0x0 0x147

        ${r}=  Execute Command   sysbus ReadDoubleWord 0x4
        Should Be Equal As Numbers   ${r}  0x28e

        ${r}=  Execute Command   sysbus ReadDoubleWord 0x8
        Should Be Equal As Numbers   ${r}  5
