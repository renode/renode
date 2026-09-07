*** Settings ***
Test Teardown                       Custom Test Teardown
Test Timeout                        1 minute  # Quickly timeout even when emulation isn't started
Library                             Process
Library                             OperatingSystem
Library                             Collections
Library                             String

*** Variables ***
${PORT}                              3345
${SERVER_NAME}                       server
${EXTERNAL_MACHINE}                  external-mach
${EXTERNALLY_CONTROLED_RESC}         scripts/complex/external_control/renode_externally_controlled.resc
${EXTERNALLY_CONTROLED_RESC_GPIO}    scripts/complex/external_control/renode_externally_controlled_gpio.resc
${GPIO_PLATFORM}                     SEPARATOR=${\n}
...                                  """
...                                  led1: Miscellaneous.LED @ sysbus
...                                  led2: Miscellaneous.LED @ sysbus
...                                  led3: Miscellaneous.LED @ sysbus
...                                  """
${EXTERNALLY_CONTROLED_RESC_PERIPH}  scripts/complex/external_control/renode_externally_controlled_peripherals.resc
${LOCAL_PERIPHERAL_PLATFORM}         SEPARATOR=${\n}
...                                  """
...                                  memory_bus_peripheral_remote: Bus.ExternalControlBusPeripheral @ sysbus 0x1000
...                                  ${SPACE*4}size: 0x1000
...
...                                  counter_bus_peripheral_remote: Bus.ExternalControlBusPeripheral @ sysbus 0x2000
...                                  ${SPACE*4}size: 0x10
...                                  """
${STDOUT_FILE}                       None
${STDERR_FILE}                       None

*** Keywords ***
Custom Test Teardown
    Test Teardown

    Return From Keyword If          'skipped' in @{TEST TAGS}

    ${is_process_running}=          Is Process Running
    IF  ${is_process_running}
        ${result}=                      Terminate Process
        Fail                            Unfinished process during teardown
        Log                             Process rc: ${result.rc}
        Log                             Process stdout:${\n}${result.stdout}
        Log                             Process stderr:${\n}${result.stderr}
    END

Create Machine And Connect Remote Renode
    [Arguments]                     ${remote_renode_resc}  ${local_platform_desc}=""
    Create Log Tester               10

    Execute Command                 emulation CreateExternalControlServer "${SERVER_NAME}" ${PORT}
    Execute Command                 mach create "machine"
    Execute Command                 logLevel 0 ${SERVER_NAME}

    IF  ${local_platform_desc} != ""
        Execute Command                 machine LoadPlatformDescriptionFromString ${local_platform_desc}
    END

    ${remote_renode}=               Start Renode  ${PORT}  ${remote_renode_resc}

    Wait For Log Entry              ${SERVER_NAME}: Connection accepted  startEmulation=false

    [Return]                        ${remote_renode}

Start Renode
    [Arguments]                     ${port}  ${resc}

    # Redirect outputs to files to avoid filling up buffers
    ${stdout_file}=                 Allocate Temporary File
    ${stderr_file}=                 Allocate Temporary File
    Set Global Variable             ${STDOUT_FILE}  ${stdout_file}
    Set Global Variable             ${STDERR_FILE}  ${stderr_file}

    @{args}=                        Split Command Line  ${COMMAND}
    # Make sure that the logs are seen on stdout
    ${_idx}=                        Get Index From List             ${args}  --hide-log
    IF  ${_idx} != -1
        Remove From List            ${args}  ${_idx}
    END
    Append To List                  ${args}  --console  -e  $client_port=${PORT}; i "${resc}"

    ${proc}=                        Start Process  @{args}  cwd=${DIRECTORY}  stdout=${STDOUT_FILE}  stderr=${STDERR_FILE}  stdin=PIPE
    [Return]                        ${proc}

Execute Command In Process
    [Arguments]                     ${proc}  ${command}

    Evaluate                        $proc.stdin.write(($command + "\\n").encode("utf-8"))
    Evaluate                        $proc.stdin.flush()

File Should Contain
    [Arguments]                     ${filename}  ${expected}

    ${contents}=                    Get File  ${filename}
    Should Contain                  ${contents}  ${expected}

Wait For Line In File
    [Arguments]                     ${filename}  ${expected}

    Wait Until Keyword Succeeds
    ...                             30 seconds
    ...                             1 second
    ...                             File Should Contain
    ...                             ${filename}
    ...                             ${expected}

Quit Renode
    [Arguments]                     ${proc}  ${timeout}=1 minute

    Execute Command In Process      ${proc}  quit

    ${result}=                      Wait For Process  ${proc}
    Log                             Remote Renode stdout:${\n}${result.stdout}
    Log                             Remote Renode stderr:${\n}${result.stderr}
    Should Be Equal As Integers     ${result.rc}  0  msg=Process failed with exit code

    [Return]                        ${result.stdout}

Wait For LED State Change
    [Arguments]                     ${led}  ${state}
    Wait For Log Entry              ${led}: LED state changed to ${state}  startEmulation=false

*** Test Cases ***
Should Connect Two Renodes
    [Tags]                          basic-tests  skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC}

    Quit Renode                     ${remote}

Should Synchronize Time Between Two Renodes
    [Tags]                          skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC}
    Execute Command In Process      ${remote}  client SynchronizeTimeWithExternal

    Wait For Log Entry              ${SERVER_NAME}: Registered time elapsed callback  startEmulation=false

    Execute Command                 emulation RunFor "0.0002"
    Execute Command In Process      ${remote}  emulation GetTimeSourceInfo

    ${output}=                      Quit Renode  ${remote}
    Should Contain                  ${output}  Elapsed Virtual Time: 00:00:00.000200000

Should Pass GPIO Between Two Renodes
    [Tags]                          skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC_GPIO}

    # Synchronize GPIOs even when emulation is stopped
    Execute Command                 emulation Mode SynchronizedTimers
    Execute Command                 machine LoadPlatformDescriptionFromString ${GPIO_PLATFORM}
    Execute Command                 logLevel -1 led1
    Execute Command                 logLevel -1 led2
    Execute Command                 logLevel -1 led3

    Execute Command                 ${SERVER_NAME} ConnectExternalGPIOOutput led1 0 "${EXTERNAL_MACHINE}" "external_button1" 0
    Execute Command                 ${SERVER_NAME} ConnectExternalGPIOOutput led2 0 "${EXTERNAL_MACHINE}" "external_button1" 0
    Execute Command                 ${SERVER_NAME} ConnectExternalGPIOOutput led3 0 "${EXTERNAL_MACHINE}" "external_button2" 0

    Execute Command In Process      ${remote}  external_button1 Press
    Wait For LED State Change       led1  True
    Wait For LED State Change       led2  True
    Execute Command In Process      ${remote}  external_button1 Release
    Wait For LED State Change       led1  False
    Wait For LED State Change       led2  False

    Execute Command In Process      ${remote}  external_button2 Press
    Wait For LED State Change       led3  True
    Execute Command In Process      ${remote}  external_button2 Release
    Wait For LED State Change       led3  False

    Quit Renode                     ${remote}

Should Connect To Remote Bus Peripheral And Write
    [Tags]                          skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC_PERIPH}  ${LOCAL_PERIPHERAL_PLATFORM}
    Wait For Log Entry              ${SERVER_NAME}: Registered sysbus callbacks (ed=0, access_types=[Write], access_widths=[DoubleWord])  startEmulation=false
    Wait For Log Entry              ${SERVER_NAME}: Registered sysbus callbacks (ed=1, access_types=[ReadWrite], access_widths=[Byte])    startEmulation=false
    Wait For Log Entry              ${SERVER_NAME}: Registered sysbus callbacks (ed=2, access_types=[Read], access_widths=[DoubleWord])   startEmulation=false

    Execute Command In Process      ${remote}  log \\"Writing data to remote memory\\"
    Execute Command In Process      ${remote}  sysbus WriteByte 0x1020 0xEE

    Wait For Line In File           ${STDOUT_FILE}   memory_bus_peripheral: WriteByte to 0x20 (unknown), value 0xEE

    Execute Command                 sysbus WriteDoubleWord 0x1000 0xCD
    Execute Command                 sysbus WriteDoubleWord 0x1008 0xEF
    Execute Command                 sysbus WriteDoubleWord 0x1008 0xAB
    ${val}=                         Execute Command                 sysbus ReadByte 0x1020

    Execute Command In Process      ${remote}  sysbus ReadDoubleWord 0x1000
    Execute Command In Process      ${remote}  sysbus ReadDoubleWord 0x1008

    Should Be Equal As Numbers      ${val}  0xEE

    ${output}=                      Quit Renode  ${remote}
    Should Contain                  ${output}  memory_bus_peripheral: ReadUInt32 from 0x0 (unknown), returned 0xCD
    Should Contain                  ${output}  memory_bus_peripheral: ReadUInt32 from 0x8 (unknown), returned 0xAB

Should Connect To Remote Bus Peripheral And Read
    [Tags]                          skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC_PERIPH}  ${LOCAL_PERIPHERAL_PLATFORM}
    Wait For Log Entry              ${SERVER_NAME}: Registered sysbus callbacks (ed=0, access_types=[Write], access_widths=[DoubleWord])  startEmulation=false
    Wait For Log Entry              ${SERVER_NAME}: Registered sysbus callbacks (ed=1, access_types=[ReadWrite], access_widths=[Byte])    startEmulation=false
    Wait For Log Entry              ${SERVER_NAME}: Registered sysbus callbacks (ed=2, access_types=[Read], access_widths=[DoubleWord])   startEmulation=false

    ${op1}=                         Execute Command                 sysbus ReadDoubleWord 0x2000
    ${op2}=                         Execute Command                 sysbus ReadDoubleWord 0x2000
    ${op3}=                         Execute Command                 sysbus ReadDoubleWord 0x2000

    ${output}=                      Quit Renode  ${remote}
    Should Be Equal As Numbers      ${op1}    1
    Should Be Equal As Numbers      ${op2}    2
    Should Be Equal As Numbers      ${op3}    3

Should Run Custom Command Sample
    [Tags]                          skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC}
    Execute Command In Process      ${remote}  client AttachCustomCommandCallbackToMonitor

    Wait For Log Entry              Attaching CustomCommand callback  startEmulation=False

    ${response}=                    Execute Command  ${SERVER_NAME} SendCustomCommand 'echo "echo"'
    Should Contain                  ${response}  echo
    ${response}=                    Execute Command  ${SERVER_NAME} SendCustomCommand 'emulation RunFor "0.0002"'
    Should Be Equal                 ${response}  \n\n
    ${response}=                    Execute Command  ${SERVER_NAME} SendCustomCommand 'emulation GetTimeSourceInfo'
    Should Contain                  ${response}  Elapsed Virtual Time: 00:00:00.000200000

    Quit Renode                     ${remote}

Should Run Quit As Custom Command
    [Tags]                          skip_windows

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC}
    Execute Command In Process      ${remote}  client AttachCustomCommandCallbackToMonitor

    Wait For Log Entry              Attaching CustomCommand callback  startEmulation=False

    Execute Command                 ${SERVER_NAME} SendCustomCommand 'quit'

    Wait Until Keyword Succeeds
    ...                             30 seconds
    ...                             1 second
    ...                             Process Should Be Stopped
    ...                             ${remote}

    Wait For Log Entry              Listening for connections  startEmulation=False
