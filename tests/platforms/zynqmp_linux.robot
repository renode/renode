*** Settings ***
# Contains variables: LINUX_PROMPT
# Contains keywords: Boot Linux And Login, Check Exit Code, Execute Login Command
Resource                            zynqmp.resource

*** Variables ***
${I2C_ECHO_ADDRESS}                 0x10
${LINUX_UART}                       sysbus.uart1

${URL_BASE}                         https://dl.antmicro.com/projects/renode
${LINUX_32BIT_ROOTFS}               @${URL_BASE}/zynq--interface-tests-rootfs.ext2-s_16777216-191638e3b3832a81bebd21d555f67bf3a4d7882a

*** Keywords ***
Boot U-Boot And Launch Linux
    Wait For Line On Uart           U-Boot 2023.01
    Wait For Line On Uart           Starting kernel ...

Create Linux Machine
    Execute Command                 include @scripts/single-node/zynqmp_linux.resc
    Execute Command                 machine SetSerialExecution True
    ${linux_tester}=                Create Terminal Tester          ${LINUX_UART}  defaultPauseEmulation=true

Create Linux 32-Bit Userspace Machine
    Execute Command                 $rootfs=${LINUX_32BIT_ROOTFS}
    Create Linux Machine

Should Reboot To Linux
    [Arguments]    ${scope}  ${ipi_registers}  ${reset_ipi_state}

    ${rpu_r0}=                      Set Variable  0xDEADCAFE
    Execute Command                 rpu0 SetRegister "R0" ${rpu_r0}
    Execute Command                 rpu1 SetRegister "R0" ${rpu_r0}
    Execute Command                 rpuGic DisabledSecurity True

    # Except for "subsystem", which is an APU-only reset, RPUs, IPI etc. should be reset.
    ${expected_ipi_state}=          Set Variable  ${reset_ipi_state}
    ${expected_gic_disabled}=       Set Variable  False
    ${expected_rpu_r0}=             Set Variable  0x0

    IF    $scope == "subsystem"
        # There should be no changes compared to before reboot.
        &{expected_ipi_state}=      Dump Devices Registers  ${ipi_registers}
        ${expected_gic_disabled}=   Set Variable  True
        ${expected_rpu_r0}=         Set Variable  ${rpu_r0}
        ${log_scope}=               Set Variable  ApuSubsystem
    ELSE IF    $scope == "ps_only"
        ${log_scope}=               Set Variable  ProcessingSystem
    ELSE IF    $scope == "system"
        ${log_scope}=               Set Variable  System
    ELSE
        Fail                        Invalid scope: ${scope}
    END

    Write Line To Uart              echo ${scope} > /sys/devices/platform/firmware\:zynqmp-firmware/shutdown_scope
    Write Line To Uart              reboot

    Wait For Log Entry              ipi.platformManagementUnit: System was reset due to the SystemShutdown request (type: Restart, scope: ${log_scope})

    &{ipi_state}=                   Dump Devices Registers  ${ipi_registers}
    Devices Registers Dump Should Be Equal
    ...                             ${ipi_state}  ${expected_ipi_state}  "Reboot"  "Expected"
    ${gic_disabled}=                Execute Command  rpuGic DisabledSecurity
    ${gic_disabled}=                Strip String  ${gic_disabled}
    Should Be Equal As Strings      ${gic_disabled}  ${expected_gic_disabled}
    Register Should Be Equal        R0  ${expected_rpu_r0}  cpuName=rpu0
    Register Should Be Equal        R0  ${expected_rpu_r0}  cpuName=rpu1

    Should Boot And Login

Should Boot And Login
    Boot U-Boot And Launch Linux
    Boot Linux And Login

    # Check if we see the other CPUs
    Write Line To Uart              nproc
    Wait For Line On Uart           4

*** Test Cases ***
Should Boot And Login With All CPUs
    Create Linux Machine
    Should Boot And Login

    Provides                        linux-shell

Should Reboot To Linux In System And APU-only modes
    Create Linux Machine
    Create Log Tester               5  defaultPauseEmulation=true

    ${ipi_registers_list}=          Catenate  SEPARATOR=${SPACE}
    ...    [(x, x+0x14) for x in range(0x0, 0x80000, 0x10000)] +
    ...    [(x, x+0x14) for x in [0x31000, 0x32000, 0x33000]]
    ${ipi_registers_list}=          Evaluate  ${ipi_registers_list}

    # 0x18-0x1C registers are present but write-only.
    ${ipi_registers}=               Create Dictionary  ipi=${{ $ipi_registers_list }}
    &{reset_ipi_state}=             Dump Devices Registers  ${ipi_registers}

    Should Boot And Login

    # We don't check `ps_only` mode because the only difference with `system` is that it
    # keeps ZynqMP's FPGA intact so currently in Renode those two modes work the same.
    Should Reboot To Linux          subsystem  ${ipi_registers}  ${reset_ipi_state}
    Should Reboot To Linux          system  ${ipi_registers}  ${reset_ipi_state}

Test Dirty Addresses Reduction
    [Tags]                          exclude_host_aarch64
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
    Execute Command                 ${LINUX_UART} CharacterTransmitDelayMicroseconds 20

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
    Execute Command                 $bootargs="earlycon console=ttyPS1,115200n8 root=/dev/ram0 rw initrd=0x20000000,64M nr_cpus=1"
    Create Linux 32-Bit Userspace Machine

    Execute Command                 machine LoadPlatformDescriptionFromString "i2cEcho: Mocks.EchoI2CDevice @ i2c1 ${I2C_ECHO_ADDRESS}"

    Boot U-Boot And Launch Linux
    Boot Linux And Login            smp_count=1

    # Suppress messages from the kernel space
    Execute Linux Command           echo 0 > /proc/sys/kernel/printk

    ${log}=                         Allocate Temporary File
    # Linux is booted with `nr_cpus=1` to guarantee that i2ctransfer will be executed on apu0
    Execute Command                 apu0 LogFile @${log}
    # Clear the TB cache so all instructions are translated and appear in the log
    Execute Command                 apu0 ClearTranslationCache
    Write Line To Uart              i2ctransfer -ya 1 w3@${I2C_ECHO_ADDRESS} 0x01 0x23 0x45 r2
    Wait For Line On Uart           0x01 0x23
    Wait For Prompt On Uart         ${LINUX_PROMPT}
    Execute Command                 apu0 LogFile null
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

VCU Should Return Encoded Buffers Through DMA
    Execute Command                 include @scripts/single-node/zynqmp_vcu.resc
    ${frame_dump_directory}=        Allocate Temporary Directory  zynqmp_vcu_frames
    Execute Command                 allegro FrameDumpDirectory "${frame_dump_directory}"
    # Intentionally make encoder pipeline creation fail to force the model to output its own fake NALUs,
    # so we can reproducibly hash the output file in the guest and test encoded buffer return DMA without
    # taking a dependency on the exact host codec.
    Execute Command                 allegro H264Encoder "nonexistent-encoder-to-force-failure"
    Create Terminal Tester          sysbus.uart0  defaultPauseEmulation=true  timeout=50
    Start Emulation

    Wait For Prompt On Uart         zcu106-zynqmp login:
    Write Line To Uart              root
    Wait For Prompt On Uart         ${LINUX_PROMPT}
    Write Line To Uart              gst-launch-1.0 videotestsrc pattern=ball num-buffers=10 ! video/x-raw,width=128,height=128,format=NV12,framerate=60/1 ! omxh264enc ! filesink location=ball.h264  waitForEcho=false
    Wait For Prompt On Uart         ${LINUX_PROMPT}

    @{frames}=                      List Files In Directory  ${frame_dump_directory}  pattern=*.nv12  absolute=${True}
    Sort List                       ${frames}
    Length Should Be                ${frames}  10
    ${digest}=                      Evaluate  hashlib.sha256(b''.join(pathlib.Path(path).read_bytes() for path in $frames)).hexdigest()  modules=hashlib,pathlib
    Should Be Equal                 ${digest}  8ec5e456420b44a606f68e8e9fc6b52805529680b7cfd085b3663893b5a08af2

    Write Line To Uart              sha256sum ball.h264
    Wait For Line On Uart           e5ba3b78a2dc5563243f19190537ecb4b5e77805e59acf2172f01d88d6d3d3c9
