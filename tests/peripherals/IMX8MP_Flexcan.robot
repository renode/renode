*** Variables ***
${UART}                             sysbus.uart4
${CAN}                              sysbus.flexcan1
${CAN_HUB}                          canHub
${SCRIPT}                           @scripts/single-node/nxp-im8mplus_zephyr.resc
${URI}                              https://dl.antmicro.com/projects/renode
${CAN_COUNTER_ELF}                  @${URI}/imx8mp_evk_mimx8ml8_a53-zephyr-can_counter.elf-s_1883848-e50bf05ce6ad42d9cffb58787378c4b3aa92f24e
${CAN_COUNTER_NO_LOOPBACK_ELF}      @${URI}/imx8mp_evk_mimx8ml8_a53-zephyr-can_counter_no_loopback.elf-s_1883384-e446ef35ae5042ffe73ae57131245ef519eb33ad

*** Keywords ***
Create CAN Hub
    Execute Command                 emulation CreateCANHub "${CAN_HUB}" False

Create IMX8MP Machine
    [Arguments]                     ${binary}  ${name}=machine-0
    Execute Command                 $bin=${binary}
    Execute Command                 mach create
    Execute Command                 include ${SCRIPT}
    Execute Command                 connector Connect ${CAN} ${CAN_HUB}

*** Test Cases ***
Should Receive CAN Frames On Loopback
    Create CAN Hub
    Create IMX8MP Machine           ${CAN_COUNTER_ELF}
    Create Terminal Tester          ${UART}

    # Wait for several successful transmissions
    ${cnt}=                         Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart           Counter received: ${i}
    END

Should Exchange CAN Frames Between Machines
    Create CAN Hub
    Create IMX8MP Machine           ${CAN_COUNTER_NO_LOOPBACK_ELF}  name=machine-0
    ${tester-0}=                    Create Terminal Tester  ${UART}  machine=machine-0

    Create IMX8MP Machine           ${CAN_COUNTER_NO_LOOPBACK_ELF}  name=machine-1
    ${tester-1}=                    Create Terminal Tester  ${UART}  machine=machine-1

    # Lower quantum to keep synchronization between machines
    Execute Command                 emulation SetGlobalQuantum "0.000025"
    Execute Command                 emulation SetGlobalSerialExecution True

    # Wait for several successful transmissions
    ${cnt}=                         Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart           Counter received: ${i}  testerId=${tester-0}
        Wait For Line On Uart           Counter received: ${i}  testerId=${tester-1}
    END
