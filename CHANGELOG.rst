Renode changelog
================

This document describes notable changes to the Renode framework.

1.13.0 - 2022.04.29
-------------------

Added platforms:

* Xtensa sample controller stub
* MIMXRT1064-EVK
* STM32L552
* ARVSOM
* BeagleV StarLight
* Sparc GR716
* RISC-V virt
* S32K118 with LPIT, LPTMR, GPIO, Clock generator mock
* STM32G0
* STM32F412
* STM32H743
* MIV_RV32

Added models:

* new models for i.MX RT 1064: PWM, timer, ADC, LPSPI, Flex SPI, TRNG
* new models for nRF52840: RNG, Radio, Watchdog, ECB, PPI infrastructure
* new models for STM32: ADC, slave CAN, PWR, watchdog
* new models for OpenTitan: flash controller, timer, PLIC, HMAC, AES, KMAC, ROM controller, Key manager, Reset manager
* new models for Polarfire SoC: system services, user crypto features (RNG and RSA), Mustein GPU and various fixes to platform description
* new model for Zynq 7000: XADC
* new generic models:

  * generic SPISensor
  * HostCamera device
  * TrivialUart
  * HPSHostController - fake I2C host master device for communicating with simulated devices
  * GigaDevice_GD25LQ - initial model
  * VirtIO block device model

Added demos:

* Murax SoC with verilated UART with simple echo demo
* LiteX with verilated CFU running CFU Playground demo
* Zynq with verilated FastVDMA running Linux
* NRF52840 BLE demo running Zephyr ``central_hr`` and ``peripheral_hr`` samples
* Leon3 running Zephyr shell
* GR716 running Zephyr shell
* Xtensa sample controller running Zephyr "Hello World" sample

Added core features:

* RISC-V: vector extension 1.0 support
* Xtensa architecture support
* RISC-V: access to proper set of registers + custom registers from GDB
* RISC-V: support for Custom Function Unit extensions
* WFE support on ARM cores
* uninterruptible debugging option to all architectures
* floating point support to Cortex-M platforms
* basic support for ARM 64-bit registers
* Cortex-M33 stub
* Sparc: added CSR register and exposed FSR register

Added features:

* primary selection copy support in TermSharp
* support for asciinema UART dumps
* support for native library communication in verilated peripherals
* APB3 bus implementation for VerilatorIntegrationLibrary
* support for loading HEX files
* video capture mechanism with host camera integration
* startup parameter for specifying the config file
* register access keywords for Robot Framework integration
* keyboard input in VideoAnalyzer on Windows
* option to stop on first error when running tests
* option to save failed test logs
* opcodes counting mechanism, along with RISC-V opcodes files parser
* execution tracing mechanism
* Wireshark support on Windows
* seL4-aware GDB debug support
* BLE wireless medium including Wireshark support
* gdb_compare script allowing to compare execution of two GDB instances, for example one connected to Renode and one to hardware
* support for vector registers in GDB
* CPU Id parameter in ARM cores
* option to control timestamp format and visibility in LoggingUartAnalyzer
* option to skip library fetch during build
* option to flush terminal history when connecting via socket
* support for external, bus-connected MMU

Changed:

* bumped Robot Framework version to ``4.0.1``
* RobotFramework: log entries keywords now accept regex patterns
* STM: renamed some UART ports to USART
* ZynqEthernet: removed and replaced with CadenceGEM
* Zedboard: updated demo to Linux 5.10
* reworked CPU halting
* added CRC to packets sent by NetworkServer
* RISC-V: added logs on unhandled CSR accesses
* improved build time by changes to TermSharp project organization
* various updates to STM32F746 CPU definition
* added limit to displayed command history in AntShell
* moved output of Robot tests to current directory when running on Windows
* XWT events are now queued in GTK engine
* added option to reconnect to SocketServerProvider
* explicitly used XZ compression with pacman
* added option to limit function names logging to unique entries, vastly improving performance
* removed dependency to realpath from build and run scripts
* removed dependency to ZeroMQ
* renamed EOSS3_SPIMaster to DesignWare_SPI
* dropped Fedora version indicator from packages
* optimized RISC-V PMP handling
* reworked PlatformLevelInterruptController to operate on contexts instead of targets
* added O/H/W write commands to ArduinoLoader
* enabled TLS 1.1 and TLS 1.2 in CachingFileFetcher
* improved multicore debugging support in GDB
* allowed to reuse testers in Robot tests
* added option to safely include the same C# file multiple times during one Renode run
* added ``tests.yaml``, containing all Robot tests, to all packages
* add debug mode for all architectures disabling interrupts when stepping over guest code
* simplified fixture selection when running tests
* allowed unaligned memory access by default in IbexRiscV32
* added GDB support for VS bits in MSTATUS register
* added interrupts support in verilated peripherals
* added support for CPU registers wider than 64-bits in Renode (C# part, not tlibs)
* improved and unified the --plain mode handling
* refactored the disassembly handling subsystem
* improved GDB packets handling performance
* added option to control serialization mode in the configuration file
* added optional compiled files cache
* improved handling of exceptions at the C/C# boundary
* flattened the TimeFramework structure to increase performance
* improved performance of handling of truncated translation blocks
* improved performance of TermSharp height map calculations and row handling
* added several tlib performance optimizations
* added the synchronized timers emulation mode
* added support for the flow control in UART
* added support for bright colors to TermSharp
* added basic VSCode launch configurations for Renode on Mono
* unified ``renode`` and ``renode-test`` scripts names across all packages
* added support for per-core peripheral registration
* added option to the build script to export the build directory
* improved performance of ELF reloading
* updated Conda build scripts to better work with the latest Renode, improved Windows support
* added option to configure step for clock entries
* improved startup performance by skipping analysis of uninteresting assemblies in TypeManager
* tied the AutoRepaintingVideo refresh frequency to the virtual time flow
* enabled passing the -e parameter to Renode even when providing a script file parameter
* added option to preserve temporary files from Robot tests
* added a source of a log message to the log tester
* Provides and Requires keywords now use state snapshots

Fixed:

* CPU endianness handling in GDB register accesses
* SPARC WRASR and CASA instructions
* SPARC registers handling in GDB
* memory invalidation on writes in MappedMemory
* ARM instructions: ASX, SAX, SUB16 and UQSUB
* symbol name mangling on MacOS
* updating PC before raising MMU exception on RISC-V
* unaligned ld_phys handling, resolves problems of possible memory corruption
* possible race conditions in TerminalTester
* IO access path selection in tlib
* support for big-endian peripherals
* running tests in sequential mode
* HiFive Unleashed platform description including PHY advertisement and RAM size
* Ethernet PHY advertisement on the Zedboard platform
* cross-endian bus accesses
* endian conversion wrappers for untranslated accesses
* registers mapping of fflags/frm/fcsr, resolving GDB registers XML generation
* running tests when the build phase failed
* it-status unit test
* added LibLLVM to all packages
* whitespace handling in resc scripts on Windows
* occasional assertion fail when loading ELF files
* setting breakpoints on virtual addresses
* MicroPython tests
* installation on Linux with a separate /opt mount point
* demangling symbols from the anonymous namespace
* SoftFloat's type conversion functions
* illegal instruction exception on wrong CSR access on RISC-V
* support for quad words access on the system bus
* possible memory leak in tlib
* improved precision of calculations in BasicClockSource and ComparingTimer Fixed
* support for various versions of standard libraries on Linux hosts (libdl, libutil, etc)
* libc dependencies for the Renode portable package
* invalidation of translation blocks on writes
* handling big offsets in MappedMemory
* ARM-M PRIMASK and xPSR handling
* PowerPC registers listing in GDB
* improved tlib debugging by not omitting the frame pointer on debug build
* fixed sfence.vma instruction implementation for RISC-V
* potential math errors (underflows/overflows) when handling the virtual time
* handling input redirected from file in the console mode
* prevented GdbStub from sending telnet config bytes on new connections
* serialization of paused state
* ad-hoc compiler support in the portable package
* flushing of log tester
* UartPtyTerminal serialization
* reporting the exit code in renode-test
* RISC-V custom CSRs handling
* resetting of a machine from the context of another machine
* thread-safety of interrupt handling mechanism
* occasional dependency fail on static constructors

Improvements in peripherals:

* CoreLevelInterruptor
* PlatformLevelInterruptController
* NVIC
* CortexAPrivateTimer
* BMA180
* CC1200
* Micron_MT25Q
* SynopsysEthernetMAC
* K6xF_Ethernet
* CadenceGEM
* OV2640
* GaislerMIC
* PL011
* EFR32_USART
* LowPower_UART
* OpenTitan_UART
* OpenTitan_GPIO
* IMXRT_ADC
* IMXRT_LPSPI
* LPUART
* STM32F7_I2C
* STM32_UART
* STM32 RTC
* STM32_TIMER
* STM32DMA
* STMCAN
* EXTI
* NRF52840_CLOCK
* NRF52840_Timer
* NRF52840 GPIO
* LiteX_I2S
* Litex_GPIO
* MPFS_PDMA
* MPFS_DDRMock
* Gaisler_GPTimer

1.12.0 - 2021.04.02
-------------------

Added:

* STM32F072 platform, with the STM32F072b Discovery board
* i.MX RT1064 platform
* NRF52840 platform, with Arduino Nano 33 BLE Sense board
* OpenTitan EarlGrey RISC-V platform with a range of OpenTitan peripherals
* CV32E40P-based RISC-V platform with many PULP peripherals
* LiteX with RISC-V Ibex CPU platform support
* CrossLink-NX evaluation board
* ice40up5k-mdp-evn board
* Zephyr-based test suite for QuickLogic QuickFeather with EOS S3
* Tock demo on LiteX/VexRiscv and STM32F4
* Mbed demo on STM32F7
* integration with Arduino IDE and Arduino CLI
* Python Standard Library, to be used with Python hooks and scripts in Renode
* support for images in the Monitor, along with possibility to take framebuffer screenshots. This also works with certain terminal emulators, like iTerm2, when in headless mode

  * option to connect UART to the running console, improving headless capabilities

    * option to run Renode Monitor directly in console, overlapped with logs, using the ``--console`` command line switch

* support for virtual addressing in GDB
* option to combine multiple interrupt or GPIO signals into one, using logical OR, directly in REPL files
* multi-bus support and AXI4 support (both as an initiator and a receiver) in co-simulation with Verilator
* ability to send synthetic network frames in Robot tests
* various sensor models: MC3635, LSM330, LSM303DLHC, LSM9DS1, LIS2DS12, BMP180
* seven-segment display model
* support for camera interfaces for nRF52840 and other platforms, along with a basic HM01B camera model
* support for sound data via PDM and I2S interfaces in nRF52840 and EOS S3
* 32-bit CSR versions of various LiteX peripherals
* ``window-height`` and ``window-width`` Renode config file options

Changed:

* ad hoc C# compilation now uses the same, bundled compiler on all OSes, also allowing for compilation in the portable Linux package
* bumped the officially supported Ubuntu version to 20.04
* added execution metrics analyzer to all Renode packages
* verilated peripherals can now also be used on Windows and on macOS
* verilated UART peripherals have updated protocol message numbers, requiring them to be recompiled to work with the latest Renode version
* moved to use openlibm instead of libm on Linux, improving portability
* GDB can now access memory across pages in a single access
* switched the unit testing framework from NUnit2 to NUnit3
* reduced the number of transitions between the C and C# code, improving performance
* improved performance of peripheral writes
* tests print the run summary at the end of the output, making it easier to spot errors
* revamped handling of the vectored interrupt mode for RISC-V cores
* RISC-V CPUs can now optionally allow for unaligned memory accesses
* updated the default privileged architecture version for VexRiscv CPU
* VexRiscv can now use standard RISC-V interrupt model
* changed the flow of NVIC interrupt handling, significantly improving performance
* STM32F7 DMA2D and LTDC now support more pixel blending modes
* reimplemented and modernized several STM32 peripherals
* improved the model of K6xF Ethernet controller
* LiteSDCard model now supports DMA interface
* EXTI controller now has a configurable number of output lines
* improved handling of dummy bytes in MPFS QSPI

Fixed:

* tests running from installed Renode packages creating output files in forbidden locations
* serialization of NetworkInterfaceTester and UARTBackend
* possible non-deterministic behavior of UART backend in tests
* occasional file sharing violation in PosixFileLocker
* Renode printing out colors when in plain mode
* non-determinism in the button model
* time drift caused by unreported virtual ticks and improper instruction counting
* crash in TermsharpProvider when running on Windows
* invalid default frequency for STM32L1

1.11.0 - 2020.10.22
-------------------

Added:

* support for generating execution metrics, covering information like executed instructions count, memory and peripheral accesses, and interrupt handling
* infrastructure for reporting supported CPU features to GDB
* tests for Icicle Kit with PolarFire SoC
* ``--debug-on-error`` option for ``renode-test`` allowing interactive debugging of failed Robot tests
* ``lastLog`` Monitor command displaying ``n`` last log messages
* ``currentTime`` monitor command with information about elapsed host and virtual time
* ``WriteLine`` UART helper method to feed strings from the Monitor or scripts
* support for non-base RISC-V instruction sets disassembly
* support for custom Robot test results listeners
* support for Python-based implementation of (stateful) custom CSRs and custom instructions in RISC-V
* option to control RISC-V CSR access validation level interactively
* dummy support for data cache flush instruction in VexRiscv
* 64-bit decrementer support in PowerPC
* nRF52840 RTC model
* STM32F4 RTC model
* STM32F4 RCC stub model
* unified timer model for STM32F4 and STM32L1 platforms
* support for ATAPI CD-ROM
* burst read support in OpenCores I2C

Changed:

* time flow settings in Icicle Kit script now ensure full determinism
* all testers (for UART, LED, network, sysbus accesses and log messages) now rely on virtual time instead of host time and accept floating point timeouts
* portable package now includes requirements.txt file
* skipped tests do not generate save files anymore
* ``Clear`` Monitor command does not remove current working directory from searched paths
* WFI handling in RISC-V is simplified, improving performance on sleepy systems
* translation block fetch logger messages are now logged with Info instead of Debug level
* Cortex-M CPUs now reports their registers to GDB
* several infrastructural changes in the PCI subsystem
* STM32L1 oscillators are now all reported as ready

Fixed:

* Renode logo appearing in UART analyzer windows when running without Monitor
* logs not being fully written out when terminating Renode
* keyboard event detection in framebuffer window when no pointer device is attached
* crash when the logger console reports width equal to 0
* crash of ad-hoc compilation on Renode portable. Note that this still requires a C# compiler to be available on the host system
* crash when connecting GDB with the first core not being connected
* occasional crash when providing incorrect CLI arguments
* invalid disassembly of 64-bit RISC-V instructions
* crash on machine reset when using custom CSRs in RISC-V
* handling of multi-byte reads in LiteX I2C model
* handling of images with unaligned size in USB pen drive
* invalid LED connections in STM32F4

1.10.1 - 2020.07.30
-------------------

This is a hotfix release overriding 1.10.0.

Fixed:

* crash on Windows when accessing high memory addresses
* installation instructions in README

1.10.0 - 2020.07.28
-------------------

Added:

* support for the PolarFire SoC-based Icicle Kit platform, with a demo running Linux
* experimental support for OpenPOWER ISA
* support for NXP K64F with UART, Ethernet and RNG
* basic support for Nordic nRF52840
* Microwatt platform, with Potato UART, running MicroPython or Zephyr
* LiteX platform with a 4-core VexRiscv in SMP
* LiteX demo running Microwatt as a CPU
* LiteX demo with VexRiscv booting Linux from the SD card
* LiteX demo with VexRiscv showing how to handle input and output via I2S
* LiteX MMCM model, I2S model and SD card controller model
* several peripheral models for QuickLogic EOS S3: ADC, SPI DMA, Packet FIFO, FFE etc
* ADXL345 accelerometer model
* PAC1934 power monitor model
* PCM encoder/decoder infrastructure for providing audio data to I2S devices
* modular network server allowing to easily add server components to the emulation without a host-to-guest connection
* built-in TFTP server module
* file backend for UARTs, allowing to send output directly to a file (``uart CreateFileBackend``)
* ``alias`` Monitor command
* ``console_log`` Monitor command to simply print to the log window without level filtering
* ``--no-gui`` build option to build without graphical dependencies
* option to define an average cycles count per instruction, to be used by CPU counters
* code formatting rules for translation libraries, to be used with Uncrustify

Changed:

* Renode is now able to be compiled with ``mcs``. This means that you can use your distribution's Mono package instead of the one provided by mono-project.com, as long as it satisfies the minimum version requirement (currently Mono 5.2)
* the default log level is now set to ``INFO`` instead of ``DEBUG``
* all PolarFire SoC peripherals are now renamed from PSE_* to MPFS_*, to follow Microchip's naming pattern
* major rework of the SD card model, along with the added SPI interface
* RI5CY core can now be created with or without FPU support
* STM32 and SAM E70 platforms now have verified ``priorityMask`` in NVIC
* Cortex-M based platforms can now be reset by writing to NVIC
* easy way to update timer values between synchronization phases, significantly improving the performance of polling on timers
* tests are now able to run in parallel, using the ``-j`` switch in the testing script execution
* the pattern for download links in scripts for binaries hosted by Antmicro has been changed
* portable package now includes testing infrastructure and sample tests
* the LLVM-based disassembly library is now rebuilt, using less space and being able to support more architectures on all host OSes
* the C++ symbol demangling now relies on a `CxxDemangler <https://github.com/southpolenator/CxxDemangler>`_ library, instead of libstdc++
* failed Robot tests will now produce snapshots allowing users to debug more easily
* SVD-based log messages on reads and writes are now more verbose
* Terminal Tester API has changed slightly, allowing for easier prompt detection, timeout control etc.

Fixed:

* crash when running tests with empty ``tests.yaml`` file
* crash when Renode is unable to find the root directory
* crash when loading broken or incompatible state snapshot with ``Load``
* several issues in the PPC architecture
* ``mstatus`` CSR behaviour when accessing FP registers in RISC-V
* PMP napot decoding in RISC-V
* evaluation of the IT-state related status codes in ARM CPUs
* invalid setting of CPUID fields in x86 guests
* PolarFire SoC platform description and various models: CAN, SPI, SD controller, etc.
* ``ODR`` register behavior in STM32F1 GPIO port
* ``State changed`` event handling in LED model
* invalid disposal of the SD card model, possibly leading to filesystem sharing violations
* some cursor manipulation commands in TermSharp
* performance issues when hitting breakpoints with GDB
* on the fly compilation of "*.cs" files in the portable Renode package
* Mono Framework version detection
* upgrading Renode version on Windows when installed using the ``msi`` package
* error message when quitting Renode on Windows
* running tests from binary packages
* support for testing in Conda Renode package
* other various fixes in Conda package building

1.9.0 - 2020.03.10
------------------

Breaking changes:

* the Renode configuration directory was moved to another location.

  The directory is moved from ``~/.renode`` on Unix-like systems and ``Documents`` on Windows to
  ``~/.config/renode`` and ``AppData\Roaming\renode`` respectively. To use your previous settings
  and Monitor history, please start Renode 1.9 and copy your old config folder over the new one.

Added:

* support for RISC-V Privileged Architecture 1.11
* EOS S3 platform, with QuickFeather and Qomu boards support
* EFR32MG13 platform support
* Zolertia Firefly dual radio (CC2538/CC1200) platform support
* Kendryte K210 platform support
* NeTV2 with LiteX and VexRiscv platform support
* EFR32 timer and gpcrc models
* CC2538 GPIO controller and SSI models
* CC1200 radio model
* MAX3421E USB controller model
* LiteX SoC controller model
* support for Wishbone bus in verilated peripherals, exemplified with the ``riscv_verilated_liteuart.resc`` sample
* one-shot mode in AutoRepaintingVideo allowing display models to control when they are refreshed
* ``GetItState`` for ARM Cortex-M cores allowing to verify the current status of the IT block
* scripts to create Conda packages for Linux, Windows and macOS
* requirements.txt with Python dependencies to simplify the compilation process
* configuration option to collapse repeated lines in the log - turn it to false if you observe strange behavior of the log output

Changed:

* VexRiscv now supports Supervisor level interrupts, following latest changes to this core
* PolarFire SoC script now has a sample binary, running FreeRTOS with LwIP stack
* the output of Robot test is now upgraded to clearly indicate time of execution
* NetworkInterfaceKeywords now support wireless communication
* exposed several RISC-V registers to the Monitor
* VerilatedUART now supports interrupts
* tests file format was changed to yaml, thus changing tests.txt to tests.yaml
* test.sh can now run NUnit tests in parallel
* ``./build.sh -p`` will no longer build the portable Linux package as it requires a very specific Mono version
* path to ``ar`` can now be specified in the properties file before building
* MinGW libraries are now compiled in statically, significantly reducing the Windows package size

Fixed:

* crash when trying to set the underlying model for verilated peripheral in REPL
* crash when copying data from the terminal to clipboard on Windows
* crash on loading missing FDT file
* crash when starting the GDB server before loading the platform
* handling of very long commands via GDB
* improper window positioning when running on Windows with a display scaling enabled
* exception reporting from running CPUs
* flushing of closing LoggingUartAnalyzer
* icon installation on Fedora
* rebuilding translation libraries when only a header is changed
* macOS run scripts bundled in packages
* priority level handling in NVIC
* COUNTFLAG handling in NVIC
* several improvements in Cadence GEM frame handling
* FastRead operations in Micron MT25Q flash
* PolarFire SoC Watchdog forbidden range handling
* offset calculation on byte accesses in NS16550 model
* interrupt handling in PolarFire SoC QSPI model
* connected pins state readout in PolarFire SoC GPIO model
* several fixes in HiFive SPI model
* page latch alignment in PolarFire SoC

1.8.2 - 2019.11.12
------------------

Added:

* a sample running HiFive Unleashed with Fomu running Foboot, connected via USB
* a sample running MicroPython on LiteX with VexRiscv
* vectored interrupts support in RISC-V
* ``pythonEngine`` variable is now availalbe in Python scripting

Changed:

* Renode now requires Mono 5.20 on Linux and macOS
* USB setup packets are now handled asynchronously, allowing more advanced processing on the USB device side
* additional flash sizes for Micron MT25Q
* LiteX_Ethernet has a constant size now

Fixed:

* problem with halting cores in GDB support layer when hitting a breakpoint - GDB works in a proper all-stop mode now

1.8.1 - 2019.10.09
------------------

Added:

* LiteX with VexRiscv configuration running Zephyr
* USB/IP Server for attaching Renode peripherals as a USB device to host
* optional NMI support in RISC-V
* flash controller for EFR32
* I2C controller for LiteX
* SPI controller for PicoRV
* framebuffer controller for LiteX
* USB keyboard model

Changed:

* ``-e`` parameter for commands executed at startup can be provided multiple times
* ``polarfire`` platform is now renamed to ``polarfire-soc``
* style of Robot Framework result files
* MT25Q flash backend has changed from file to memory, allowing software to execute directly from it
* improved LiteX on Fomu platform
* terminals based on sockets now accept reconnections from clients

Fixed:

* ``Bad IL`` exceptions when running on Mono 6.4

1.8.0 - 2019.09.02
------------------

Added:

* support for RI5CY core and the VEGA board
* UART and timer models for RI5CY
* support for Minerva, a 32-bit RISC-V soft CPU
* LiteX with Minerva platform
* LiteX with VexRiscv on Arty platform
* SPI, Control and Status, SPI Flash and GPIO port peripheral models for LiteX
* PSE_PDMA peripheral model for the PolarFire SoC platform
* basic slave mode support in PSE_I2C
* EtherBone bridge model to connect Renode with FPGA via EtherBone
* EtherBone bridge demo on Fomu
* RTCC and GPCRC peripheral models for EFR32
* support for deep sleep on Cortex-M cores
* option of bundling Renode as an ELF executable on Linux

Changed:

* GDB server is now started from the ``machine`` level instead of ``cpu`` and is able to handle multiple cores at once
* renamed ``SetLossRangeWirelessFunction`` to ``SetRangeLossWirelessFunction``
* LiteX Ethernet now supports the MDIO interface
* updated memory map for several EFR32 platforms
* changed the interrupt handling of EFR32_USART
* several changes in Ethernet PHY
* switch is now started immediately after creation
* the Monitor (and other mechanisms) now uses caching, increasing its performance
* Robot tests are now part of packages
* Robot tests no longer cause the Monitor telnet server to start automatically
* REPL files now accept multiline strings delimited with triple apostrophe
* UART analyzers are writing to the Renode log when running from Robot
* simplified command line switches for running Robot tests
* some Robot keywords (e.g. ``LogToFile``) are not saved between related tests

Fixed:

* compilation of verilated peripheral classes in Windows (backported to 1.7.1 package)
* determinism of SAM E70 tests
* crash when using ``logLevel`` command with ``--hide-log`` switch
* ad-hoc compiler behavior in Windows
* crash on too short Ethernet packets
* byte read behavior in NS16550
* auto update behavior of PSE_Timer
* connection mode when running the Monitor via telnet
* deserialization of ``SerializableStreamView``
* crash when completing interrupts in PLIC when no interrupt is pending
* Renode startup position on Windows with desktop scaling enabled
* fence.* operation decoding in RISC-V
* invalid size reported by SD card
* crash when trying to set the same log file twice
* compilation issues on GCC 9


1.7.1 - 2019.05.15
------------------

Added:

* integration layer for Verilator
* base infrastructure for verilated peripherals
* base class for verilated UARTs, with analyzer support
* Linux on LiteX with VexRiscv demo

Changed:

* RISC-V CPUs now don't need CLINT in their constructor, but will accept any abstract time provider
* updated LiteX with PicoRV32 and LiteX with VexRiscv platform

Fixed:

* sharing violation when trying to run downloaded files

1.7.0 - 2019.05.02
------------------

Added:

* PicoRV32 CPU
* LiteX platform with PicoRV32
* LiteX timer and ethernet (LiteEth) model
* Murax SoC with UART, timer and GPIO controller models
* Fomu target support with LiteX and VexRiscv
* SAM E70 Xplained platform with USART, TRNG and ethernet controller models
* STM32F4 Random Number Generator model
* PSE watchdog model
* PTP support in Cadence GEM ethernet model, along with several fixes
* option to execute CPUs in serial instead of parallel
* support for custom instructions in RISC-V
* ``empty`` keyword in REPL
* graphical display analyzer support on Windows
* multi-target GPIO support, along with the new REPL syntax
* local interrupts in PolarFire SoC platform
* option to pass variables to Robot tests via test.sh
* some SiFive FU540 tests
* network interface tester for Robot tests
* tests for PTP implementation in Zephyr

Changed:

* Micron MT25Q is now able to use file as a backend and does not need to have a separate memory provided in REPL
* Micron MT25Q now has selectable endianess
* ``logFile`` command will now create a copy of the previous log before overwriting it
* ``sysbus LogPeripheralAccess`` will now add the active CPU name and current PC to log messages
* single-stepping of a CPU is now easier, it requires only a single call to ``cpu Step`` on a paused CPU
* NVIC reload value is now 24-bit
* reimplemented the STM32_UART model
* updated the PolarFire SoC memory map
* updated the SiFive FU540 memory map
* ``GetClockSourceInfo`` will now display the name of the timer
* Termsharp will no longer print the NULL character
* RISC-V cores will now abort when trying to run a disabled F/D instruction

Fixed:

* handling of divider in ComparingTimer
* reporting of download progress on some Mono versions
* running Robot tests on Windows
* generation of TAP helper on newest Mono releases
* Renode crashing after opening a socket on the same port twice
* serialization of data storage structures
* architecture name reported on GDB connection for Cortex-M CPUs
* highlighting of wrapped lines in the terminal on Windows
* TAB completion in the Monitor on Windows
* RNG determinism and serialization for multicore/multi-node systems
* SiFive FE310 interrupt connection
* instruction counting in RISC-V on MMU faults
* time progress in multicore systems
* fixes in MiV GPIO controller model
* several fixes and improvements in file backend storage layer
* several fixes in testing scripts
* several fixes in various LiteX peripherals
* several fixes in PSE QSPI and Micron MT25Q model

1.6.2 - 2019.01.10
------------------

Added:

* instructions on running in Docker
* --pid-file option to save Renode's process ID to a file

Changed:

* RISC-V X0 register is now protected from being written from the Monitor
* Renode will now close when it receives a signal from the environment (e.g. Ctrl+C from the console window)
* invalid instructions in RISC-V will no longer lead to CPU abort - an exception will be issued instead, to be handled by the guest software
* Robot tests will now log more

Fixed:

* formatting of symbol logging
* error reporting in Robot tests using the ``Requires`` keyword
* Microsemi's Mi-V CPU description

1.6.1 - 2019.01.02
------------------

Added:

* CC2538 Flash Controller
* ECB mode for CC2538 Cryptoprocessor

Changed:

* unhandled read/write logs are now decorated with the CPU name instead of the number
* message acknowledge logic on PolarFire CAN controller

Fixed:

* race condition in PromptTerminal used by the Robot Framework
* Monitor socket not opening in certain situations
* unaligned accesses in RISC-V not setting the proper badaddr value
* handling of data exceeding the maximum packet size of USB endpoint
* memory map and CPU definition for SiFive FE310
* out of bounds access when using Ctrl+R with wrapped lines in the Monitor

1.6.0 - 2018.11.21
------------------

Added:

* new USB infrastructure
* new PCI infrastructure
* PolarFire SoC platform support
* atomic instructions on RISC-V
* basic PicoSoC support - the picorv32 CPU and UART
* block-finished event infrastructure - verified on RISC-V and ARM cores
* more PSE peripherals: RTC, PCIe controller, USB controller, QSPI, CAN, etc
* Micron MT25Q flash model
* ``watch`` command to run Monitor commands periodically
* a message on the Monitor when quitting Renode
* qXfer support for GDB, allowing the client to autodetect the architecture
* log tester for Robot Framework

Changed:

* added error handling for uninitialized IRQ objects in REPL loading
* RISC-V CSR registers are now accessible in relevant privilege architecture version only
* RISC-V CPUs no longer require CLINT provided as a constructor parameter
* added second timer interrupt to PSE_Timer
* machine.GetClockSourceInfo now prints the current value for each clock entry
* REPL loading tests are now in Robot
* value provider callbacks on write-only fields will generate exceptions
* watchpoint handling infrastructure
* reworked single stepping
* Monitor errors are forwarded to the GDB client when issuing qRcmd
* LoadELF command initializes PC on all cores by default
* reduced the default synchronization quantum
* CPU abort now halts the emulation
* --disable-xwt no longer requires opening a port
* RISC-V atomic instructions now fail if the A instruction set is not enabled

Fixed:

* pausing and halting the CPU from hooks
* error when trying to TAB-complete nonexisting paths
* packaging script on Windows
* crash on extremely narrow Terminal on Windows
* inconsistent cursor position when erasing in Termsharp
* selection of multibyte UTF characters on Linux
* scrollbar behavior on Windows
* error reporting from executed commands in Robot
* RISC-V cores reset
* several fixes in time framework
* output pin handling and interrupt clearing in PSE_GPIO
* minor fixes in PSE_SPI
* throwing invalid instruction exception on wrong CSR access in RISC-V
* CPU abort will now stop the failing CPU


1.5.0 - 2018.10.03
------------------

Added:

* custom CSR registers in RISC-V
* VexRiscv CPU
* basic LiteX platform with VexRiscv
* LiteX VexRiscv demo with Zephyr
* single and multinode CC2538 demos with Contiki-NG
* PSE peripherals
* several tests for demos and internal mechanisms
* base classes for bus peripherals, allowing for easier definition of registers

Changed:

* installation instructions in README
* the target .NET version changed to 4.5 reducing the number of dependencies
* forced mono64 on macOS
* renamed the multinode demos directory
* RISC-V CPUs now generate an exception on unaligned memory reads and writes
* CLINT is now optional for RISC-V CPUs
* reimplemented FileStreamLimitWrapper

Fixed:

* first line blinking in terminal on Windows
* performance fixes in function logging
* handling of broken CSI codes in Termsharp
* completely removed the GTK dependency on Windows
* handling of CheckIfUartIsIdle Robot keyword
* resetting of RISC-V-based platforms
* prevented a rare crash on disposing multicore platforms when using hooks
* handling of unsupported characters in Robot protocol
* Windows installer correctly finds the previous Renode installation (may require manual deinstallation of the previous version)
* compilation of translation libraries on Windows is no longer forced on every Renode recompilation


1.4.2 - 2018.07.27
------------------

Added:

* debug mode in RISC-V, masking interrupts and ignoring WFI when connected via GDB
* installer file for Windows
* GPIO controller for STM32F103, with other improvements to the platform file
* PWM, I2C and SPI peripherals for HiFive Unleashed
* tests for HiFive Unleashed
* configuration option to always add machine name in logs
* test scripts when installing Renode from a package on Linux

Changed:

* changed gksu dependency to pkexec, as Ubuntu does not provide gksu anymore
* virtual time of machines created after some time is synchronized with other machines
* improved Vector Table Offset guessing when loading ELF files on ARM Cortex-M CPUs
* extended capabilities of some Robot keywords
* changed the way peripheral names are resolved in logs, so that they don't disappear when removing the emulation

Fixed:

* support for writing 64-bit registers from GDB
* crash when trying to connect to a nonexisting interrupt
* GDB access to Cortex-M registers
* some fixes in EFR32_USART


1.4.1 - 2018.06.28
------------------

Added:

* AXI UART Lite model

Changed:

* event dispatching on WPF on Windows

Fixed:

* an error in handling of generated code on Windows, causing the emulated application to misbehave
* font loading and default font size on Windows

1.4.0 - 2018.06.22
------------------

Added:

* support for RISC-V Privileged Architecture 1.10
* 64-bit RISC-V target emulation
* support for HiFive Unleashed platform
* support for SiFive Freedom E310 platform
* new way of handling time progression and synchronization in the whole framework
* support for 64-bit registers
* basic support for a range of SiLabs EFM32, EFR32 and EZR32 MCUs
* several new Robot keywords
* Wireshark support for macOS

Changed:

* Windows runs a 64-bit version of Renode
* 32-bit host OSes are no longer supported
* Robot tests can now be marked as OS-specific or ignored
* improvements in CC2538 radio model
* enum values in REPL files can now be provided as integers
* updated interrupt model in RISC-V
* MaximumBlockSize is no longer forced to 1 when starting GDB server

Fixed:

* several fixes in REPL grammar
* fixes in Robot test handling
* fixes in GDB watchpoints and breakpoints
* few other fixes in GDB integration layer
* floating point operations in RISC-V
* atomic operations in RISC-V
* high CPU usage when loading many nodes at the same time
* deserialization of the UART windows
* symbol names caching when loading new symbol files
* several minor fixes in different platform files

1.3.0 - 2018.01.26
------------------

Added:

* EmulationEnvironment - a mechanism to handle sensor data in a centralized way
* test for loading REPL files
* several registers and commands in CC2538RF
* SCSS device for QuarkC1000 platform
* sample scripts with two nodes running a Zephyr demo

Changed:

* ComparingTimer and LimitTimer are now more similar in terms of API
* macOS runs a 64-bit version of Renode
* changed Arduino 101 with CC2520 board to Quark C1000 devkit
* improvements in RISC-V interrupt handling
* current working directory is now always a part of Monitor's default path

Fixed:

* crash when closing Renode with Wireshark enabled but not yet started
* handling of timer events for a specific timer configuration
* implementation of LED tester
* starting Robot on Windows without administrative privileges
* terminal state after running Robot tests
* improper timer initialization in RISC-V's CoreLevelInterruptor
* text highlighting in wrapped lines in terminal windows

1.2.0 - 2017.11.15
------------------

Added:

* support for RISC-V architecture
* support for Microsemi Mi-V platform
* thin OpenOCD layer in GDB remote protocol support

Changed:

* timers can now hold values up to 64 bits
* ``Button`` peripheral can now have inverted logic
* GDB server can be configured to autostart after the first "monitor halt" received

Fixed:

* translation cache invalidation on manual writes to memory
* reset of ``LimitTimer`` peripheral, which is the base for most of the supported timers

1.1.0 - 2017.11.14
------------------

Added:

* sample scripts for different platforms
* support for running Renode on Windows
* EFR32MG cpu support. For the list of peripherals, see efr32mg.repl
* more robust support for SVD files
* support for '\n -> \r\n' patching in Termsharp console windows
* support for font configuration in Termsharp
* support for CRC in Ethernet
* packaging scripts

Changed:

* API for UART-related keywords in Robot Framework integration layer
* the project infrastructure now supports C# 7.0
* directory organization

Fixed:

* several minor fixes in platform description format (.repl)
* bug where Renode hanged after issuing the "help" command in the Monitor

1.0.0 - 2017.06.13
------------------

This is the initial release of Renode.
Renode is a virtual development and testing tool for multinode embedded networks.
For more information please visit `<https://www.renode.io>`_.

