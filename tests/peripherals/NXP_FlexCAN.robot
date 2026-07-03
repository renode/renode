*** Variables ***
${UART}                           sysbus.lpuart2
${CAN}                            sysbus.can0
${CAN_HUB}                        canHub
${URI}                            https://dl.antmicro.com/projects/renode/

${CAN_COUNTER_ELF}                @${URI}/mr_canhubk3--zephyr-can-counter.elf-s_1959844-b2284bfd7adff900c7d6ac7fa06bb5ba3291b0e4
${CAN_COUNTER_NO_LOOPBACK_ELF}    @${URI}/mr_canhubk3--zephyr-can-counter--no-loopback.elf-s_1959384-b17eb95f04cb75ef5a7781cdaad708db8a7f7449

*** Keywords ***
Create CAN Hub
    Execute Command               emulation CreateCANHub "${CAN_HUB}" False

Create MR CANHUBK3 Machine
    [Arguments]                   ${binary}    ${name}=machine-0
    Execute Command               $name="${name}"
    Execute Command               $bin=${binary}
    Execute Command               include @tests/peripherals/mr_canhubk3.resc
    Execute Command               connector Connect ${CAN} ${CAN_HUB}

*** Test Cases ***
Should Receive CAN Frames On Loopback
    Create CAN Hub
    Create MR CANHUBK3 Machine    ${CAN_COUNTER_ELF}
    Create Terminal Tester        ${UART}

    # Wait for several successful transmissions
    ${cnt}=                   Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     Counter received: ${i}
    END

Should Exchange CAN Frames Between Machines
    Create CAN Hub
    Create MR CANHUBK3 Machine    ${CAN_COUNTER_NO_LOOPBACK_ELF}   name=machine-0
    ${tester-0}=                  Create Terminal Tester  ${UART}  machine=machine-0

    Create MR CANHUBK3 Machine    ${CAN_COUNTER_NO_LOOPBACK_ELF}   name=machine-1
    ${tester-1}=                  Create Terminal Tester  ${UART}  machine=machine-1

    # Lower quantum to keep synchronization between machines
    Execute Command               emulation SetGlobalQuantum "0.000025"
    Execute Command               emulation SetGlobalSerialExecution True

    # Wait for several successful transmissions
    ${cnt}=                       Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     Counter received: ${i}  testerId=${tester-0}
        Wait For Line On Uart     Counter received: ${i}  testerId=${tester-1}
    END
