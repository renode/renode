*** Variables ***
${UART}                                            sysbus.usart3
${CAN}                                             sysbus.fdcan1
${CAN_HUB}                                         canHub
${ZYNQ_UART}                                       sysbus.uart0
${ZYNQ_CAN}                                        sysbus.mcan
${PROMPT}                                          \#${SPACE}
${ZYNQ_MCAN_PERIPHERALS}                           SEPARATOR=\n
...                                                """
...                                                mcan: CAN.MCAN @ sysbus <0xe0104000, +0x4000>
...                                                ${SPACE*4}Line0 -> gic@30
...                                                ${SPACE*4}Line1 -> gic@31
...                                                ${SPACE*4}Calibration -> gic@32
...                                                ${SPACE*4}messageRAM: canMessageRAM
...
...                                                canMessageRAM: Memory.ArrayMemory @ sysbus <0xe0108000, +0x22000>
...                                                ${SPACE*4}size: 0x22000
...                                                """
# All Zephyr tests work in loopback mode
${TESTS_NET_SOCKET_CAN_BIN}                        @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-net-socket-can.elf-s_724872-88ee55e384b5d68e4bd7a9a9a51faa47e9faa597
${TESTS_SUBSYS_CANBUS_ISOTP_IMPLEMENTATION_BIN}    @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-subsys-canbus-isotp-implementation.elf-s_1402784-504c3c0fa0d5d111ed443954bbb2c86766153932
${TESTS_SUBSYS_CANBUS_ISOTP_CONFORMANCE_BIN}       @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-subsys-canbus-isotp-conformance.elf-s_1466100-749f79deb1ce2d791b1794454b8afd977825b6eb
${TESTS_DRIVERS_CAN_API_BIN}                       @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-drivers-can-api.elf-s_2039836-5cbc533cfc6334d3df2b0f8ef504c28093fa4dd8
${TESTS_DRIVERS_CAN_TIMING_BIN}                    @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-drivers-can-timing.elf-s_1873596-3a77a90c168202844bf70717b6a221b73e69926c
${TESTS_DRIVERS_CAN_SHELL_BIN}                     @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-tests-drivers-can-shell.elf-s_1642156-92afb142a6be519e6cf51ecb34023167bb66e1fd
# Zephyr samples can be configured to work in either normal or loopback mode
${SAMPLES_SUBSYS_CANBUS_ISOTP_LOOPBACK_BIN}        @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-subsys-canbus-isotp--loopback.elf-s_1554556-1a03849de5b83796ba0d541e279cc04ca1561106
${SAMPLES_SUBSYS_CANBUS_ISOTP_NO_LOOPBACK_BIN}     @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-subsys-canbus-isotp.elf-s_1554512-549bcf52da77937f5c7a86dd407d3e9599e40938
${SAMPLES_NET_SOCKETS_CAN_LOOPBACK_BIN}            @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-net-sockets-can--loopback.elf-s_2246072-12c8e04ba0a5f9ef2181cffb9bd0a38321c8e182
${SAMPLES_NET_SOCKETS_CAN_NO_LOOPBACK_BIN}         @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-net-sockets-can.elf-s_2243040-d8ba11b258437935c3880cf3e162f448f55c6f17
${SAMPLES_DRIVERS_CAN_COUNTER_LOOPBACK_BIN}        @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-drivers-can-counter--loopback.elf-s_1391916-0b17986e6f81b9d38be88cf70c6a5d616de19234
${SAMPLES_DRIVERS_CAN_COUNTER_NO_LOOPBACK_BIN}     @https://dl.antmicro.com/projects/renode/nucleo_h743zi--zephyr-samples-drivers-can-counter.elf-s_1391464-17e71d5820ab718e5dc89f8480644c576306d24c
# Linux with support for MCAN
${ZYNQ_MCAN_BIN}                                   @https://dl.antmicro.com/projects/renode/zynq--linux-mcan.elf-s_14394628-0381324a8046cfb3f7a3f08364acd364588d2f03
${ZYNQ_MCAN_ROOTFS}                                @https://dl.antmicro.com/projects/renode/zynq--linux-mcan-rootfs.ext2-s_16777216-485d90cf2065794b6bbb68768315d1310387a0cc
${ZYNQ_MCAN_DTB}                                   @https://dl.antmicro.com/projects/renode/zynq--linux-mcan.dtb-s_12849-650fd5a9575fd9e2917e5f9dd2677014cbd7af11

*** Keywords ***
Create CAN Hub
    [Arguments]               ${loopback}=${True}
    Execute Command           emulation CreateCANHub "${CAN_HUB}" ${loopback}

Create STM32H7 Machine
    [Arguments]               ${bin}  ${name}=machine-0
    Execute Command           $bin=${bin}
    Execute Command           mach create "${name}"
    Execute Command           machine LoadPlatformDescription @platforms/cpus/stm32h753.repl
    Execute Command           sysbus LoadELF ${bin}
    Execute Command           connector Connect ${CAN} ${CAN_HUB}
    Execute Command           showAnalyzer ${UART}

Create Zynq Machine
    [Arguments]               ${name}=machine-0
    Execute Command           $name="${name}"
    Execute Command           $bin=${ZYNQ_MCAN_BIN}
    Execute Command           $rootfs=${ZYNQ_MCAN_ROOTFS}
    Execute Command           $dtb=${ZYNQ_MCAN_DTB}
    Execute Command           include @scripts/single-node/zedboard.resc
    Execute Command           machine LoadPlatformDescriptionFromString ${ZYNQ_MCAN_PERIPHERALS}
    Execute Command           connector Connect ${ZYNQ_CAN} ${CAN_HUB}

Check Exit Code
    [Arguments]                     ${testerId}
    Write Line To Uart              echo $?  testerId=${testerId}
    Wait For Line On Uart           0  testerId=${testerId}
    Wait For Prompt On Uart         ${PROMPT}  testerId=${testerId}

Execute Linux Command
    [Arguments]                     ${command}  ${testerId}  ${timeout}=5
    Write Line To Uart              ${command}  testerId=${testerId}
    Wait For Prompt On Uart         ${PROMPT}  timeout=${timeout}  testerId=${testerId}
    Check Exit Code                 ${testerId}

Boot And Login
    [Arguments]                     ${testerId}
    Wait For Line On Uart           Booting Linux on physical CPU 0x0  testerId=${testerId}
    Wait For Prompt On Uart         buildroot login:  timeout=25  testerId=${testerId}
    Write Line To Uart              root  testerId=${testerId}
    Wait For Prompt On Uart         ${PROMPT}  testerId=${testerId}

*** Test Cases ***
Should Pass Zephyr CAN Net Socket Test
    Create CAN Hub
    Create STM32H7 Machine    ${TESTS_NET_SOCKET_CAN_BIN}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL

Should Pass Zephyr CAN ISOTP Implementation Test
    Create CAN Hub
    Create STM32H7 Machine    ${TESTS_SUBSYS_CANBUS_ISOTP_IMPLEMENTATION_BIN}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL  timeout=20

Should Pass Zephyr CAN ISOTP Conformance Test
    Create CAN Hub
    Create STM32H7 Machine    ${TESTS_SUBSYS_CANBUS_ISOTP_CONFORMANCE_BIN}
    Create Terminal Tester    ${UART}

    Wait For Line On Uart     PROJECT EXECUTION SUCCESSFUL  timeout=12

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

Should Use CAN ISOTP Protocol To Exchange Messages In Loopback Mode
    Create CAN Hub
    Create STM32H7 Machine    ${SAMPLES_SUBSYS_CANBUS_ISOTP_LOOPBACK_BIN}
    Create Terminal Tester    ${UART}

    # Wait for several successful transmissions
    ${cnt}=                   Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     Got 247 bytes in total
        Wait For Line On Uart     TX complete cb [0]
        Wait For Line On Uart     This is the sample test for the short payload
    END

Should Use CAN ISOTP Protocol To Exchange Messages Between Machines
    Create CAN Hub            loopback=${False}
    Create STM32H7 Machine    ${SAMPLES_SUBSYS_CANBUS_ISOTP_NO_LOOPBACK_BIN}  machine-0
    ${tester-0}=              Create Terminal Tester  ${UART}  machine=machine-0
    # Lower quantum to keep synchronization between machines
    Execute Command           emulation SetGlobalQuantum "0.000025"
    Execute Command           emulation SetGlobalSerialExecution True

    Create STM32H7 Machine    ${SAMPLES_SUBSYS_CANBUS_ISOTP_NO_LOOPBACK_BIN}  machine-1
    ${tester-1}=              Create Terminal Tester  ${UART}  machine=machine-1

    # Wait for several successful transmissions
    ${cnt}=                   Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     Got 247 bytes in total  testerId=${tester-0}
        Wait For Line On Uart     Got 247 bytes in total  testerId=${tester-1}
        Wait For Line On Uart     TX complete cb [0]  testerId=${tester-0}
        Wait For Line On Uart     TX complete cb [0]  testerId=${tester-1}
        Wait For Line On Uart     This is the sample test for the short payload  testerId=${tester-0}
        Wait For Line On Uart     This is the sample test for the short payload  testerId=${tester-1}
    END

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
    Create CAN Hub            loopback=${False}
    Create STM32H7 Machine    ${SAMPLES_NET_SOCKETS_CAN_NO_LOOPBACK_BIN}  machine-0
    ${tester-0}=              Create Terminal Tester  ${UART}  machine=machine-0

    Create STM32H7 Machine    ${SAMPLES_NET_SOCKETS_CAN_NO_LOOPBACK_BIN}  machine-1
    ${tester-1}=              Create Terminal Tester  ${UART}  machine=machine-1
    Execute Command           emulation SetGlobalQuantum "0.000025"
    Execute Command           emulation SetGlobalSerialExecution True

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
    Create CAN Hub            loopback=${False}
    Create STM32H7 Machine    ${SAMPLES_DRIVERS_CAN_COUNTER_NO_LOOPBACK_BIN}  machine-0
    ${tester-0}=              Create Terminal Tester  ${UART}  machine=machine-0

    Create STM32H7 Machine    ${SAMPLES_DRIVERS_CAN_COUNTER_NO_LOOPBACK_BIN}  machine-1
    ${tester-1}=              Create Terminal Tester  ${UART}  machine=machine-1
    # Lower quantum to keep synchronization between machines
    Execute Command           emulation SetGlobalQuantum "0.000025"
    Execute Command           emulation SetGlobalSerialExecution True

    # Wait for several successful transmissions
    ${cnt}=                   Set Variable  40
    FOR  ${i}  IN RANGE  0  ${cnt}
        Wait For Line On Uart     Counter received: ${i}  testerId=${tester-0}
        Wait For Line On Uart     Counter received: ${i}  testerId=${tester-1}
    END

Should Boot Linux And Login With MCAN
    Create CAN Hub            loopback=${False}
    Create Zynq Machine       machine-0
    ${tester-0}=              Create Terminal Tester    ${ZYNQ_UART}  machine=machine-0
    Create Zynq Machine       machine-1
    ${tester-1}=              Create Terminal Tester    ${ZYNQ_UART}  machine=machine-1
    # Lower quantum to keep synchronization between machines
    Execute Command           emulation SetGlobalQuantum "0.000025"
    Execute Command           emulation SetGlobalSerialExecution True

    Boot And Login            ${tester-0}
    Boot And Login            ${tester-1}
    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk  testerId=${tester-0}
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk  testerId=${tester-1}

    Provides                        mcan-logged-in

Should Handle CAN Messages Issued Through CAN Utils Tools
    Requires                        mcan-logged-in

    ${tester-0}=                    Create Terminal Tester    ${ZYNQ_UART}  machine=machine-0
    ${tester-1}=                    Create Terminal Tester    ${ZYNQ_UART}  machine=machine-1

    Execute Linux Command           ip link set can0 up type can bitrate 125000 dbitrate 125000 fd on  testerId=${tester-0}
    Execute Linux Command           ip link set can0 up type can bitrate 125000 dbitrate 125000 fd on  testerId=${tester-1}

    # Send CAN frames
    Write Line To Uart              candump can0  testerId=${tester-0}
    Write Line To Uart              cansend can0 099#11223344AABBCCDD  testerId=${tester-1}  # Send classical CAN 2.0 frame
    Wait For Line On Uart           .*11 22 33 44 AA BB CC DD  treatAsRegex=true  testerId=${tester-0}
    Write Line To Uart              cansend can0 013##311223344AABBCCDD11223344  testerId=${tester-1}  # Send CAN FD frame
    Wait For Line On Uart           .*11 22 33 44 AA BB CC DD 11 22 33 44  treatAsRegex=true  testerId=${tester-0}
    # Send Control-C
    Send Key To Uart                0x03  testerId=${tester-0}

    # Send random messages of different type
    Write Line To Uart              candump can0  testerId=${tester-0}
    Write Line To Uart              cangen can0 -m -v  testerId=${tester-1}
    # Send Control-C
    Send Key To Uart                0x03  testerId=${tester-0}
    Send Key To Uart                0x03  testerId=${tester-1}

    Write Line To Uart              canfdtest -v can0  testerId=${tester-0}
    Write Line To Uart              canfdtest -g -v can0  testerId=${tester-1}
    Should Not Be On Uart           RX before TX!  testerId=${tester-1}  timeout=${10}
