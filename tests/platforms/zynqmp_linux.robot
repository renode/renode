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
