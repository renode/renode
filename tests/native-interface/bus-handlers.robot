# Like native-interface.robot, this suite does not use the Renode instance started by
# robot_tests_provider. It builds a native host process that hosts its own Renode instance and
# checks the guest's bus accesses itself, reporting the result through its exit code.
#
# See native-interface.resource for the variables that select which librenode is used.

*** Settings ***
Library                             OperatingSystem
Resource                            ${CURDIR}/native-interface.resource

*** Variables ***
${EXAMPLE_DIR}                      ${CURDIR}/../../tools/NativeInterface/example

*** Keywords ***
Run Guest Program On Native Bus Handlers
    [Arguments]                     ${program}
    ${build_dir}=                   Set Variable  ${RESULTS_DIRECTORY}/bus-handlers-build
    Build NativeInterface Project   ${EXAMPLE_DIR}  ${build_dir}

    ${script}=                      Catenate  SEPARATOR=${\n}
    ...                             mach create "bus-handlers"
    ...                             machine LoadPlatformDescription @platforms/cpus/cortex-a78.repl
    ...                             machine LoadPlatformDescriptionFromString "dut: Bus.ExternalControlBusPeripheral @ sysbus 0x10000000 { size: 0x1000 }"
    ...                             cpu AssembleBlock 0x40000000 """
    ...                             ${program}
    ...                             """ triple="arm64"
    ...                             cpu PC 0x40000000
    ${script_path}=                 Set Variable  ${RESULTS_DIRECTORY}/bus-handlers.resc
    Create File                     ${script_path}  ${script}

    ${result}=                      Run Process  ${build_dir}/bus_handlers_host  ${script_path}
    ...                             timeout=60s  on_timeout=kill
    Should Be Equal As Integers     ${result.rc}  0  msg=Host exited with code ${result.rc}${\n}stdout:${\n}${result.stdout}${\n}stderr:${\n}${result.stderr}

*** Test Cases ***
Should Serve Guest Accesses Through Native Bus Handlers
    ${program}=                     Catenate  SEPARATOR=${\n}
    ...                             mov x0, #0x10000000      # volatile uint32_t *dut = (volatile uint32_t *)0x10000000;
    ...                             ldr w1, =0xdeadbeef      # uint32_t expected = 0xdeadbeef;
    ...                             str w1, [x0]             # dut[REGISTER_SCRATCH] = expected;
    ...                             ldr w2, [x0]             # uint32_t actual = dut[REGISTER_SCRATCH];
    ...                             cmp w1, w2               # uint32_t passed = actual == expected;
    ...                             cset w3, eq
    ...                             str w3, [x0, #4]         # dut[REGISTER_TEST_END] = passed;
    ...                             halt:
    ...                             wfi                      # for(;;) { wait_for_interrupt(); }
    ...                             b halt
    Run Guest Program On Native Bus Handlers  ${program}
