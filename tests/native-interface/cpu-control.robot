# Like lockstep.robot, this suite does not use the Renode instance started by
# robot_tests_provider. Each test builds a native host process that hosts its own
# Renode instance, controls the guest's CPU through the external control API in one
# scenario of cpu_control_host.cpp and reports the result through its exit code.
#
# See native-interface.resource for the variables that select which librenode is used.

*** Settings ***
Resource                            ${CURDIR}/native-interface.resource

*** Keywords ***
Run CPU Control Scenario
    [Arguments]                     ${scenario}
    # The guest counts its loop iterations in RAM, in this struct:
    #     struct data { uint64_t iterations, access_request, marker; };
    # The host sets `access_request` to make the guest write to the host's device.
    # A routine after the loop, which only a set PC reaches, sets `marker`.
    ${program}=                     Catenate  SEPARATOR=${\n}
    ...                             ldr x0, =0x40100000      # volatile struct data *data = (volatile struct data *)0x40100000;
    ...                             loop:                    # for(;;) {
    ...                             ldr x1, [x0]             #     data->iterations++;
    ...                             add x1, x1, #1
    ...                             str x1, [x0]
    ...                             ldr x2, [x0, #8]         #     if(data->access_request != 0) {
    ...                             cbz x2, loop
    ...                             str xzr, [x0, #8]        #         data->access_request = 0;
    ...                             ldr x3, =0x10000000      #         *(volatile uint64_t *)0x10000000 = 0;
    ...                             str xzr, [x3]            #     }
    ...                             b loop                   # }
    ...                             marker:                  # marker:
    ...                             mov x4, #1               #     data->marker = 1;
    ...                             str x4, [x0, #16]
    ...                             b loop                   #     goto loop;
    Run Guest Program With Native Host  ${program}  cpu_control_host  ${scenario}

*** Test Cases ***
Should Give No CPU Handle For Another Peripheral
    Run CPU Control Scenario        not-a-cpu

Should Read The PC Of The Running Guest
    Run CPU Control Scenario        pc

Should Run The Code At The PC Set By The Host
    Run CPU Control Scenario        set-pc

Should Report Whether The CPU Is Halted
    Run CPU Control Scenario        halted-state

Should Execute Nothing While The CPU Is Halted
    Run CPU Control Scenario        halt

Should Run Again After A Halt
    Run CPU Control Scenario        resume

Should Set The PC While A Device Serves An Access
    # The device sets the PC on the thread that serves the
    # guest's write, while the CPU waits for the write to end.
    Run CPU Control Scenario        set-pc-from-access
