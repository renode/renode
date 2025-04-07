*** Variables ***
${UART}                           sysbus.uart0
${URI}                            @https://dl.antmicro.com/projects/renode
${LINUX_PROMPT}                   \#${SPACE}

# DTBs are embedded in Coreboot+Linux ROMs. Built with Coreboot v4.20.1, ATF v2.9.0, Linux v6.3 and Buildroot 2023.08-rc1.
${COREBOOT_ARMv8A_ROM}                ${URI}/coreboot-without-payload-armv8a.rom-s_16777216-b5c6df85cfb8d240d31fe3cd1d055a3106d2fadb
${COREBOOT_ARMv8A_GICv2_ROM_LINUX}    ${URI}/coreboot-linux-armv8a-gicv2.rom-s_67108864-fb2ff9ba59a83cc29deecaf79d4fd3a62196be8a
${COREBOOT_ARMv8A_GICv3_ROM_LINUX}    ${URI}/coreboot-linux-armv8a-gicv3.rom-s_67108864-2348c80d6b871b9ac1916dfe0fd590125559ef73
${COREBOOT_ARMv8_2A_GICv3_ROM_LINUX}  ${URI}/coreboot-linux-armv8_2a-gicv3.rom-s_67108864-6643f8e84c2f6e9f8205d7f2d35142fad66cb959

${OREBOOT_GICv2_DTB}                  ${URI}/aarch64-oreboot-cortex-a53-gicv2.dtb-s_1402-91c68d88d35caf827e213fed170fcda80a3a3b96
${OREBOOT_GICv3_DTB}                  ${URI}/aarch64-oreboot-cortex-a53-gicv3.dtb-s_1394-6805aad03aeae232a620e6afa11d929f3a06bc95
${OREBOOT_LINUX_BIN}                  ${URI}/cortex_a53-oreboot-linux-rust-shell.bin-s_67108864-9bb5a940528af703ecd716dc99e39f543e7353a7

${UBOOT_DTB}                          ${URI}/cortex-a53-gicv2.dtb-s_1048576-2f0dd29f4be231d02cc1c99c7a85cf5c895b3b49
${UBOOT_ELF}                          ${URI}/cortex-a53-u-boot.elf-s_7272248-e9dbaeaa70ddf928ec69f822180703c8729398a5
${UBOOT_LINUX_IMAGE}                  ${URI}/cortex-a53-Image-s_12589568-b03715d3f08414d582a2467990dff7b4a7dd2213

*** Keywords ***
Create Machine
    [Arguments]    ${gic_version}=3    ${el2_el3_disabled}=False    ${gic_security_disabled}=False    ${cpu_model}=cortex-a53

    Execute Command               using sysbus
    Execute Command               mach create
    ${PLATFORM} =  Get File       ${CURDIR}/../../platforms/cpus/cortex-a53-gicv${gic_version}.repl
    IF  "${cpu_model}" != "cortex-a53"
        ${PLATFORM} =  Replace String    ${PLATFORM}  cortex-a53  ${cpu_model}
    END
    Execute Command               machine LoadPlatformDescriptionFromString """${PLATFORM}"""

    IF  ${el2_el3_disabled}
        Execute Command               cpu SetAvailableExceptionLevels false false
    END

    IF  ${gic_security_disabled}
        Execute Command               gic DisabledSecurity true
    END

    Create Terminal Tester        ${UART}  defaultPauseEmulation=true
    Execute Command               showAnalyzer ${UART}

Create Multicore Machine
    Execute Command                 include @scripts/single-node/cortex-a53-linux.resc
    Create Terminal Tester          ${UART}

Boot Linux And Login
    # Verify that SMP works
    Wait For Line On Uart           SMP: Total of 4 processors activated  includeUnfinishedLine=true
    Wait For Prompt On Uart         buildroot login:  timeout=50
    Write Line To Uart              root
    Wait For Prompt On Uart         ${LINUX_PROMPT}

Configure UART For Boot Logs
    [Arguments]    ${uart}

    # Set UART enable bit. The reset value is 0x300.
    Execute Command               ${uart} WriteDoubleWord 0x30 0x301
    # Set 7-bit word length to hush the warning that 5-bit WLEN is unsupported.
    Execute Command               ${uart} WriteDoubleWord 0x2c 0x40  #b10 << 5

Coreboot Should Load ATF
    Wait For Line On Uart         bootblock starting
    Wait For Line On Uart         romstage starting
    Wait For Line On Uart         ramstage starting
    Wait For Line On Uart         Relocating uncompressed kernel to 0x40000000
    Wait For Line On Uart         Entry Point 0x0e0a0000

ATF Should Jump To Linux
    [Arguments]    ${gic_version}=3

    Wait For Line On Uart         BL31: v2.9(release):v2.9.0
    IF  ${gic_version} == 2
        Wait For Line On Uart         ARM GICv2 driver initialized
    ELSE
        Wait For Line On Uart         GICv3 with legacy support detected.
        Wait For Line On Uart         ARM GICv3 driver initialized in EL3
    END
    Wait For Line On Uart         BL31: Preparing for EL3 exit to normal world

Linux Should Print CPU Model ID
    [Arguments]    ${cpu_model}=cortex-a53

    IF  "${cpu_model}" == "cortex-a53"
        ${cpu_model_id}=  Set Variable  0x410fd034
    ELSE IF  "${cpu_model}" == "cortex-a75"
        ${cpu_model_id}=  Set Variable  0x413fd0a1
    ELSE IF  "${cpu_model}" == "cortex-a76"
        ${cpu_model_id}=  Set Variable  0x414fd0b1
    ELSE IF  "${cpu_model}" == "cortex-a78"
        ${cpu_model_id}=  Set Variable  0x411fd412
    ELSE
        Fail  "No ID for the given CPU: ${cpu_model}"
    END

    Wait For Line On Uart         Booting Linux on physical CPU 0x0000000000 [${cpu_model_id}]

Linux Should Print GICv2 Info
    Wait For Line On Uart         GIC: Using split EOI/Deactivate mode

Linux Should Print GICv3 Info
    Wait For Line On Uart         GICv3: GIC: Using split EOI/Deactivate mode
    Wait For Line On Uart         GICv3: 960 SPIs implemented
    Wait For Line On Uart         GICv3: 0 Extended SPIs implemented
    Wait For Line On Uart         Root IRQ handler: gic_handle_irq
    Wait For Line On Uart         GICv3: GICv3 features: 16 PPIs
    Wait For Line On Uart         GICv3: CPU0: found redistributor 0 region 0:0x00000000080a0000

Linux Should Run Init Process
    [Arguments]    ${arch_timer_type}    ${cpu_start_el}    ${uart_irq}    ${perfevents_counters}=False
    ...            ${squashfs}=False    ${fuse}=False    ${virtio_mmio_devices}=False    ${check_rtc}=True

    Wait For Line On Uart         arch_timer: cp15 timer(s) running at 62.50MHz (${arch_timer_type}).

    Wait For Line On Uart         smp: Bringing up secondary CPUs ...
    Wait For Line On Uart         smp: Brought up 1 node, 1 CPU
    Wait For Line On Uart         SMP: Total of 1 processors activated.
    Wait For Line On Uart         CPU features: detected: 32-bit EL0 Support
    Wait For Line On Uart         CPU features: detected: CRC32 instructions

    Wait For Line On Uart         CPU: All CPU(s) started at EL${cpu_start_el}

    Wait For Line On Uart         Serial: AMBA PL011 UART driver

    Wait For Line On Uart         9000000.pl011: ttyAMA0 at MMIO 0x9000000 (irq = ${uart_irq}, base_baud = 0) is a PL011 rev3

    Wait For Line On Uart         printk: console [ttyAMA0] enabled

    # When comparing with the actual UART output be aware the whole log is sometimes printed again at this point.

    IF  ${virtio_mmio_devices}
        # Only the first of 32 was added to the platform to check if it can be successfully used to create virtio_blk device.
        # Initializing the remaining 31 results in 'Wrong magic value' logs.
        Wait For Line On Uart         virtio-mmio a000200.virtio_mmio: Wrong magic value 0x00000000
        Wait For Line On uart         virtio_blk virtio0: [vda] 0 512-byte logical blocks (0 B/0 B)
    END

    IF  ${check_rtc}
        Wait For Line On Uart         rtc-pl031 9010000.pl031: registered as rtc0
        # It can be the current date with 'machine RealTimeClockMode HostTimeUTC' but testing it here would be problematic.
        Wait For Line On Uart         rtc-pl031 9010000.pl031: setting system clock to 1970-01-01
    END

    Wait For Line On Uart         Freeing unused kernel memory

    # There are most probably problems with timer IRQs if the test fails to reach this line.
    Wait For Line On Uart         Run /init as init process

Linux Should Start Rust Userspace
    Wait For Line On Uart         The words I got: [Literal("#")]
    Wait For Line On Uart         rush: #: No such file or directory (os error 2)
    Wait For Line On Uart         The words I got: [Literal("ls")]
    Wait For Line On Uart         bin \ dev \ init \ proc \ sys
    Wait For Line On Uart         The words I got: [Literal("exec")]
    Wait For Line On Uart         The words I got: [Literal("sh")]
    Wait For Line On Uart         \#>  includeUnfinishedLine=true

    Write Line To Uart            ls
    Wait For Line On Uart         The words I got: [Literal("ls")]
    Wait For Line On Uart         bin \ dev \ init \ proc \ sys

Wait For Services And Enter Shell
    [Arguments]    ${with_network}=False

    Wait For Line On Uart         Starting syslogd: OK
    Wait For Line On Uart         Starting klogd: OK
    Wait For Line On Uart         Running sysctl: OK
    IF  ${with_network}
        Wait For Line On Uart         Starting network: Waiting for interface eth0 to appear  timeout=16
    END

    Wait For Line On Uart         Welcome to Buildroot
    Wait For Prompt On Uart       buildroot login:${SPACE}
    Write Line To Uart            root
    Wait For Prompt On Uart       \#${SPACE}

Shell Should Handle Basic Commands
    # Let's only match lines that don't contain any version.
    Write Line To Uart            cat /etc/os-release
    Wait For Line On Uart         Buildroot
    Wait For Prompt On Uart       \#${SPACE}

    Write Line To Uart            ls -1 /
    Wait For Line On Uart         bin
    Wait For Line On Uart         dev
    Wait For Line On Uart         etc
    Wait For Line On Uart         init

    ${before}=                    Wait For Prompt On Uart       \#${SPACE}

    Write Line To Uart            sleep 1
    ${after}=                     Wait For Prompt On Uart       \#${SPACE}
    # Timestamps are in milliseconds
    Should Be True                ${after.Timestamp} - ${before.Timestamp} > 1000
    Should Be True                ${after.Timestamp} - ${before.Timestamp} < 1050


Test Running Coreboot With Linux And ARM Trusted Firmware
    [Arguments]    ${cpu_model}    ${coreboot_rom}

    Create Machine                cpu_model=${cpu_model}
    Execute Command               sysbus LoadBinary ${coreboot_rom} 0x0
    Configure UART For Boot Logs  ${UART}

    Coreboot Should Load ATF
    ATF Should Jump To Linux

    Linux Should Print CPU Model ID  cpu_model=${cpu_model}
    Linux Should Print GICv3 Info
    Linux Should Run Init Process
    ...                           arch_timer_type=phys
    ...                           cpu_start_el=2
    ...                           uart_irq=14
    ...                           perfevents_counters=1
    ...                           squashfs=False
    ...                           fuse=True

    Wait For Services And Enter Shell
    Shell Should Handle Basic Commands

*** Test Cases ***
Test Running Coreboot Without Payload
    Create Machine
    Execute Command               sysbus LoadBinary ${COREBOOT_ARMv8A_ROM} 0x0
    Configure UART For Boot Logs  ${UART}

    Wait For Line On Uart         bootblock starting

    Wait For Line On Uart         romstage starting
    Wait For Line On Uart         ARM64: Exception handlers installed.
    Wait For Line On Uart         RAMDETECT: Found 1024 MiB RAM

    Wait For Line On Uart         ramstage starting
    # These three messages won't be shown, e.g., if accesses close to the end of RAM fail.
    Wait For Line On Uart         Timestamp - start of ramstage
    Wait For Line On Uart         Writing coreboot table
    Wait For Line On Uart         FMAP: area COREBOOT found

    Wait For Line On Uart         Payload not loaded.

Test Running Coreboot With Linux And ARM Trusted Firmware On Cortex-A53 With GICv2
    [Tags]                        basic-tests
    Create Machine                gic_version=2
    Execute Command               sysbus LoadBinary ${COREBOOT_ARMv8A_GICv2_ROM_LINUX} 0x0
    Configure UART For Boot Logs  ${UART}

    Coreboot Should Load ATF
    ATF Should Jump To Linux      gic_version=2

    Linux Should Print CPU Model ID
    Linux Should Print GICv2 Info
    Linux Should Run Init Process
    ...                           arch_timer_type=phys
    ...                           cpu_start_el=2
    ...                           uart_irq=14

    Wait For Services And Enter Shell
    Shell Should Handle Basic Commands

Test Running Coreboot With Linux And ARM Trusted Firmware On Cortex-A53
    Test Running Coreboot With Linux And ARM Trusted Firmware  cortex-a53  ${COREBOOT_ARMv8A_GICv3_ROM_LINUX}

Test Running Coreboot With Linux And ARM Trusted Firmware On Cortex-A75
    Test Running Coreboot With Linux And ARM Trusted Firmware  cortex-a75  ${COREBOOT_ARMv8_2A_GICv3_ROM_LINUX}

Test Running Coreboot With Linux And ARM Trusted Firmware On Cortex-A76
    Test Running Coreboot With Linux And ARM Trusted Firmware  cortex-a76  ${COREBOOT_ARMv8_2A_GICv3_ROM_LINUX}

Test Running Coreboot With Linux And ARM Trusted Firmware On Cortex-A78
    Test Running Coreboot With Linux And ARM Trusted Firmware  cortex-a78  ${COREBOOT_ARMv8_2A_GICv3_ROM_LINUX}

Test Running Oreboot With Linux And Rust Shell With GICv2
    Create Machine                gic_version=2  el2_el3_disabled=True  gic_security_disabled=True

    Execute Command               sysbus LoadBinary ${OREBOOT_GICv2_DTB} 0x40000000
    Execute Command               sysbus LoadBinary ${OREBOOT_LINUX_BIN} 0x0

    Configure UART For Boot Logs  ${UART}
    Execute Command               cpu.timer CounterFrequencyRegister 62500000

    Wait For Line On Uart         Welcome to oreboot
    Wait For Line On Uart         Not in EL3, jumping to payload

    Linux Should Print CPU Model ID

    # There are no details on GIC version.
    Wait For Line On Uart         NR_IRQS: 64, nr_irqs: 64, preallocated irqs: 0
    Wait For Line On Uart         Root IRQ handler: gic_handle_irq

    Linux Should Run Init Process
    ...                           arch_timer_type=virt
    ...                           cpu_start_el=1
    ...                           uart_irq=13
    ...                           check_rtc=False

    Linux Should Start Rust Userspace

Test Running Oreboot With Linux And Rust Shell With GICv3
    [Tags]                        basic-tests
    Create Machine                el2_el3_disabled=True  gic_security_disabled=True

    Execute Command               sysbus LoadBinary ${OREBOOT_GICv3_DTB} 0x40000000
    Execute Command               sysbus LoadBinary ${OREBOOT_LINUX_BIN} 0x0

    Configure UART For Boot Logs  ${UART}
    Execute Command               cpu.timer CounterFrequencyRegister 62500000

    Wait For Line On Uart         Welcome to oreboot
    Wait For Line On Uart         Not in EL3, jumping to payload

    Linux Should Print CPU Model ID

    Wait For Line On Uart         NR_IRQS: 64, nr_irqs: 64, preallocated irqs: 0
    Wait For Line On Uart         GICv3: 960 SPIs implemented
    Wait For Line On Uart         Root IRQ handler: gic_handle_irq

    Linux Should Run Init Process
    ...                           arch_timer_type=virt
    ...                           cpu_start_el=1
    ...                           uart_irq=13
    ...                           check_rtc=False

    Linux Should Start Rust Userspace

Test Running U-Boot With Linux
    [Tags]                        basic-tests
    # U-Boot doesn't properly support GIC Security Extensions.
    Create Machine                gic_version=2  gic_security_disabled=True

    # DeviceTree contains 32 virtio_blk/virtio_mmio devices at 0x0a000000, 0x0a000200, ..., 0x0a003e00 but
    # let's at least add one to check if it can be properly initialized. Initializing others won't succeed.
    Execute Command               machine LoadPlatformDescriptionFromString "virtio0: Storage.VirtIOBlockDevice @ sysbus 0x0a000000"

    Execute Command               sysbus LoadELF ${UBOOT_ELF}
    Execute Command               sysbus LoadBinary ${UBOOT_DTB} 0x40000000
    Execute Command               sysbus LoadBinary ${UBOOT_LINUX_IMAGE} 0x40400000

    # In U-Boot, this register is expected to be configured by a previous bootloader.
    Execute Command               cpu.timer CounterFrequencyRegister 62500000

    Wait For Line On Uart         U-Boot 2023.01
    Wait For Line On Uart         Hit any key to stop autoboot  includeUnfinishedLine=true
    Write Line To Uart
    Write Line To Uart            setenv bootargs \"console=ttyAMA0 earlycon\"; booti 0x40400000 - \${fdtcontroladdr}

    Wait For Line On Uart         Starting kernel ...

    Linux Should Print CPU Model ID
    Linux Should Print GICv2 Info
    Linux Should Run Init Process
    ...                           arch_timer_type=phys
    ...                           cpu_start_el=2
    ...                           uart_irq=48
    ...                           virtio_mmio_devices=True

    Wait For Services And Enter Shell   with_network=True
    Shell Should Handle Basic Commands

Should Boot And Login
    Create Multicore Machine

    Boot Linux And Login

    # Check if we see other CPUs
    Write Line To Uart              nproc
    Wait For Line On Uart           4
