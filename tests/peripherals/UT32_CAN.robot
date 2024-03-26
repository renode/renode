# Based on MCAN.robot

*** Variables ***
${UART}                                            sysbus.usart3
${CAN}                                             sysbus.utcan
${CAN_HUB}                                         canHub
${PROMPT}                                          \#${SPACE}
${UT32_CAN_REPL}                                   SEPARATOR=\n
...                                                """
...                                                utcan: CAN.UT32_CAN @ sysbus 0x40cccc00
...                                                ${SPACE*4}-> nvic@19
...                                                """
# All Zephyr tests work in loopback mode
${TESTS_NET_SOCKET_CAN_BIN}                        @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-net-socket-can-ut32_can.elf-s_730196-c52d44ada96c6b31de3a0d158d015b73292b40da
${TESTS_DRIVERS_CAN_API_BIN}                       @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-drivers-can-api-ut32_can.elf-s_1906268-a5504a6579baa2a4ec54631d64c9f21337b91379
${TESTS_DRIVERS_CAN_TIMING_BIN}                    @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-drivers-can-timing-ut32_can.elf-s_1734652-3eb1047cd81cc11f72613746aee01d5278d0bcc8
${TESTS_DRIVERS_CAN_SHELL_BIN}                     @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-drivers-can-shell-ut32_can.elf-s_1510120-b2056800cb2907c73a4bd42b49417e4a09db5b99
# Zephyr samples can be configured to work in either normal or loopback mode
${SAMPLES_NET_SOCKETS_CAN_LOOPBACK_BIN}            @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-net-sockets-can--loopback-ut32_can.elf-s_2059904-50e9744c770ea67909a0951ab30650f0c0246f13
${SAMPLES_NET_SOCKETS_CAN_NO_LOOPBACK_BIN}         @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-net-sockets-can-ut32_can.elf-s_2056976-efbc0327c5433fde0fa166ab3b652602c9c5ae0b
${SAMPLES_DRIVERS_CAN_COUNTER_LOOPBACK_BIN}        @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-drivers-can-counter--loopback-ut32_can.elf-s_1272296-cfc7a216ae8f087a89e79c211442a80347888017
${SAMPLES_DRIVERS_CAN_COUNTER_NO_LOOPBACK_BIN}     @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-drivers-can-counter-ut32_can.elf-s_1271844-3366c77a9b0c4c7ca234a445644ae89ef8b73ad7

*** Keywords ***
Create CAN Hub
    Execute Command           emulation CreateCANHub "${CAN_HUB}"

Create STM32H7 Machine
    [Arguments]               ${bin}  ${name}=machine-0
    Execute Command           $bin=${bin}
    Execute Command           mach create "${name}"
    Execute Command           machine LoadPlatformDescription @platforms/cpus/stm32h753.repl
    # The Zephyr binaries used here would not work on a real STM32H753 as they expect a UT32-compatible CAN controller
    # to be present at 0x40cccc00. Add it to the platform
    Execute Command           machine LoadPlatformDescriptionFromString ${UT32_CAN_REPL}
    Execute Command           macro reset "sysbus LoadELF ${bin}"
    Execute Command           runMacro $reset
    Execute Command           connector Connect ${CAN} ${CAN_HUB}
    Execute Command           showAnalyzer ${UART}

Set Emulation Parameters For Better Synchronization Between Machines
    Execute Command           emulation SetGlobalQuantum "0.000025"
    Execute Command           emulation SetGlobalSerialExecution True

*** Test Cases ***
Should Pass Zephyr CAN Net Socket Test
    Create CAN Hub
    Create STM32H7 Machine    ${TESTS_NET_SOCKET_CAN_BIN}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr CAN API Test
    Create CAN Hub
    Create STM32H7 Machine    ${TESTS_DRIVERS_CAN_API_BIN}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr CAN Timing Test
    Create CAN Hub
    Create STM32H7 Machine    ${TESTS_DRIVERS_CAN_TIMING_BIN}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr CAN Shell Test
    Create CAN Hub
    Create STM32H7 Machine    ${TESTS_DRIVERS_CAN_SHELL_BIN}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Use CAN Socket API To Exchange Messages In Loopback Mode
    Create CAN Hub
    Create STM32H7 Machine    ${SAMPLES_NET_SOCKETS_CAN_LOOPBACK_BIN}
    Create Terminal Tester    ${UART}

    # Wait for several successful transmissions
    ${cnt}=                   Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     net_socket_can_sample: [0] CAN frame: IDE 0x0 RTR 0x0 ID 0x1 DLC 0x8
        Wait For Line On Uart     f0 f1 f2 f3 f4 f5 f6 f7
    END

Should Use CAN Socket API To Exchange Messages Between Machines
    Create CAN Hub
    Create STM32H7 Machine    ${SAMPLES_NET_SOCKETS_CAN_NO_LOOPBACK_BIN}  machine-0
    ${tester-0}=              Create Terminal Tester  ${UART}  machine=machine-0

    Create STM32H7 Machine    ${SAMPLES_NET_SOCKETS_CAN_NO_LOOPBACK_BIN}  machine-1
    ${tester-1}=              Create Terminal Tester  ${UART}  machine=machine-1

    Set Emulation Parameters For Better Synchronization Between Machines

    # Wait for several successful transmissions
    ${cnt}=                   Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     net_socket_can_sample: [0] CAN frame: IDE 0x0 RTR 0x0 ID 0x1 DLC 0x8  testerId=${tester-0}
        Wait For Line On Uart     net_socket_can_sample: [0] CAN frame: IDE 0x0 RTR 0x0 ID 0x1 DLC 0x8  testerId=${tester-1}
        Wait For Line On Uart     f0 f1 f2 f3 f4 f5 f6 f7  testerId=${tester-0}
        Wait For Line On Uart     f0 f1 f2 f3 f4 f5 f6 f7  testerId=${tester-1}
    END

Should Run Zephyr CAN Counter Sample In Loopback Mode
    Create CAN Hub
    Create STM32H7 Machine    ${SAMPLES_DRIVERS_CAN_COUNTER_LOOPBACK_BIN}
    Create Terminal Tester    ${UART}

    # Wait for several successful transmissions
    ${cnt}=                   Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     Counter received: ${i}
    END

Should Run Zephyr CAN Counter Sample To Exchange Messages Between Machines
    Create CAN Hub
    Create STM32H7 Machine    ${SAMPLES_DRIVERS_CAN_COUNTER_NO_LOOPBACK_BIN}  machine-0
    ${tester-0}=              Create Terminal Tester  ${UART}  machine=machine-0

    Create STM32H7 Machine    ${SAMPLES_DRIVERS_CAN_COUNTER_NO_LOOPBACK_BIN}  machine-1
    ${tester-1}=              Create Terminal Tester  ${UART}  machine=machine-1

    Set Emulation Parameters For Better Synchronization Between Machines

    # Wait for several successful transmissions
    ${cnt}=                   Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     Counter received: ${i}  testerId=${tester-0}
        Wait For Line On Uart     Counter received: ${i}  testerId=${tester-1}
    END
