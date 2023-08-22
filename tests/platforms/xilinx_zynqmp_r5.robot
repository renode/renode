*** Variables ***
${UART}                                         sysbus.uart0
${PROMPT}                                       uart:~$
${URL}                                          https://dl.antmicro.com/projects/renode
# Note that following samples are built with MPU disabled (CONFIG_ARM_MPU=n)
${ZEPHYR_BASIC_SYS_HEAP}                        @${URL}/zephyr-basic_sys_heap-xilinx_zynqmp_r5-no_mpu.elf-s_410328-41429bd6fb58f0e8f730ba86a8775b15f134b9f3
${ZEPHYR_COMPRESSION_LZ4}                       @${URL}/zephyr-compression_lz4-xilinx_zynqmp_r5-no_mpu.elf-s_827328-11c6e8c49708288cc39388f860139153ac2473d8
${ZEPHYR_CPP_SYNCHRONIZATION}                   @${URL}/zephyr-cpp_cpp_synchronization-xilinx_zynqmp_r5-no_mpu.elf-s_466404-10b2e4a27fb049979b0819c52be3fede42d9c438
${ZEPHYR_HELLO_WORLD}                           @${URL}/zephyr-hello_world-xilinx_zynqmp_r5-no_mpu.elf-s_357852-c165e28a3fa2fe42ba53ffcb916e3773cceb952f
${ZEPHYR_KERNEL_CONDITION_VARIABLES_CONDVAR}    @${URL}/zephyr-kernel_condition_variables_condvar-xilinx_zynqmp_r5-no_mpu.elf-s_457628-11da822aa2a8573d790f3d333ee690b2185bf37e
${ZEPHYR_KERNEL_CONDITION_VARIABLES_SIMPLE}     @${URL}/zephyr-kernel_condition_variables_simple-xilinx_zynqmp_r5-no_mpu.elf-s_455128-fc84bb8dc69870ec4bade073fdcec507407e0583
${ZEPHYR_KERNEL_METAIRQ_DISPATCH}               @${URL}/zephyr-kernel_metairq_dispatch-xilinx_zynqmp_r5-no_mpu.elf-s_515944-d9169f147a260f8e726e6fc9256e605abd1af4d9
${ZEPHYR_PHILOSOPHERS}                          @${URL}/zephyr-philosophers-xilinx_zynqmp_r5-no_mpu.elf-s_478248-ddb0b782d2bc6d39d81295a53a4866d5d4780d99
${ZEPHYR_SYNCHRONIZATION}                       @${URL}/zephyr-synchronization-xilinx_zynqmp_r5-no_mpu.elf-s_381160-e91943b548e98c8368e823ff6746602dcea9b875
${ZEPHYR_SHELL}                                 @${URL}/zephyr-subsys_shell_shell_module-xilinx_zynqmp_r5-no_mpu.elf-s_1271676-ef03382599f6f99c4de14d1306e8a706d3cd5a0c
${ZEPHYR_USERSPACE_HELLO_WORLD_NO_MPU}          @${URL}/zephyr-userspace_hello_world_user-xilinx_zynqmp_r5-no_mpu.elf-s_411848-1b3bc43849411db05745b5226bb64350ece53500
${ZEPHYR_TESTS_KERNEL_FPU_SHARING}              @${URL}/zephyr-fpu_sharing-xilinx_zynqmp_r5-no_mpu.elf-s_480700-2e936ebba4e2980977679bbfccd248cf4d80a9be

*** Keywords ***
Create Machine
    [Arguments]                     ${elf}
    Execute Command                 set bin ${elf}
    Execute Command                 include @scripts/single-node/xilinx_zynqmp_r5.resc
    Create Terminal Tester          ${UART}

Should Pass Zephyr Test Suite
    Wait For Line On Uart           SUITE PASS - 100.00%  timeout=40

*** Test Cases ***
Should Boot Zephyr
    Create Machine                  ${ZEPHYR_HELLO_WORLD}
    Start Emulation
    Wait For Line On Uart           *** Booting Zephyr OS build${SPACE*2}***

Should Print Hello World
    Create Machine                  ${ZEPHYR_HELLO_WORLD}
    Start Emulation
    Wait For Line On Uart           Hello World! qemu_cortex_r5

Should Decompress Lorem Ipsum
    Create Machine                  ${ZEPHYR_COMPRESSION_LZ4}
    Start Emulation
    Wait For Line On Uart           Original Data size: 1160
    Wait For Line On Uart           Compressed Data size : 895
    Wait For Line On Uart           Successfully decompressed some data
    Wait For Line On Uart           Validation done. The string we ended up with is:
    Wait For Line On Uart           Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque sodales lorem lorem, sed congue enim vehicula a. Sed finibus diam sed odio ultrices pharetra. Nullam dictum arcu ultricies turpis congue,vel venenatis turpis venenatis. Nam tempus arcu eros, ac congue libero tristique congue. Proin velit lectus, euismod sit amet quam in, maximus condimentum urna. Cras vel erat luctus, mattis orci ut, varius urna. Nam eu lobortis velit.
    Wait For Line On Uart           Nullam sit amet diam vel odio sodales cursus vehicula eu arcu. Proin fringilla, enim nec consectetur mollis, lorem orci interdum nisi, vitae suscipit nisi mauris eu mi. Proin diam enim, mollis ac rhoncus vitae, placerat et eros. Suspendisse convallis, ipsum nec rhoncus aliquam, ex augue ultrices nisl, id aliquet mi diam quis ante. Pellentesque venenatis ornare ultrices. Quisque et porttitor lectus. Ut venenatis nunc et urna imperdiet porttitor non laoreet massa.Donec eleifend eros in mi sagittis egestas. Sed et mi nunc. Nunc vulputate,mauris non ullamcorper viverra, lorem nulla vulputate diam, et congue dui velit non erat. Duis interdum leo et ipsum tempor consequat. In faucibus enim quis purus vulputate nullam.

Should Run System Heap Sample
    Create Machine                  ${ZEPHYR_BASIC_SYS_HEAP}
    Start Emulation
    Wait For Line On Uart           System heap sample
    Wait For Line On Uart           allocated 0, free 196, max allocated 0, heap size 256
    Wait For Line On Uart           allocated 156, free 36, max allocated 156, heap size 256
    Wait For Line On Uart           allocated 100, free 92, max allocated 156, heap size 256
    Wait For Line On Uart           allocated 0, free 196, max allocated 156, heap size 256

Should Complete MetaIRQ Test
    Create Machine                  ${ZEPHYR_KERNEL_METAIRQ_DISPATCH}
    Start Emulation
    Wait For Line On Uart           I: Starting Thread0 at priority -2
    Wait For Line On Uart           I: Starting Thread1 at priority -1
    Wait For Line On Uart           I: Starting Thread2 at priority 0
    Wait For Line On Uart           I: Starting Thread3 at priority 1

    Wait For Line On Uart           I: M0 T[0-3] mirq \\d+ disp \\d+ proc \\d+ real \\d+            treatAsRegex=true
    Wait For Line On Uart           I: M7 T[0-3] mirq \\d+ disp \\d+ proc \\d+ real \\d+            treatAsRegex=true
    Wait For Line On Uart           I: M15 T[0-3] mirq \\d+ disp \\d+ proc \\d+ real \\d+           treatAsRegex=true

    Wait For Line On Uart           I:${SPACE*9}---------- Latency (cyc) ----------
    Wait For Line On Uart           I:${SPACE*13}Best${SPACE*4}Worst${SPACE*5}Mean${SPACE*4}Stdev
    Wait For Line On Uart           I: MetaIRQ +\\d+ +\\d+ +\\d+ +\\d+                              treatAsRegex=true
    Wait For Line On Uart           I: Thread0 +\\d+ +\\d+ +\\d+ +\\d+                              treatAsRegex=true
    Wait For Line On Uart           I: Thread1 +\\d+ +\\d+ +\\d+ +\\d+                              treatAsRegex=true
    Wait For Line On Uart           I: Thread2 +\\d+ +\\d+ +\\d+ +\\d+                              treatAsRegex=true
    Wait For Line On Uart           I: Thread3 +\\d+ +\\d+ +\\d+ +\\d+                              treatAsRegex=true
    Wait For Line On Uart           I: MetaIRQ Test Complete

Should Interleave Main And Cooperative Thread
    Create Machine                  ${ZEPHYR_CPP_SYNCHRONIZATION}
    Start Emulation
    Wait For Line On Uart           Create semaphore 0x[a-f0-9]+                                    treatAsRegex=true
    Wait For Line On Uart           Create semaphore 0x[a-f0-9]+                                    treatAsRegex=true
    Wait For Line On Uart           main: Hello World!
    Wait For Line On Uart           coop_thread_entry: Hello World!
    Wait For Line On Uart           main: Hello World!
    Wait For Line On Uart           coop_thread_entry: Hello World!
    Wait For Line On Uart           main: Hello World!
    Wait For Line On Uart           coop_thread_entry: Hello World!
    Wait For Line On Uart           main: Hello World!
    Wait For Line On Uart           coop_thread_entry: Hello World!
    Wait For Line On Uart           main: Hello World!
    Wait For Line On Uart           coop_thread_entry: Hello World!

Should Interleave Concurrent Threads
    Create Machine                  ${ZEPHYR_SYNCHRONIZATION}
    Start Emulation
    Wait For Line On Uart           thread_a: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_b: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_a: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_b: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_a: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_b: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_a: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_b: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_a: Hello World from cpu 0 on qemu_cortex_r5!
    Wait For Line On Uart           thread_b: Hello World from cpu 0 on qemu_cortex_r5!

Should Run Kernel Condition Variables Condvar Sample
    Create Machine                  ${ZEPHYR_KERNEL_CONDITION_VARIABLES_CONDVAR}
    Start Emulation
    Wait For Line On Uart           Starting watch_count: thread 1
    Wait For Line On Uart           watch_count: thread 1 Count= 0. Going into wait...
    Wait For Line On Uart           inc_count: thread 2, count = 1, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 2, unlocking mutex
    Wait For Line On Uart           inc_count: thread 2, count = 3, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 4, unlocking mutex
    Wait For Line On Uart           inc_count: thread 2, count = 5, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 6, unlocking mutex
    Wait For Line On Uart           inc_count: thread 2, count = 7, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 8, unlocking mutex
    Wait For Line On Uart           inc_count: thread 2, count = 9, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 10, unlocking mutex
    Wait For Line On Uart           inc_count: thread 2, count = 11, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 12${SPACE*2}Threshold reached.Just sent signal.
    Wait For Line On Uart           inc_count: thread 3, count = 12, unlocking mutex
    Wait For Line On Uart           watch_count: thread 1 Condition signal received. Count= 12
    Wait For Line On Uart           watch_count: thread 1 Updating the value of count...
    Wait For Line On Uart           watch_count: thread 1 count now = 137.
    Wait For Line On Uart           watch_count: thread 1 Unlocking mutex.
    Wait For Line On Uart           inc_count: thread 2, count = 138, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 139, unlocking mutex
    Wait For Line On Uart           inc_count: thread 2, count = 140, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 141, unlocking mutex
    Wait For Line On Uart           inc_count: thread 2, count = 142, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 143, unlocking mutex
    Wait For Line On Uart           inc_count: thread 2, count = 144, unlocking mutex
    Wait For Line On Uart           inc_count: thread 3, count = 145, unlocking mutex
    Wait For Line On Uart           Main(): Waited and joined with 3 threads. Final value of count = 145. Done.

Should Run Kernel Condition Variables Simple Sample
    Create Machine                  ${ZEPHYR_KERNEL_CONDITION_VARIABLES_SIMPLE}
    Start Emulation

    FOR  ${i}  IN RANGE  0  1
        FOR  ${t}  IN RANGE  0  19
            Wait For Line On Uart   [thread ${t}] working (${i}/5)
        END
    END

    Wait For Line On Uart           [thread main] done is 0 which is < 20 so waiting on cond

    FOR  ${i}  IN RANGE  2  4
        FOR  ${t}  IN RANGE  0  19
            Wait For Line On Uart   [thread ${t}] working (${i}/5)
        END
    END

    FOR  ${t}  IN RANGE  0  18
        Wait For Line On Uart       [thread ${t}] done is now ${t + 1}. Signalling cond.
        Wait For Line On Uart       [thread main] wake - cond was signalled.
        Wait For Line On Uart       [thread main] done is ${t + 1} which is < 20 so waiting on cond
    END
    Wait For Line On Uart           [thread 19] done is now 20. Signalling cond.
    Wait For Line On Uart           [thread main] wake - cond was signalled.
    Wait For Line On Uart           [thread main] done == 20 so everyone is done

Should Run Philosophers Sample
    Create Machine                  ${ZEPHYR_PHILOSOPHERS}
    Start Emulation

    FOR  ${p}  IN RANGE  0  5
        FOR  ${state}  IN  ${SPACE*7}STARVING${SPACE*7}  ${SPACE*3}HOLDING ONE FORK${SPACE*3}  ${SPACE*2}EATING${SPACE*2}\\[ ${SPACE}?\\d{1,3} ms \\]${SPACE}  ${SPACE*3}DROPPED ONE FORK${SPACE*3}  ${SPACE}THINKING \\[ ${SPACE}?\\d{1,3} ms \\]${SPACE}
            Wait For Line On Uart   Philosopher 0 \\[[PC]:[ -]\\d\\] ${state}                       treatAsRegex=true
        END
    END

Should Interact Via Shell
    Create Machine                  ${ZEPHYR_SHELL}
    Start Emulation

    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              version
    Wait For Line On Uart           Zephyr version \\d+.\\d+.\\d+                                   treatAsRegex=true

    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              device list
    Wait For Line On Uart           devices:
    Wait For Line On Uart           - uart@ff000000 (READY)

    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              demo ping
    Wait For Line On Uart           pong

    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              history
    Wait For Line On Uart           [${SPACE*2}0] history
    Wait For Line On Uart           [${SPACE*2}1] demo ping
    Wait For Line On Uart           [${SPACE*2}2] device list
    Wait For Line On Uart           [${SPACE*2}3] version

    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              log_test start demo
    FOR  ${i}  IN RANGE  0  7
        Wait For Line On Uart           \\[\\d{2}:\\d{2}:\\d{2}.\\d{3},\\d{3}\\] <inf> app: Timer expired.          treatAsRegex=true
        Wait For Line On Uart           \\[\\d{2}:\\d{2}:\\d{2}.\\d{3},\\d{3}\\] <inf> app_test: info message       treatAsRegex=true
        Wait For Line On Uart           \\[\\d{2}:\\d{2}:\\d{2}.\\d{3},\\d{3}\\] <wrn> app_test: warning message    treatAsRegex=true
        Wait For Line On Uart           \\[\\d{2}:\\d{2}:\\d{2}.\\d{3},\\d{3}\\] <err> app_test: err message        treatAsRegex=true
    END
    Write Line To Uart              log_test stop

    Wait For Prompt On Uart         ${PROMPT}
    Write Line To Uart              date get
    Wait For Line On Uart           1970-01-01 \\d{2}:\\d{2}:\\d{2} UTC                             treatAsRegex=true
    Write Line To Uart              date set 2023-12-31 12:00:59
    Write Line To Uart              date get
    Wait For Line On Uart           2023-12-31 12:\\d{2}:\\d{2} UTC                                 treatAsRegex=true

Should Fail To Enter Userspace Without MPU
    Create Machine                  ${ZEPHYR_USERSPACE_HELLO_WORLD_NO_MPU}
    Start Emulation
    Wait For Line On Uart           Hello World from privileged mode. (qemu_cortex_r5)
    Wait For Line On Uart           ASSERTION FAIL [k_is_user_context()]
    Wait For Line On Uart           User mode execution was expected
    Wait For Line On Uart           E: >>> ZEPHYR FATAL ERROR 4: Kernel panic on CPU 0
    Wait For Line On Uart           E: Halting system

Should Pass Zephyr FPU Sharing Test
    Create Machine                  ${ZEPHYR_TESTS_KERNEL_FPU_SHARING}
    Start Emulation
    Should Pass Zephyr Test Suite
