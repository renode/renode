*** Settings ***
Test Teardown                       Custom Test Teardown
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
    [Arguments]                     ${proc}  ${timeout}=5 minute

    Execute Command In Process      ${proc}  quit

    ${result}=                      Wait For Process  ${proc}
    Log                             Remote Renode stdout:${\n}${result.stdout}
    Log                             Remote Renode stderr:${\n}${result.stderr}
    Should Be Equal As Integers     ${result.rc}  0  msg=Process failed with exit code

    [Return]                        ${result.stdout}

Wait For LED State Change
    [Arguments]                     ${led}  ${state}
    Wait For Log Entry              ${led}: LED state changed to ${state}  startEmulation=false

Run Renodes Freely
    [Arguments]                     ${sleep_time}

    ${remote}=                      Create Machine And Connect Remote Renode  ${EXTERNALLY_CONTROLED_RESC}

    Execute Command In Process      ${remote}  client SynchronizeTimeWithExternal
    Wait For Log Entry              ${SERVER_NAME}: Registered time elapsed callback  startEmulation=false

    Execute Command                 start
    Sleep                           ${sleep_time}

    [Return]                        ${remote}

Ensure NPU Device In Reset
    # Follow initialization procedures as described in:
    # https://github.com/google-coral/coralnpu/blob/main/doc/integration_guide.md#booting-coralnpu

    # Write to physical memory
    Write Line To Uart              devmem 0xE00030000
    # Ensure that the device is in reset, and has gated its clock
    Wait For Line On Uart           0x00000003

Release NPU Clock Gate And Reset
    # Release Clock Gate
    Write Line To Uart              devmem 0xE00030000 w 0x1
    Write Line To Uart              devmem 0xE00030000
    Wait For Line On Uart           0x00000001

    # Release Reset
    Write Line To Uart              devmem 0xE00030000 w 0x0
    Write Line To Uart              devmem 0xE00030000
    Wait For Line On Uart           0x00000000

Check If NPU Finished
    Write Line To Uart              devmem 0xE00030008
    Wait For Line On Uart           0x00000001

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

Should Quit External Renode While Running
    [Tags]                          basic-tests  skip_windows

    ${remote}=                      Run Renodes Freely  3

    ${output}=                      Quit Renode  ${remote}

Should Quit Local Renode While Running
    [Tags]                          basic-tests  skip_windows

    ${remote}=                      Run Renodes Freely  3

    Reset Emulation
    ${output}=                      Quit Renode  ${remote}

Should Launch Sample Coral App
    [Tags]                          skip_windows
    [Timeout]                       NONE

    Execute Command                 include @scripts/complex/coral_npu/external_control/imx8mplus_linux_coral_external_control_server.resc
    Create Terminal Tester          sysbus.uart2  timeout=120   defaultPauseEmulation=true

    Create Log Tester               1

    Execute Command                 logLevel 0 ${SERVER_NAME}
    ${remote}=                      Start Renode  ${PORT}  scripts/complex/coral_npu/external_control/imx8mplus_linux_coral_external_control_client.resc
    Wait For Log Entry              Registered sysbus callbacks  startEmulation=false
    Execute Command                 logLevel 1 ${SERVER_NAME}

    ${response} =                   Execute Command      ${SERVER_NAME} SendCustomCommand 'coralStats_reset'

    Wait For Line On Uart           ==== Hello World! Linux i.MX 8M Plus ====
    Wait For Prompt On Uart         \#${SPACE}
    Write Line To Uart              uname -a
    Wait For Line On Uart           Linux

    Ensure NPU Device In Reset

    # Copy the binary to NPU's Instruction Memory
    Execute Command                 sysbus LoadBinary @https://dl.antmicro.com/projects/renode/coralnpu_v2_hello_world_add_floats.bin-s_65648-0e3f5d6ae173fa2e06f6b5f91906ef721516de4c 0xE00000000

    # Initialize input data in Data Memory
    Write Line To Uart              devmem 0xE00010000 w 2
    Write Line To Uart              devmem 0xE00010000
    Wait For Line On Uart           0x00000002

    Write Line To Uart              devmem 0xE00010020 w 5
    Write Line To Uart              devmem 0xE00010020
    Wait For Line On Uart           0x00000005

    Release NPU Clock Gate And Reset

    # Check that we finished the program
    Wait Until Keyword Succeeds     30s  1s  Check If NPU Finished

    # Check the result (this is an addition A + B)
    Write Line To Uart              devmem 0xE00010040
    Wait For Line On Uart           0x00000007

    ${response} =                   Execute Command      ${SERVER_NAME} SendCustomCommand 'coralStats_print'
    Should Contain                  ${response}  Executed NPU (CoralNPU_RVV) instructions: 208

    Quit Renode                     ${remote}
