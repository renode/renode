*** Settings ***
Test Setup                          Custom Test Setup
Test Teardown                       Custom Test Teardown
Library                             Process
Library                             OperatingSystem

*** Variables ***
${EXTERNAL_CONTROL_DIR}             ${CURDIR}/../../tools/external_control_client
# This will be overriden by the test setup
${BUILD_DIR}                        ${EXTERNAL_CONTROL_DIR}/build
${PORT}                             3344
${MEMORY_ADDRESS}                   0x1000

*** Keywords ***
Custom Test Setup
    Test Setup
    ${temp}=                        Allocate Temporary Directory  external_control
    Set Global Variable             ${BUILD_DIR}  ${temp}
    Execute Command                 emulation CreateExternalControlServer "server" ${PORT}

Custom Test Teardown
    Test Teardown

    Return From Keyword If          'skipped' in @{TEST TAGS}

    ${proc}=                        Terminate Process
    IF  ${{ $proc is not None }}
        Log                             Sample stdout:${\n}${proc.stdout}
        Log                             Sample stderr:${\n}${proc.stderr}
    END

    IF  $TEST_STATUS == 'FAIL'
        ${test_name}=                   Get Sanitized Test Name
        ${out_dir}=                     Set Variable  ${RESULTS_DIRECTORY}/external-control/${test_name}

        Copy Directory                  ${BUILD_DIR}  ${out_dir}
        Log To Console                  !!!!! External control client build directory saved to "${out_dir}"
    ELSE
        Remove Directory                ${BUILD_DIR}  recursive=${True}
    END

Build Sample
    [Arguments]                     ${app}

    ${r}=                           Run Process  cmake
    ...                             -DAPP_NAME\=${app}
    ...                             -DAPP_SOURCES_DIR\=${EXTERNAL_CONTROL_DIR}/examples/${app}
    ...                             -DAPP_NON_INTERACTIVE\=ON
    ...                             -DRENODE_API_SANITIZERS\=%{RENODE_TESTS_SANITIZERS=ON}
    ...                             -S ${EXTERNAL_CONTROL_DIR}
    ...                             -B ${BUILD_DIR}

    Should Be Equal As Integers     ${r.rc}  0  msg=cmake failed: ${r.stderr}

    ${r}=                           Run Process  cmake  --build  ${BUILD_DIR}
    Should Be Equal As Integers     ${r.rc}  0  msg=cmake failed: ${r.stderr}

Start Sample
    [Arguments]                     ${app}  @{args}
    ${proc}=                        Start Process  ${BUILD_DIR}/${app}  @{args}
    [Return]                        ${proc}

Execute Sample
    [Arguments]                     ${app}  @{args}
    ${proc}=                        Start Sample  ${app}  @{args}

    ${r}=                           Wait For Process  ${proc}
    Log                             Sample stdout:${\n}${r.stdout}
    Should Be Equal As Integers     ${r.rc}  0  msg=app '${app}' failed exitted with code ${r.rc}, stderr: ${r.stderr}
    [Return]                        ${r}

*** Test Cases ***
Should Run RunFor Sample
    [Tags]                          basic-tests  exclude_windows

    Build Sample                    run_for

    ${r}=                           Execute Sample  run_for  ${PORT}  500ms  3
    ${time}=                        Execute Command  emulation GetTimeSourceInfo
    Should Contain                  ${time}  Elapsed Virtual Time: 00:00:01.500000000

    Should Contain                  ${r.stdout}  Elapsed virtual time 00:00:00.500000
    Should Contain                  ${r.stdout}  Elapsed virtual time 00:00:01.000000
    Should Contain                  ${r.stdout}  Elapsed virtual time 00:00:01.500000

    Start Emulation
    Run Keyword And Expect Error    *This action is not available when emulation is already started*
    ...                             Execute Sample  run_for  ${PORT}  100ms  1

Should Run Sysbus Sample
    [Tags]                          exclude_windows

    Execute Command                 mach create "machine"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x100 }"

    Build Sample                    sysbus
    FOR  ${offset}  IN RANGE  0  0x10  0x8
        ${r}=                           Execute Sample  sysbus  ${PORT}  machine  mem  ${offset}
        ${val}=                         Execute Command  sysbus ReadQuadWord ${offset}

        Should Be Equal As Integers     ${val}  0xAABBCCDDEEFF8899

        ${offset_hex}=                  Convert To Hex  ${offset}
        Should Contain                  ${r.stderr}  (CONTEXT 'machine.mem' @ 0x${offset})
    END

Should Run ADC Sample On ADC Channel
    [Tags]                          exclude_windows

    Execute Command                 mach create "machine"
    Execute Command                 machine LoadPlatformDescriptionFromString "adc: Analog.CAES_ADC @ sysbus 0x0"

    Build Sample                    adc

    ${channel_count}=               Execute Command  adc ADCChannelCount
    ${channel_count}=               Evaluate  int(${channel_count.strip()})

    @{voltages}=                    Create List  13  100  254  1000
    FOR  ${voltage}  IN  @{voltages}
        ${r}=                           Execute Sample  adc  ${PORT}  machine  adc  0  ${voltage}uv
        ${volts}=                       Execute Command  adc.adc-channel0 Volts
        Should Be Equal As Integers     ${{1e6 * ${volts}}}  ${voltage}
        Should Contain                  ${r.stdout}  [INFO] # of channels: ${channel_count}
    END

Should Run ADC Sample On Potentiometer
    [Tags]                          skip_windows
    Set Test Variable               ${MAX_POTENTIOMETER}  3300

    Build Sample                    adc
    Execute Command                 include @scripts/multi-node/ramn.resc
    Execute Command                 mach set "ECUC"

    FOR  ${voltage}  IN  0  825  1650  1980  3300
        Execute Sample                  adc  ${PORT}  ECUC  adc1  6  ${voltage}mV
        ${val}=                         Execute Command  adc1.brake Percentage
        Should Be Equal As Integers     ${val}  ${{100 * ${voltage} / ${MAX_POTENTIOMETER}}}
    END

    ${expected_error}=              Catenate  app 'adc' failed exitted with code 1, stderr:
    ...                             Setting channel #0 value for 'adc1' failed with:
    ...                             Invalid voltage value 3301000 not in [0; 3300000]: 1 != 0

    Run Keyword And Expect Error    EQUALS:${expected_error}
    ...                             Execute Sample  adc  ${PORT}  ECUC  adc1  6  ${{${MAX_POTENTIOMETER} + 1}}mV

Should Run ADC Sample On Named Discrete Values
    [Tags]                          skip_windows

    Build Sample                    adc
    Execute Command                 include @scripts/multi-node/ramn.resc
    Execute Command                 mach set "ECUD"

    ${states}=                      Create Dictionary
    ...                             left=0
    ...                             middle=1650
    ...                             right=3300

    FOR  ${state}  IN  @{states}
        Execute Sample                  adc  ${PORT}  ECUD  adc1  9  ${states}[${state}]mV
        ${currentState}=                Execute Command  adc1.engineKey CurrentState
        Should Be Equal                 ${currentState}  ${state}  strip_spaces=True
    END

    Run Keyword And Expect Error    app 'adc' failed exitted with code 1, stderr: Setting channel #0 value for 'adc1' failed with: Invalid voltage value 1000000: 1 != 0
    ...                             Execute Sample  adc  ${PORT}  ECUD  adc1  9  1V

Should Run GPIO Sample
    [Tags]                          exclude_windows

    Execute Command                 mach create "machine"
    Execute Command                 machine LoadPlatformDescriptionFromString "gpio: GPIOPort.NPCX_GPIO @ sysbus 0x0"
    Execute Command                 machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32gc_Zfh\\" }"
    Execute Command                 machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus ${MEMORY_ADDRESS} { size: 0x40000 }"
    Create Log Tester               5

    Build Sample                    gpio

    FOR  ${pin}  IN RANGE  0  8
        Execute Sample                  gpio  ${PORT}  machine  gpio  ${pin}  true

        ${register}=                    Execute Command  gpio ReadByte 0x1  # Read the data input register
        Should Be True                  ${register.strip()} & (1 << ${pin}) == (1 << ${pin})

        Execute Sample                  gpio  ${PORT}  machine  gpio  ${pin}  false

        ${register}=                    Execute Command  gpio ReadByte 0x1  # Read the data input register
        Should Be True                  ${register.strip()} & (1 << ${pin}) != (1 << ${pin})
    END

    Execute Command                 gpio WriteByte 0x2 0xF  # Set all pins as output
    Execute Command                 cpu AssembleBlock ${MEMORY_ADDRESS} """li x1, 0x1; sb x1, 0(x0); jal x0, 0"""  # Trigger a GPIO change

    ${proc}=                        Start Sample  gpio  ${PORT}  machine  gpio  0  event
    # Wait for sample to setup the callback. Do not start the emulation here as otherwise
    # the sample will not be able to issue the "run for" command.
    Wait For Log Entry              Executing RunFor  startEmulation=false

    ${r}=                           Wait For Process  ${proc}
    Should Be Equal As Integers     ${r.rc}  0  msg=app failed: ${r.stderr}

    Should Contain                  ${r.stdout}  machine: GPIO #0 in gpio set
