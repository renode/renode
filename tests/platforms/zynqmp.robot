*** Settings ***
Library                                         tap_helper.py    # used for 'Preconfigure Macos' keyword

*** Variables ***
${LINUX_UART}                                   sysbus.uart1
${UBOOT_UART}                                   sysbus.uart1
${ZEPHYR_UART}                                  sysbus.uart0
${OPENAMP_UART}                                 sysbus.uart0
${LINUX_PROMPT}                                 \#${SPACE}
${ZEPHYR_PROMPT}                                uart:~$
${UBOOT_PROMPT}                                 ZynqMP r5>
${I2C_ECHO_ADDRESS}                             0x10

${URL_BASE}                                     https://dl.antmicro.com/projects/renode
${ZEPHYR_BASIC_SYS_HEAP}                        @${URL_BASE}/zephyr-basic_sys_heap-xilinx_zynqmp_r5.elf-s_438388-8991d33506751fe196ee3eb488144583ba0ccbd7
${ZEPHYR_COMPRESSION_LZ4}                       @${URL_BASE}/zephyr-compression_lz4-xilinx_zynqmp_r5.elf-s_862900-fbcf30b0880cabd5e807d9b166edb30af6292724
${ZEPHYR_CPP_SYNCHRONIZATION}                   @${URL_BASE}/zephyr-cpp_cpp_synchronization-xilinx_zynqmp_r5.elf-s_493632-f7cd8210dde1935690ba706dd4d56f51c369be37
${ZEPHYR_HELLO_WORLD}                           @${URL_BASE}/zephyr-hello_world-xilinx_zynqmp_r5.elf-s_388044-7673bd83fa331e9cab9281a0c000d9774479d4c4
${ZEPHYR_KERNEL_CONDITION_VARIABLES_CONDVAR}    @${URL_BASE}/zephyr-kernel_condition_variables_condvar-xilinx_zynqmp_r5.elf-s_495360-20c5dc4d6c886c51fde9ce2d4057966762d410c9
${ZEPHYR_KERNEL_CONDITION_VARIABLES_SIMPLE}     @${URL_BASE}/zephyr-kernel_condition_variables_simple-xilinx_zynqmp_r5.elf-s_493588-ff54eafc5f0aca434358a5c715058ad77166346b
${ZEPHYR_KERNEL_METAIRQ_DISPATCH}               @${URL_BASE}/zephyr-kernel_metairq_dispatch-xilinx_zynqmp_r5.elf-s_551952-d4792b65f1cb6e172cd4d653d4b373abd1366b92
${ZEPHYR_PHILOSOPHERS}                          @${URL_BASE}/zephyr-philosophers-xilinx_zynqmp_r5.elf-s_515508-f1bcfa0adcf29714365ae53609420644614298c9
${ZEPHYR_SYNCHRONIZATION}                       @${URL_BASE}/zephyr-synchronization-xilinx_zynqmp_r5.elf-s_409936-c67fa8fb36a0318e82a45e57f0c8436c6af4740d
${ZEPHYR_SHELL}                                 @${URL_BASE}/zephyr-subsys_shell_shell_module-xilinx_zynqmp_r5.elf-s_1310204-e0e970d25e7c5d471c1d2d308e3f30944c414490
${ZEPHYR_USERSPACE_HELLO_WORLD_NO_MPU}          @${URL_BASE}/zephyr-userspace_hello_world_user-xilinx_zynqmp_r5-no_mpu.elf-s_411848-1b3bc43849411db05745b5226bb64350ece53500
${ZEPHYR_TESTS_KERNEL_FPU_SHARING}              @${URL_BASE}/zephyr-kernel_fpu_sharing_generic-xilinx_zynqmp_r5.elf-s_515064-6f0345a25b12e1e8e5c130266ddd2568e3e7138f
${ZEPHYR_USERSPACE_HELLO_WORLD}                 @${URL_BASE}/zephyr-userspace_hello_world_user-xilinx_zynqmp_r5.elf-s_1032888-0009042615539a30dbe799896b96501d0f90ae84
${ZEPHYR_MPU_TEST}                              @${URL_BASE}/zephyr-arch_mpu_mpu_test-xilinx_zynqmp_r5.elf-s_1149568-ae2c8f6e5e8219564e4640c47cfef5e33fcf2ea4
${ZEPHYR_USERSPACE_PROD_CONSUMER}               @${URL_BASE}/zephyr-userspace_prod_consumer-xilinx_zynqmp_r5.elf-s_1343804-9f7520160bb347a15f01e1a25bd94c87007335af
${ZEPHYR_USERSPACE_SHARED_MEM}                  @${URL_BASE}/zephyr-userspace_shared_mem-xilinx_zynqmp_r5.elf-s_1081056-a43ec0a1353e21c55908bbed997d6a52b8d031fb
${LINUX_32BIT_ROOTFS}                           @${URL_BASE}/zynq--interface-tests-rootfs.ext2-s_16777216-191638e3b3832a81bebd21d555f67bf3a4d7882a
${UBOOT}                                        @${URL_BASE}/xilinx_zynqmp_r5--u-boot.elf-s_2227172-4d77b9622e19b3dcf205efffde87321422b5294c

*** Keywords ***
Create Linux Machine
    Execute Command                 include @scripts/single-node/zynqmp_linux.resc
    Execute Command                 machine SetSerialExecution True
    ${linux_tester}=                Create Terminal Tester          ${LINUX_UART}  defaultPauseEmulation=true

Create Linux Remoteproc Machine
    Execute Command                 include @scripts/single-node/zynqmp_remoteproc.resc
    Execute Command                 machine SetSerialExecution True
    ${linux_tester}=                Create Terminal Tester          ${LINUX_UART}  defaultPauseEmulation=true
    ${zephyr_tester}=               Create Terminal Tester          ${ZEPHYR_UART}  defaultPauseEmulation=true
    RETURN                          ${linux_tester}  ${zephyr_tester}

Create Linux OpenAMP Machine
    Execute Command                 include @scripts/single-node/zynqmp_openamp.resc
    Execute Command                 machine SetSerialExecution True
    ${linux_tester}=                Create Terminal Tester         ${LINUX_UART}    defaultPauseEmulation=true
    ${openamp_tester}=              Create Terminal Tester         ${OPENAMP_UART}  defaultPauseEmulation=true
    RETURN                          ${linux_tester}  ${openamp_tester}

Create Linux Docker Machine
    Execute Command                 include @scripts/single-node/zynqmp_docker.resc
    ${linux_tester}=                Create Terminal Tester          ${LINUX_UART}  defaultPauseEmulation=true

Create Linux 32-Bit Userspace Machine
    Execute Command                 $rootfs=${LINUX_32BIT_ROOTFS}
    Create Linux Machine

Create Linux SMMUv3 Machine
    Execute Command                 include @scripts/single-node/zynqmp_smmuv3.resc
    ${linux_tester}=                Create Terminal Tester          ${OPENAMP_UART}  defaultPauseEmulation=true

Create Zephyr Machine
    [Arguments]                     ${elf}  ${uart}=${ZEPHYR_UART}
    Execute Command                 set bin ${elf}
    Execute Command                 include @scripts/single-node/zynqmp_zephyr.resc
    Execute Command                 machine SetSerialExecution True
    ${zephyr_tester}=               Create Terminal Tester          ${uart}  defaultPauseEmulation=true

Boot U-Boot And Launch Linux
    Wait For Line On Uart           U-Boot 2023.01
    Wait For Line On Uart           Starting kernel ...

Boot Linux And Login
    [Arguments]                     ${testerId}=0
    # Verify that the GIC system register interface is not enabled
    # Wait for a message that gets logged early in boot, before any CPU features are printed
    Wait For Line On Uart           Booting Linux on physical CPU           testerId=${testerId}
    # Then run for a while looking for `CPU features: detected: GIC system register CPU interface`
    Should Not Be On Uart           GIC system register CPU interface       testerId=${testerId}  timeout=2
    # By waiting for the messages that follow all CPU feature printing with `timeout=0` we ensure
    # that the previous "Should Not Be On Uart" covered the printing of all of the CPU features
    # (all prints occurred before we finished waiting for completion of `Should Not Be On Uart`).
    # This also verifies SMP support.
    Wait For Line On Uart           SMP: Total of 4 processors activated    testerId=${testerId}  timeout=0
    Wait For Line On Uart           CPU: All CPU(s) started at EL2          testerId=${testerId}  timeout=0
    Wait For Prompt On Uart         buildroot login:                        testerId=${testerId}  timeout=50
    Write Line To Uart              root                                    testerId=${testerId}
    Wait For Prompt On Uart         ${LINUX_PROMPT}                         testerId=${testerId}

Check Exit Code
    [Arguments]                     ${testerId}=0
    Write Line To Uart              echo $?                                 testerId=${testerId}
    Wait For Line On Uart           0                                       testerId=${testerId}
    Wait For Prompt On Uart         ${LINUX_PROMPT}                         testerId=${testerId}

Execute Linux Command
    [Arguments]                     ${command}  ${testerId}=0  ${timeout}=5
    Write Line To Uart              ${command}                              testerId=${testerId}
    Wait For Prompt On Uart         ${LINUX_PROMPT}                         testerId=${testerId}  timeout=${timeout}
    Check Exit Code                 testerId=${testerId}

Execute Linux Command Non Blocking
    [Arguments]                     ${command}  ${testerId}=0
    Write Line To Uart              ${command}                              testerId=${testerId}

Should Pass Zephyr Test Suite
    [Arguments]                     ${testerId}=0
    Wait For Line On Uart           SUITE PASS - 100.00%                    testerId=${testerId}  timeout=40

*** Test Cases ***
Should Boot And Login
    Create Linux Machine

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Check if we see the other CPUs
    Write Line To Uart              nproc
    Wait For Line On Uart           4

    Provides                        linux-shell

Test Dirty Addresses Reduction
    [Tags]                          skip_host_arm
    Requires                        linux-shell
    Execute Command                 showAnalyzer uart1

    # The log below is on a Debug level and can come from any APU core.
    Create Log Tester               0
    Execute Command                 logLevel 0 cluster0.apu0
    Execute Command                 logLevel 0 cluster0.apu1
    Execute Command                 logLevel 0 cluster0.apu2
    Execute Command                 logLevel 0 cluster0.apu3

    Wait For Prompt On Uart         \#
    Write Line To Uart              du -sh /*
    Wait For Prompt On Uart         \#

    # No such log should be triggered by `du`. If the reduction logic is incorrectly waiting for RPU cores
    # to fetch dirty addresses, then the list has more than 60k addresses after boot and `du` adds 200k+
    # more. This results in two failed reduction log entries (128k and 256k) which won't be present if the
    # reduction logic works correctly.
    Should Not Be In Log            Attempted reduction of arm64 dirty addresses list failed

Should Detect I2C Peripherals
    Create Linux Machine

    Execute Command                 machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ i2c1 ${I2C_ECHO_ADDRESS}"

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Write Line To Uart              i2cdetect -yar 1
    Wait For Line On Uart           10: 10 --
    Wait For Prompt On Uart         ${LINUX_PROMPT}
    Check Exit Code

Should Communicate With I2C Echo Peripheral
    Create Linux Machine

    Execute Command                 machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ i2c1 ${I2C_ECHO_ADDRESS}"

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Write Line To Uart              i2ctransfer -ya 1 w3@${I2C_ECHO_ADDRESS} 0x01 0x23 0x45 r2
    Wait For Line On Uart           0x01 0x23
    Wait For Prompt On Uart         ${LINUX_PROMPT}
    Check Exit Code

Should Communicate With I2C Echo Peripheral From 32-Bit Userspace On 64-Bit Kernel
    Create Linux 32-Bit Userspace Machine

    Execute Command                 machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ i2c1 ${I2C_ECHO_ADDRESS}"

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    ${log}=                         Allocate Temporary File
    # It was checked empirically that i2ctransfer process is executed on apu2.
    # Determinism during the emulation is guaranteed by SerialExecution mode,
    # but it may end up on a different core if the boot flow is changed or binaries modified.
    Execute Command                 apu2 LogFile @${log}
    # Clear the TB cache so all instructions are translated and appear in the log
    Execute Command                 apu2 ClearTranslationCache
    Write Line To Uart              i2ctransfer -ya 1 w3@${I2C_ECHO_ADDRESS} 0x01 0x23 0x45 r2
    Wait For Line On Uart           0x01 0x23
    Wait For Prompt On Uart         ${LINUX_PROMPT}
    Execute Command                 apu2 LogFile null
    Check Exit Code

    # Assert that the TB log has no errors and includes A64 instructions (in the kernel),
    # as well as A32 and Thumb instructions (in userspace)

    # No errors
    ${x}=                           Grep File  ${log}  Disassembly error detected
    Should Be Empty                 ${x}

    # A64
    ${x}=                           Grep File  ${log}  d69f03e0 *eret
    Should Not Be Empty             ${x}

    # A32
    ${x}=                           Grep File  ${log}  e3500000 *cmp*r0, #0
    Should Not Be Empty             ${x}

    # T32
    ${x}=                           Grep File  ${log}  ba12 *rev*r2, r2
    Should Not Be Empty             ${x}

    # Assert that the kernel is 64-bit
    Execute Linux Command           [ $(uname -m) = aarch64 ]

    # Assert that some binaries are 32-bit (ehdr.e_machine == EM_ARM, or 0x28)
    Execute Linux Command           [ $(dd if=/bin/busybox bs=1 skip=18 count=2 | xxd -p) = 2800 ]
    Execute Linux Command           [ $(dd if=/usr/bin/v4l2-compliance bs=1 skip=18 count=2 | xxd -p) = 2800 ]
    Execute Linux Command           [ $(dd if=/usr/sbin/i2ctransfer bs=1 skip=18 count=2 | xxd -p) = 2800 ]

Should Support RTC
    Create Linux Machine

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Write Line To Uart              date; hwclock
    ${d}=                           Wait For Line On Uart  Thu Jan${SPACE*2}1 00:00:(\\d+) UTC 1970  treatAsRegex=true
    ${h}=                           Wait For Line On Uart  Thu Jan${SPACE*2}1 00:00:(\\d+) 1970${SPACE*2}0.000000 seconds  treatAsRegex=true

    # Allow for 1 second of difference between the hwclock and the kernel's view
    ${diff}=                        Evaluate  abs(int(${d.Groups[0]}) - int(${h.Groups[0]}))
    Should Be True                  ${diff} <= 1

Should Display Output on GPIO
    Create Linux Machine

    Execute Command                 machine LoadPlatformDescriptionFromString "gpio: { 7 -> heartbeat@0 }; heartbeat: Miscellaneous.LED @ gpio 7"
    Create LED Tester               sysbus.gpio.heartbeat  defaultTimeout=2

    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    Write Line To Uart              echo none > /sys/class/leds/heartbeat/trigger
    Write Line To Uart              echo 1 > /sys/class/leds/heartbeat/brightness
    Assert LED State                true
    Write Line To Uart              echo 0 > /sys/class/leds/heartbeat/brightness
    Assert LED State                false

Should Boot Zephyr
    Create Zephyr Machine           ${ZEPHYR_HELLO_WORLD}

    Wait For Line On Uart           *** Booting Zephyr OS build${SPACE*2}***

Should Print Hello World
    Create Zephyr Machine           ${ZEPHYR_HELLO_WORLD}

    Wait For Line On Uart           Hello World! qemu_cortex_r5

Should Decompress Lorem Ipsum
    Create Zephyr Machine           ${ZEPHYR_COMPRESSION_LZ4}

    Wait For Line On Uart           Original Data size: 1160
    Wait For Line On Uart           Compressed Data size : 895
    Wait For Line On Uart           Successfully decompressed some data
    Wait For Line On Uart           Validation done. The string we ended up with is:
    Wait For Line On Uart           Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque sodales lorem lorem, sed congue enim vehicula a. Sed finibus diam sed odio ultrices pharetra. Nullam dictum arcu ultricies turpis congue,vel venenatis turpis venenatis. Nam tempus arcu eros, ac congue libero tristique congue. Proin velit lectus, euismod sit amet quam in, maximus condimentum urna. Cras vel erat luctus, mattis orci ut, varius urna. Nam eu lobortis velit.
    Wait For Line On Uart           Nullam sit amet diam vel odio sodales cursus vehicula eu arcu. Proin fringilla, enim nec consectetur mollis, lorem orci interdum nisi, vitae suscipit nisi mauris eu mi. Proin diam enim, mollis ac rhoncus vitae, placerat et eros. Suspendisse convallis, ipsum nec rhoncus aliquam, ex augue ultrices nisl, id aliquet mi diam quis ante. Pellentesque venenatis ornare ultrices. Quisque et porttitor lectus. Ut venenatis nunc et urna imperdiet porttitor non laoreet massa.Donec eleifend eros in mi sagittis egestas. Sed et mi nunc. Nunc vulputate,mauris non ullamcorper viverra, lorem nulla vulputate diam, et congue dui velit non erat. Duis interdum leo et ipsum tempor consequat. In faucibus enim quis purus vulputate nullam.

Should Run System Heap Sample
    Create Zephyr Machine           ${ZEPHYR_BASIC_SYS_HEAP}

    Wait For Line On Uart           System heap sample
    Wait For Line On Uart           allocated 0, free 196, max allocated 0, heap size 256
    Wait For Line On Uart           allocated 156, free 36, max allocated 156, heap size 256
    Wait For Line On Uart           allocated 100, free 92, max allocated 156, heap size 256
    Wait For Line On Uart           allocated 0, free 196, max allocated 156, heap size 256

Should Complete MetaIRQ Test
    Create Zephyr Machine           ${ZEPHYR_KERNEL_METAIRQ_DISPATCH}

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
    Create Zephyr Machine           ${ZEPHYR_CPP_SYNCHRONIZATION}

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
    Create Zephyr Machine           ${ZEPHYR_SYNCHRONIZATION}

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
    Create Zephyr Machine           ${ZEPHYR_KERNEL_CONDITION_VARIABLES_CONDVAR}

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
    Create Zephyr Machine           ${ZEPHYR_KERNEL_CONDITION_VARIABLES_SIMPLE}

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
    Create Zephyr Machine           ${ZEPHYR_PHILOSOPHERS}

    FOR  ${p}  IN RANGE  0  5
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE*7}STARVING${SPACE*7}                                    treatAsRegex=true 
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE*3}HOLDING ONE FORK${SPACE*3}                            treatAsRegex=true 
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE*2}EATING${SPACE*2}\\[ ${SPACE}?\\d{1,3} ms \\]${SPACE}  treatAsRegex=true 
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE*3}DROPPED ONE FORK${SPACE*3}                            treatAsRegex=true 
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE}THINKING \\[ ${SPACE}?\\d{1,3} ms \\]${SPACE}           treatAsRegex=true 
    END

Should Interact Via Shell
    Create Zephyr Machine           ${ZEPHYR_SHELL}

    Wait For Prompt On Uart         ${ZEPHYR_PROMPT}
    Write Line To Uart              version
    Wait For Line On Uart           Zephyr version \\d+.\\d+.\\d+                                   treatAsRegex=true

    Wait For Prompt On Uart         ${ZEPHYR_PROMPT}
    Write Line To Uart              device list
    Wait For Line On Uart           devices:
    Wait For Line On Uart           - uart@ff000000 (READY)

    Wait For Prompt On Uart         ${ZEPHYR_PROMPT}
    Write Line To Uart              demo ping
    Wait For Line On Uart           pong

    Wait For Prompt On Uart         ${ZEPHYR_PROMPT}
    Write Line To Uart              history
    Wait For Line On Uart           [${SPACE*2}0] history
    Wait For Line On Uart           [${SPACE*2}1] demo ping
    Wait For Line On Uart           [${SPACE*2}2] device list
    Wait For Line On Uart           [${SPACE*2}3] version

    Wait For Prompt On Uart         ${ZEPHYR_PROMPT}
    Write Line To Uart              log_test start demo
    FOR  ${i}  IN RANGE  0  7
        Wait For Line On Uart           <inf> app: Timer expired.          treatAsRegex=true
        Wait For Line On Uart           <inf> app_test: info message       treatAsRegex=true
        Wait For Line On Uart           <wrn> app_test: warning message    treatAsRegex=true
        Wait For Line On Uart           <err> app_test: err message        treatAsRegex=true
    END
    Write Line To Uart              log_test stop

    Wait For Prompt On Uart         ${ZEPHYR_PROMPT}
    Write Line To Uart              date get
    Wait For Line On Uart           1970-01-01 \\d{2}:\\d{2}:\\d{2} UTC                             treatAsRegex=true
    Write Line To Uart              date set 2023-12-31 12:00:59
    Write Line To Uart              date get
    Wait For Line On Uart           2023-12-31 12:\\d{2}:\\d{2} UTC                                 treatAsRegex=true

Should Fail To Enter Userspace Without MPU
    Create Zephyr Machine           ${ZEPHYR_USERSPACE_HELLO_WORLD_NO_MPU}

    Wait For Line On Uart           Hello World from privileged mode. (qemu_cortex_r5)
    Wait For Line On Uart           ASSERTION FAIL [k_is_user_context()]
    Wait For Line On Uart           User mode execution was expected
    Wait For Line On Uart           E: >>> ZEPHYR FATAL ERROR 4: Kernel panic on CPU 0
    Wait For Line On Uart           E: Halting system

Should Print Hello World From Userspace
    Create Zephyr Machine           ${ZEPHYR_USERSPACE_HELLO_WORLD}

    Wait For Line On Uart           Hello World from UserSpace! (qemu_cortex_r5)

Should Pass Zephyr FPU Sharing Test
    Create Zephyr Machine           ${ZEPHYR_TESTS_KERNEL_FPU_SHARING}

    Should Pass Zephyr Test Suite

Should Rise Permission Fault On MPU Test Read
    Create Zephyr Machine           ${ZEPHYR_MPU_TEST}

    Wait For Prompt On Uart         ${ZEPHYR_PROMPT}
    Write Line To Uart              mpu write
    Wait For Line On Uart           write address: 0xc0004000

    Wait For Line On Uart           <err> os: ***** DATA ABORT *****
    Wait For Line On Uart           <err> os: Permission Fault @ 0xc0004000
    Wait For Line On Uart           <err> os: r0/a1:${SPACE*2}0x00000000${SPACE*2}r1/a2:${SPACE*2}0x0000000e${SPACE*2}r2/a3:${SPACE*2}0x00010538
    Wait For Line On Uart           <err> os: r3/a4:${SPACE*2}0x0badc0de r12/ip:${SPACE*2}0x[a-f0-9]+ r14/lr:${SPACE*2}0x00000f8f                  treatAsRegex=true
    Wait For Line On Uart           <err> os:${SPACE*2}xpsr:${SPACE*2}0x6000013f
    Wait For Line On Uart           <err> os: fpscr:${SPACE*2}0x00000000
    Wait For Line On Uart           <err> os: Faulting instruction address (r15/pc): 0x00000f90
    Wait For Line On Uart           <err> os: >>> ZEPHYR FATAL ERROR 48: Unknown error on CPU 0
    Wait For Line On Uart           <err> os: Current thread: 0x10538 (shell_uart)
    Wait For Line On Uart           <err> os: Halting system

Should Rise Background Fault On MPU Test Write
    Create Zephyr Machine           ${ZEPHYR_MPU_TEST}

    Wait For Prompt On Uart         ${ZEPHYR_PROMPT}
    Write Line To Uart              mpu read
    Wait For Line On Uart           <err> os: ***** DATA ABORT *****
    Wait For Line On Uart           <err> os: Background Fault @ 0x04000000
    Wait For Line On Uart           <err> os: r0/a1:${SPACE*2}0x0000a3bc${SPACE*2}r1/a2:${SPACE*2}0x00000008${SPACE*2}r2/a3:${SPACE*2}0x0000ace5
    Wait For Line On Uart           <err> os: r3/a4:${SPACE*2}0x04000000 r12/ip:${SPACE*2}0x[a-f0-9]+ r14/lr:${SPACE*2}0x0000371b                 treatAsRegex=true
    Wait For Line On Uart           <err> os:${SPACE*2}xpsr:${SPACE*2}0x2000013f
    Wait For Line On Uart           <err> os: fpscr:${SPACE*2}0x00000000
    Wait For Line On Uart           <err> os: Faulting instruction address (r15/pc): 0x00000fae
    Wait For Line On Uart           <err> os: >>> ZEPHYR FATAL ERROR 47: Unknown error on CPU 0
    Wait For Line On Uart           <err> os: Current thread: 0x10538 (shell_uart)
    Wait For Line On Uart           <err> os: Halting system

Should Successfully Run Producer Consumer Sample In Userspace
    Create Zephyr Machine           ${ZEPHYR_USERSPACE_PROD_CONSUMER}

    Wait For Line On Uart           I: SUCCESS

Should Pass Messages Between Threads
    Create Zephyr Machine           ${ZEPHYR_USERSPACE_SHARED_MEM}

    Wait For Line On Uart           ENC Thread Created 0x104e0
    Wait For Line On Uart           Partitions added to enc_domain
    Wait For Line On Uart           enc_domain Created
    Wait For Line On Uart           PT Thread Created 0x103e0
    Wait For Line On Uart           pt_domain Created
    Wait For Line On Uart           CT Thread Created 0x102e0
    Wait For Line On Uart           ct partitions installed
    Wait For Line On Uart           blk partitions installed
    Wait For Line On Uart           ENC thread started
    Wait For Line On Uart           PT thread started

    FOR  ${i}  IN RANGE  0  3
        Wait For Line On Uart           PT Sending Message 1
        Wait For Line On Uart           ENC Thread Received Data
        Wait For Line On Uart           ENC PT MSG: PT: message to encrypt

        Wait For Line On Uart           CT Thread Received Message
        Wait For Line On Uart           CT MSG: ofttbhfspgmeqzos

        Wait For Line On Uart           PT Sending Message 1'
        Wait For Line On Uart           ENC Thread Received Data
        Wait For Line On Uart           ENC PT MSG: ofttbhfspgmeqzos

        Wait For Line On Uart           CT Thread Received Message
        Wait For Line On Uart           CT MSG: messagetoencrypt
    END

    Provides                        userspace_shared_mem-zephyr

Should Pass Messages Between Threads From Serialized State
    Requires                        userspace_shared_mem-zephyr
    Clear Terminal Tester Report

    Wait For Line On Uart           PT Sending Message 1
    Wait For Line On Uart           ENC Thread Received Data
    Wait For Line On Uart           ENC PT MSG: PT: message to encrypt

    Wait For Line On Uart           CT Thread Received Message
    Wait For Line On Uart           CT MSG: ofttbhfspgmeqzos

    Wait For Line On Uart           PT Sending Message 1'
    Wait For Line On Uart           ENC Thread Received Data
    Wait For Line On Uart           ENC PT MSG: ofttbhfspgmeqzos

    Wait For Line On Uart           CT Thread Received Message
    Wait For Line On Uart           CT MSG: messagetoencrypt

Should Provide Booted U-Boot And Run Version Command
    Create Zephyr Machine           ${UBOOT}  ${UBOOT_UART}

    Wait For Prompt On Uart         ${UBOOT_PROMPT}

    Provides                        booted-uboot

    Write Line To Uart              version
    Wait For Line On Uart           U-Boot

    Wait For Prompt On Uart         ${UBOOT_PROMPT}

Should Run Version Command On Provided U-Boot
    Requires                        booted-uboot

    Write Line To Uart              version
    Wait For Line On Uart           U-Boot

    Wait For Prompt On Uart         ${UBOOT_PROMPT}

Should Start And Stop Remoteproc
    ${linux_tester}  ${zephyr_tester}=  Create Linux Remoteproc Machine
    Boot Linux And Login                testerId=${linux_tester}

    # Load remoteproc kernel module and start demo
    Execute Linux Command               modprobe zynqmp_r5_remoteproc                                       testerId=${linux_tester}
    Execute Linux Command               mkdir /lib/firmware                                                 testerId=${linux_tester}
    Execute Linux Command               cp /elfs/philosophers.elf /lib/firmware                             testerId=${linux_tester}
    Execute Linux Command               echo philosophers.elf > /sys/class/remoteproc/remoteproc0/firmware  testerId=${linux_tester}
    Execute Linux Command               echo start > /sys/class/remoteproc/remoteproc0/state                testerId=${linux_tester}

    # Check if demo works correctly
    FOR  ${p}  IN RANGE  0  5
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE*7}STARVING${SPACE*7}                                    testerId=${zephyr_tester}  treatAsRegex=true 
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE*3}HOLDING ONE FORK${SPACE*3}                            testerId=${zephyr_tester}  treatAsRegex=true 
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE*2}EATING${SPACE*2}\\[ ${SPACE}?\\d{1,3} ms \\]${SPACE}  testerId=${zephyr_tester}  treatAsRegex=true 
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE*3}DROPPED ONE FORK${SPACE*3}                            testerId=${zephyr_tester}  treatAsRegex=true 
            Wait For Line On Uart   Philosopher ${p} \\[[PC]:[ -]\\d\\] ${SPACE}THINKING \\[ ${SPACE}?\\d{1,3} ms \\]${SPACE}           testerId=${zephyr_tester}  treatAsRegex=true 
    END

    # Stop demo
    Execute Linux Command               echo stop > /sys/class/remoteproc/remoteproc0/state                 testerId=${linux_tester}
    Sleep                               1s
    ${is_halted}=  Execute Command      rpu0 IsHalted
    Should Contain                      ${is_halted}    True

Should Run OpenAMP Echo Sample
    ${linux_tester}  ${openamp_tester}=     Create Linux OpenAMP Machine
    Boot Linux And Login                    testerId=${linux_tester}

    # Load remoteproc kernel module and start demo
    Execute Linux Command                   modprobe zynqmp_r5_remoteproc                                       testerId=${linux_tester}
    Execute Linux Command                   echo rpmsg-echo.out > /sys/class/remoteproc/remoteproc0/firmware    testerId=${linux_tester}
    Execute Linux Command                   echo start > /sys/class/remoteproc/remoteproc0/state                testerId=${linux_tester}
    Execute Linux Command Non Blocking      ./echo_test                                                         testerId=${linux_tester}

    # Check if demo works correctly
    Wait For Line On Uart                   Echo Test Round 0                                                   testerId=${linux_tester}
    FOR  ${i}  IN RANGE  0  471
            Wait For Line On Uart           sending payload number ${i} of size ${i + 17}                       testerId=${linux_tester}
            Wait For Line On Uart           echo test: sent : ${i + 17}                                         testerId=${linux_tester}
            Wait For Line On Uart           received payload number ${i} of size ${i + 17}                      testerId=${linux_tester}
    END
    Wait For Line On Uart                   Echo Test Round 0 Test Results: Error count = 0                     testerId=${linux_tester}

Should Run Web Server In Docker
    Create Linux Docker Machine
    Boot Linux And Login

    # The Docker daemon is not ready to accept connections as soon as the
    # init script finishes; give it a while to warm up.
    Execute Linux Command                   until docker ps; do sleep 1; done                                   timeout=10
    Execute Linux Command                   docker load < /docker/webserver.tar
    Execute Linux Command                   docker run --name webserver -d -p 80:80 localhost/webserver

    Execute Linux Command Non Blocking      wget -O - http://localhost
    Wait For Line On Uart                   <html><body><h1>Hello, world!</h1></body></html>

    Execute Linux Command Non Blocking      docker logs webserver
    Wait For Line On Uart                   response:200

Should Ping Over TAP Using An Ethernet Adapter Behind The SMMUv3
    [Tags]                                  tap
    Create Linux SMMUv3 Machine
    Boot Linux And Login

    # Prepare TAP
    Set Test Variable                       ${TAP_INTERFACE}  tap0
    Set Test Variable                       ${TAP_INTERFACE_IP}  192.0.2.1
    Set Test Variable                       ${SERVER_IP}  192.0.2.2

    Execute Command                         emulation CreateSwitch "switch"
    Execute Command                         emulation CreateTap "${TAP_INTERFACE}" "tap"

    Preconfigure Macos                      tap0  ${TAP_INTERFACE_IP}  255.255.255.0
    Network Interface Should Have Address   ${TAP_INTERFACE}  ${TAP_INTERFACE_IP}

    Execute Command                         connector Connect host.tap switch
    Execute Command                         connector Connect gem3 switch

    Execute Linux Command                   ifconfig eth0 up ${SERVER_IP}

    Write Line To Uart                      ping -c 5 ${TAP_INTERFACE_IP}
    Wait For Line On Uart                   5 packets transmitted, 5 packets received, 0% packet loss
