# Like native-interface.robot, this suite does not use the Renode instance started by
# robot_tests_provider. Each test builds a native host process that hosts its own Renode instance,
# serves the guest's bus accesses as a device model through the external control API and reports
# the result through its exit code.
#
# See native-interface.resource for the variables that select which librenode is used.

*** Settings ***
Library                             OperatingSystem
Resource                            ${CURDIR}/native-interface.resource

*** Variables ***
${EXAMPLE_DIR}                      ${CURDIR}/../../tools/NativeInterface/example

*** Keywords ***
Run Guest Program On Native Bus Handlers
    [Arguments]                     ${program}  ${host}
    ${build_dir}=                   Allocate Temporary Directory  bus-handlers-build
    Build NativeInterface Project   ${EXAMPLE_DIR}  ${build_dir}

    ${script}=                      Catenate  SEPARATOR=${\n}
    ...                             mach create "bus-handlers"
    ...                             machine LoadPlatformDescription @platforms/cpus/cortex-a78.repl
    ...                             machine LoadPlatformDescriptionFromString "dut: Bus.ExternalControlBusPeripheral @ sysbus 0x10000000 { size: 0x1000 }"
    ...                             machine LoadPlatformDescriptionFromString "gpio: GPIOPort.ARM_AHB_GPIO @ sysbus 0x10001000"
    ...                             cpu AssembleBlock 0x40000000 """
    ...                             ${program}
    ...                             """ triple="arm64"
    ...                             cpu PC 0x40000000
    ${script_path}=                 Set Variable  ${build_dir}/bus-handlers.resc
    Create File                     ${script_path}  ${script}

    Run Native Host                 ${build_dir}/${host}  ${script_path}

*** Test Cases ***
Should Serve Guest Accesses Through Native Bus Handlers
    [Tags]                          basic-tests
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
    Run Guest Program On Native Bus Handlers  ${program}  bus_handlers_host

Should Pass GPIO States Between The Guest And A Native Device
    # Each change takes effect at the next synchronization point, so the guest waits for each
    # change, and a change that never arrives makes the host time out.
    ${program}=                     Catenate  SEPARATOR=${\n}
    ...                             mov x0, #0x10000000      # volatile uint32_t *dut = (volatile uint32_t *)0x10000000;
    ...                             ldr x1, =0x10001000      # volatile uint32_t *gpio = (volatile uint32_t *)0x10001000;
    ...                             ldr x2, =0x40100000      # volatile uint32_t *data = (volatile uint32_t *)0x40100000;
    # Latch rising edges of the GPIO input, so that the guest can't miss the host's pulse.
    ...                             mov w3, #1
    ...                             str w3, [x1, #0x28]      # gpio[GPIO_INTTYPESET] = 1;
    ...                             str w3, [x1, #0x30]      # gpio[GPIO_INTPOLSET] = 1;
    # The host serves this write by writing a word into RAM and pulsing the GPIO input.
    ...                             str w3, [x0, #8]         # dut[REGISTER_START] = 1;
    # The guest waits for the latched rising edge and then checks the word.
    ...                             wait_edge:               # while(!(gpio[GPIO_INTSTATUS] & 1)) {}
    ...                             ldr w4, [x1, #0x38]
    ...                             tbz w4, #0, wait_edge
    ...                             ldr w5, [x2]             # uint32_t passed = *data == 0xcafe0001;
    ...                             ldr w6, =0xcafe0001
    ...                             cmp w5, w6
    ...                             cset w7, eq
    # The guest pulses a GPIO output. The host's state change callback saves each new state, and
    # the guest reads a DUT register until it returns that state.
    ...                             mov w4, #2               # gpio[GPIO_OUTENSET] = 1 << 1;
    ...                             str w4, [x1, #0x10]
    ...                             str w4, [x1, #4]         # gpio[GPIO_DATAOUT] = 1 << 1;
    ...                             wait_high:               # while(dut[REGISTER_OUTPUT_STATE] != 1) {}
    ...                             ldr w4, [x0, #0x10]
    ...                             cmp w4, #1
    ...                             b.ne wait_high
    ...                             str wzr, [x1, #4]        # gpio[GPIO_DATAOUT] = 0;
    ...                             wait_low:                # while(dut[REGISTER_OUTPUT_STATE] != 0) {}
    ...                             ldr w4, [x0, #0x10]
    ...                             cbnz w4, wait_low
    ...                             str w7, [x0, #4]         # dut[REGISTER_TEST_END] = passed;
    ...                             halt:                    # for(;;) { wait_for_interrupt(); }
    ...                             wfi
    ...                             b halt
    Run Guest Program On Native Bus Handlers  ${program}  gpio_host
