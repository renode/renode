# Like bus-handlers.robot, this suite does not use the Renode instance started by
# robot_tests_provider. Each test builds a native host process that hosts its own Renode instance,
# runs in lockstep with it by calling renode_run_for() through the external control API and reports
# the result through its exit code.
#
# See native-interface.resource for the variables that select which librenode is used.

*** Settings ***
Library                             OperatingSystem
Resource                            ${CURDIR}/native-interface.resource

*** Variables ***
${EXAMPLE_DIR}                      ${CURDIR}/../../tools/NativeInterface/example

*** Keywords ***
Run Guest Program On Lockstep Host
    [Arguments]                     ${program}  ${host}
    ${build_dir}=                   Allocate Temporary Directory  lockstep-build
    Build NativeInterface Project   ${EXAMPLE_DIR}  ${build_dir}

    ${script}=                      Catenate  SEPARATOR=${\n}
    ...                             mach create "lockstep"
    ...                             machine LoadPlatformDescription @platforms/cpus/cortex-a78.repl
    ...                             machine LoadPlatformDescriptionFromString "dut: Bus.ExternalControlBusPeripheral @ sysbus 0x10000000 { size: 0x1000 }"
    ...                             machine LoadPlatformDescriptionFromString "gpio: GPIOPort.ARM_AHB_GPIO @ sysbus 0x10001000"
    ...                             cpu AssembleBlock 0x40000000 """
    ...                             ${program}
    ...                             """ triple="arm64"
    ...                             cpu PC 0x40000000
    ${script_path}=                 Set Variable  ${build_dir}/lockstep.resc
    Create File                     ${script_path}  ${script}

    Run Native Host                 ${build_dir}/${host}  ${script_path}

*** Test Cases ***
Should Let The Device Call Renode Within A Lockstep Step
    # The device calls Renode during the host's renode_run_for() call. If that call to Renode waits
    # for renode_run_for() to end, the device and the host wait for each other, and the test fails
    # when the host times out.
    ${program}=                     Catenate  SEPARATOR=${\n}
    ...                             mov x0, #0x10000000      # volatile uint32_t *dut = (volatile uint32_t *)0x10000000;
    ...                             ldr x1, =0x40100000      # volatile uint32_t *data = (volatile uint32_t *)0x40100000;
    # The device serves this write by writing a word into RAM.
    ...                             mov w2, #1
    ...                             str w2, [x0, #8]         # dut[REGISTER_START] = 1;
    ...                             ldr w3, [x1]             # uint32_t passed = *data == 0xcafe0001;
    ...                             ldr w4, =0xcafe0001
    ...                             cmp w3, w4
    ...                             cset w5, eq
    ...                             str w5, [x0, #4]         # dut[REGISTER_TEST_END] = passed;
    ...                             halt:                    # for(;;) { wait_for_interrupt(); }
    ...                             wfi
    ...                             b halt
    Run Guest Program On Lockstep Host  ${program}  lockstep_device_host

Should Pass GPIO States Within Each Lockstep Step
    # The host sets the GPIO input between steps, and after each step it checks the state of the
    # GPIO output that its state change callback reported.
    ${program}=                     Catenate  SEPARATOR=${\n}
    ...                             ldr x1, =0x10001000      # volatile uint32_t *gpio = (volatile uint32_t *)0x10001000;
    ...                             mov w2, #2               # gpio[GPIO_OUTENSET] = 1 << 1;
    ...                             str w2, [x1, #0x10]
    # The guest keeps setting the GPIO output to the state of the GPIO input.
    ...                             copy:                    # for(;;) { gpio[GPIO_DATAOUT] = (gpio[GPIO_DATA] & 1) << 1; }
    ...                             ldr w3, [x1]
    ...                             and w3, w3, #1
    ...                             lsl w3, w3, #1
    ...                             str w3, [x1, #4]
    ...                             b copy
    Run Guest Program On Lockstep Host  ${program}  lockstep_gpio_host
