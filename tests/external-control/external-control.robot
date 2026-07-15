*** Settings ***
Library        Process
Library        OperatingSystem
Test Setup     Custom Test Setup
Test Teardown  Custom Test Teardown


*** Variables ***
${EXTERNAL_CONTROL_DIR}            ${CURDIR}/../../tools/external_control_client
# This will be overriden by the test setup
${BUILD_DIR}                       ${EXTERNAL_CONTROL_DIR}/build
${PORT}                            3344


*** Keywords ***
Custom Test Setup
    Test Setup
    ${temp}=                       Allocate Temporary Directory  external_control
    Set Global Variable            ${BUILD_DIR}  ${temp}
    Execute Command                emulation CreateExternalControlServer "server" ${PORT}

Custom Test Teardown
    Test Teardown

    Return From Keyword If         'skipped' in @{TEST TAGS}

    IF  $TEST_STATUS == 'FAIL'
        ${test_name}=              Get Sanitized Test Name
        ${out_dir}=                Set Variable  ${RESULTS_DIRECTORY}/external-control/${test_name}

        Copy Directory             ${BUILD_DIR}  ${out_dir}
        Log To Console             !!!!! External control client build directory saved to "${out_dir}"

    ELSE
        Remove Directory           ${BUILD_DIR}  recursive=${True}
    END

Build Sample
    [Arguments]                    ${app}

    ${r}=                          Run Process  cmake
    ...                            -DAPP_NAME\=${app}
    ...                            -DAPP_SOURCES_DIR\=${EXTERNAL_CONTROL_DIR}/examples/${app}
    ...                            -DAPP_NON_INTERACTIVE\=ON
    ...                            -S ${EXTERNAL_CONTROL_DIR}
    ...                            -B ${BUILD_DIR}

    Should Be Equal As Integers    ${r.rc}    0  msg=cmake failed: ${r.stderr}

    ${r}=                          Run Process  cmake  --build  ${BUILD_DIR}
    Should Be Equal As Integers    ${r.rc}    0  msg=cmake failed: ${r.stderr}

Start Sample
    [Arguments]                    ${app}  @{args}
    ${proc}=                       Start Process  ${BUILD_DIR}/${app}  @{args}
    [Return]                       ${proc}

Execute Sample
    [Arguments]                    ${app}  @{args}
    ${proc}=                       Start Sample  ${app}  @{args}

    ${r}=                          Wait For Process  ${proc}
    Should Be Equal As Integers    ${r.rc}  0  msg=app '${app}' failed exitted with code ${r.rc}, stderr: ${r.stderr}
    [Return]                       ${r}


*** Test Cases ***
Should Run RunFor Sample
    [Tags]                         basic-tests  skip_windows

    Build Sample                   run_for

    Execute Sample                 run_for  ${PORT}  500ms  3
    ${time}=                       Execute Command  emulation GetTimeSourceInfo
    Should Contain                 ${time}  Elapsed Virtual Time: 00:00:01.500000000

Should Run Sysbus Sample
    [Tags]                         skip_windows

    Execute Command                mach create "machine"
    Execute Command                machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x100 }"

    Build Sample                   sysbus
    FOR    ${offset}    IN RANGE    0  0x10  0x8
        ${r}=                          Execute Sample  sysbus  ${PORT}  machine  mem  ${offset}
        ${val}=                        Execute Command  sysbus ReadQuadWord ${offset}

        Should Be Equal As Integers    ${val}  0xAABBCCDDEEFF8899

        ${offset_hex}=                 Convert To Hex  ${offset}
        Should Contain                 ${r.stderr}  (CONTEXT 'machine.mem' @ 0x${offset})
    END

Should Run ADC Sample
    [Tags]                         skip_windows

    Execute Command                mach create "machine"
    Execute Command                machine LoadPlatformDescriptionFromString "adc: Analog.CAES_ADC @ sysbus 0x0"

    Build Sample                   adc

    @{voltages}=                   Create List  13  100  254  1000
    FOR    ${voltage}    IN    @{voltages}
        Execute Sample                 adc  ${PORT}  machine  adc  ${voltage}uv
        ${val}=                        Execute Command  adc GetADCValue 0
        Should Be Equal As Integers    ${val}    ${voltage}
    END

Should Run GPIO Sample
    [Tags]                         skip_windows

    Execute Command                mach create "machine"
    Execute Command                machine LoadPlatformDescriptionFromString "gpio: GPIOPort.NPCX_GPIO @ sysbus 0x0"
    Create Log Tester              5

    Build Sample                   gpio

    FOR    ${pin}    IN RANGE    0  8
        Execute Sample                 gpio  ${PORT}  machine  gpio  ${pin}  true

        ${register}=                   Execute Command  gpio ReadByte 0x1  # Read the data input register
        Should Be True                 ${register.strip()} & (1 << ${pin}) == (1 << ${pin})

        Execute Sample                 gpio  ${PORT}  machine  gpio  ${pin}  false

        ${register}=                   Execute Command  gpio ReadByte 0x1  # Read the data input register
        Should Be True                 ${register.strip()} & (1 << ${pin}) != (1 << ${pin})
    END

    ${proc}=                       Start Sample  gpio  ${PORT}  machine  gpio  0  event
    # Wait for sample to setup the callback. Do not start the emulation here as otherwise
    # the sample will not be able to issue the "run for" command.
    Wait For Log Entry             Executing RunFor  startEmulation=false

    Execute Command                gpio WriteByte 0x2 0xF  # Set all pins as output
    Execute Command                gpio WriteByte 0x0 0x1  # Trigger a GPIO change

    ${r}=                          Wait For Process  ${proc}
    Should Be Equal As Integers    ${r.rc}  0  msg=app failed: ${r.stderr}

    Should Contain                 ${r.stdout}  machine: GPIO #0 in gpio set
