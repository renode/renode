Renode changelog
================

This document describes notable changes to the Renode framework.

1.15.3 - 2024.09.17
-------------------

Added and improved architecture support:

* fixed Arm MPU skipping access checks for MPU regions sharing a page with a background region
* FPU dirty flag is now set on all FPU load instructions for RISC-V
* fixed Arm PMSAv8 not checking for domains not being page aligned
* RISC-V MTVAL register now contains the invalid instruction after illegal instruction exception
* Arm SRS (Store Return State) instruction now saves onto stack SPSR instead of masked CPSR
* improved support for x86-64, verified with Zephyr
* added SMEPMP extension stub for RISC-V
* added ability to configure usable bits in RISC-V PMPADDR registers
* fixed runtime configurability of the RISC-V MISA registers
* fixed RISC-V PMPCFG semantics from WIRI to WARL
* fixed decoding of C.ADDI4SPN in RISC-V
* fixed behavior of RORIW, RORI and SLLI.UW RISC-V instructions
* changed MSTATUS RISC-V CSR to be more responsive to the presence of User and Supervisor modes

Added and improved platform descriptions:

* NXP MR-CANHUBK3
* NXP S32K388
* NXP S32K118
* RI5CY
* Renesas r7fa8m1a
* Renesas DA14592
* STM32H743
* x86-64 ACRN

Added demos and tests:

* Zephyr running hello_world demo on x86-64 ACRN
* ZynqMP demo showcasing two way communication between Cortex-A53 running Linux and Cortex-R5 running OpenAMP echo sample

Added features:

* Socket Manager mechanism, organizing socket management in a single entity
* test real-time timeout handling mechanism in Robot
* GPIO events support for the External Control API
* Zephyr Mode support for Arm, Arm-M, SPARC, x86 and Xtensa
* disassembling support for x86-64 architecture
* support for bus access widths other than DoubleWord for DPI integration of APB3
* support for overriding a default implementation of the verilated UART model

Changed:

* improved `renesas-segger-rtt.py` helper
* Renode logs a warning instead of crashing when HDL co-simulated block reports an error
* improved `guest cache` tool results readability

Fixed:

* PulseGenerator behavior when `onTicks == offTicks`
* External Control API GetTime command returning incorrect results
* SystemC integration crashing when initializing GPIO connections
* USB Speed value reported in USB/IP device descriptor
* USB endpoints with the same number but opposite direction not being distinguished
* a potential crash due to ``OverflowException`` when stopping the emulation
* checking address range when mapping memory ranges in TranslationCPU
* configuration descriptor parsing in USBIPServer
* fatal TCG errors in some cases of invalid RISC-V instructions
* handling registration of regions not defined by peripherals
* handling registration of regions with unpaired access method
* incorrect sequence number in USBIP setup packet reply
* SD card reset condition
* starting GDB stub on platforms containing CPUs not supporting GDB
* infinite loop on debug exception with an interrupt pending
* simulation elements unpausing after some Monitor commands

Added peripheral models:

* Arm CoreLink Network Interconnect
* LPC Clock0
* RenesasDA14 GeneralPurposeRegisters
* STM32 SDMMC
* Synopsys SSI

Improvements in peripherals:

* Arm Signals Unit
* CAES ADC
* Gaisler FaultTolerantMemoryController
* LPC USART
* MiV CoreUART
* NXP LPUART
* RenesasDA Watchdog
* RenesasDA14 ClockGenerationController
* RISC-V Platform Level Interrupt Controller
* STM32 DMA
* ZynqMP IPI
* ZynqMP Platform Management Unit

1.15.2 - 2024.08.18
-------------------

Added and improved architecture support:

* support for Core-Local Interrupt Controller (CLIC) in RISC-V, enabling several flavors of the (not yet ratified) RISC-V Fast Interrupts specification
* various improvements to x86 architecture support, including virtual address translation fixes
* RISC-V custom instructions now have to follow length encoding patterns, as specified in the ISA manual (section 1.2 Instruction Length Encoding)
* fixed fetching RISC-V instruction with PMP boundary set exactly after the instruction
* fixed setting MPP after mret on RISC-V platforms without user privilege level
* fixed RISC-V PMPCFG CSR operations not respecting the ``write any, read legal`` semantics
* fixed RISC-V fcvt.wu.s, fcvt.lu.s and vmulh.vv instructions implementation

Added and improved platform descriptions:

* NPCX9 platform with improved bootrom implementation
* Chip revision tags in the Renesas DA14592 platform
* Fixed MPU regions configuration in Cortex-R8 SMP platform description
* Nuvoton NPCX9M6F EVB
* Microchip Mi-V, with correct Privileged Architecture version

Added peripheral models:

* MAX32655 UART
* NEORV32 Machine System Timer
* NEORV32 UART
* KB1200 UART
* RISC-V Core-Local Interrupt Controller
* STM32WBA CRC
* VeeR EL2 RISC-V core with custom CSRs

Added demos and tests:

* HiRTOS sample running on a dual-core Cortex-R52
* Xen hypervisor running on Cortex-R52 with Zephyr payload
* remoteproc demo on ZynqMP, with Linux running on Cortex-A loading Zephyr to Cortex-R
* NPCX9 Zephyr-based tests for GPIO and I2C
* synthetic tests for RISC-V Core-Local Interrupt Controller
* RISC-V Core-Local Interrupt Controller tests based on riscv-arch-test
* Zephyr bluetooth HR demo running on 4 nRF52840 in host / controller split communicating with HCI UART
* Zephyr running hello_world sample on X86
* regression test for custom RISC-V instructions not following the length encoding pattern

Added features:

* CPU cache analysis tool using the ExecutionTracer interface
* initial GPIO support via External Control API
* Wait For Lines On Uart keyword for Robot Framework for multiline matching
* ability to specify aliases for names of constructor parameters in REPL, simplifying adaptation to API changes
* ability to specify implemented privilege levels on RISC-V processors
* initial SMC handling for ARMv8 CPUs
* ability to load snapshots (.save files) from CLI
* mechanism for enabling sysbus transaction translations for unimplemented widths in runtime
* network based logging backend
* option to assert match on the next line in UART keywords for Robot Framework
* remapping exception vector in Arm CPUs having neither VBAR nor VTOR
* support for declaring clusters of cores in REPL files
* support for loading gzip compressed emulation snapshots
* NetMQ and AsyncIO integration

Changed:

* ExecutionTracer logs additional physical address on memory access when MMU translation is involved
* ExecutionTracer tracks values written to/read from memory if TrackMemoryAccesses parameter is used
* added the ability to override build properties
* added the ability to track memory accesses when address translation is active
* External Control client \`run_for\` example can now progress time multiple times without reconnecting
* machine by default disallows spawning a GdbServer with CPUs belonging to different architectures.
* made user-configured $CC the default value for Compiler and LinkerPath and $AR for ArPath
* paths encapsulated in quotes can handle names with whitespaces
* paths in Monitor can be encapsulated in quotes in more contexts
* improved precision of timer reconfiguration
* translation library will attempt to expand its code buffer when running out of space
* improved flexibility of parameter passing to registration points in REPL, as used by GIC
* improved flexibility of the logLevel command
* improved Renode pausing responsiveness when using TAP interface on Linux
* improved performance of External Control API renode_run_for function
* simplified per-core registration API in REPL files
* renamed \`\`PrivilegeArchitecture\`\` to \`\`PrivilegedArchitecture\`\` on RISC-V
* unified STM32 CRC peripherals so they use a single class configured with the STM32Series enum
* co-simulated peripherals protocol on writes directed to system bus
* MacOS now uses \`\`mono\`\` instead of \`\`mono64\`\` as a runner, which is equivalent since Mono 5.2
* time updates are now deferred when possible to improve performance
* virtual time precision is now 1 nanosecond instead of 1 microsecond
* limited unnecessary invalidations of memory for multicore platforms
* CPU-specific peripheral registrations have now higher priority than the global ones
* undefined AArch64 ID registers are now treated as RAZ

Fixed:

* initialization of VFP registers for Armv8 CPUs
* support for building tlibs with clang
* interruption of instructions block on precise pause
* accessing RISC-V counter CSRs for lower privilege levels for privileged specification 1.10 and newer
* Time Framework errors when handling halted CPUs
* running renode and renode-test commands via symlinks
* serialization of ARMv8-A CPUs
* serialization of some complex classes
* listing of registration points for peripherals registered at both cpu and sysbus
* handling of watchpoints set at addresses above the 32-bit range
* crashes when using both aliased attribute name and normal name at the same time
* possible hang when disabling logging of peripheral accesses
* handling of exclusive store/load instructions for ARMv7-R CPUs
* handling of interrupting execution in GDB on multicore platforms in all-stop mode
* allocating huge amount of memory for translation cache on CPU deserialization
* invalid undefined instruction faults for Armv8 CPUs
* GDB getting confused when receiving Ctrl-C on multicore platforms
* LSM303 peripheral test
* CS7034 \"specified version string does not conform to recommended format\" warning appearing when building
* Vegaboard-RI5CY demo failing to boot
* exception thrown on an empty message in log when failing a Robot test
* linking and imports in the External Control library
* nonstandard configuration byte when disabling Telnet line mode
* printing skipped test status
* version information not appearing correctly after running \`renode --help\`

Improvements in peripherals:

* Ambiq Apollo4 System Timer
* Arm Generic Interrupt Controller
* ARM Generic Timer
* Arm Performance Monitoring Unit
* Arm Snoop Control Unit
* Arm CPUs
* Arm Signal Unit
* Gaisler APB UART
* K6xF Multipurpose Clock Generator
* KB1200 UART
* LPC USART
* Macronix MX25R
* MAX32650 WDT
* Mi-V Core Timer
* MPFS SD controller
* NEORV32 UART
* NPCX MDMA
* NPCX ITIM, including both 32 and 64-bit flavors of the peripheral
* NPCX TWD
* NPCX SMBus
* NPCX UART
* nRF52840 CLOCK
* NVIC
* Renesas RA6M5 SCI
* RCAR UART
* SAMD20 UART
* SD card
* STM32 UART
* STM32 LTDC
* STM32 CRC
* STM32 Timer
* STM32F4 Flash with added mass erase and sector erase commands
* STM32L0 RCC model with added support for Low-power timer (LPTIM) reset
* STM32WBA GPDMA
* SynopsysDWCEthernetQualityOfService incorrectly resetting transmit/receive buffer position when suspending its DMA engine
* VirtIO
* Zynq7000 System Level Control Registers

1.15.1 - 2024.06.14
-------------------

Added and improved architecture support:

* improved support for SMP processing in Armv8 and Armv7
* configuration signals for Arm cores
* LOB extension (without tp variants) for Armv7
* VSTRW instruction support from Armv8.1-M MVE
* support for additional Arm CP14 and CP15 registers
* Armv8 LDM (user) instruction will update registers predictably even when executing in System Mode, instead of being UNPREDICTABLE according to Arm documentation
* basic support for Cortex-A5 CPU type
* DCIMALL instruction for Aarch32 CPUs
* IMP_CDBGDCI instruction for Cortex-R52 CPUs

Added and improved platform descriptions:

* timer interrupts configuration for STM32F4-based platforms
* improvements to networking configuration for StarFive JH7100
* improvements to Renesas R7FA2E1A9, R7FA2L1A, R7FA4M1A, R7FA6M5B, R7FA8M1A SoC
* improvements to UT32M0R500 SoC
* platform with example sensor connections for CK-RA6M5
* multicore Cortex-R52 platform
* multicore Cortex-A53 with GICv3 in SMP configuration
* improvements to the Cortex-R52 platform
* GIC architecture version selection for many Arm platforms
* added Arm signal unit support for Cortex-R8 and multicore Cortex-R8 platforms
* merged Zynq Ultrascale+ into a single platform with both Cortex-A and Cortex-R CPUs
* updated peripherals registration for STM32F0, STM32F4, STM32F746, STM32G0, STM32H743, STM32L071, STM32L151, STM32L552, STM32WBA52 SoCs

* Renesas CK-RA6M5 board
* Beagle-V Fire, with Microchip's PolarFire SoC

Added peripheral models:

* Gaisler ADC
* NPCX GPIO
* NPCX SMBus
* NXP OS Timer
* Renesas DA SPI
* Renesas RA IIC
* Renesas DA14 GeneralRegisters
* Renesas DA14 XTAL32MRegisters
* S32K3XX EMAC
* S32K3XX FlexCAN
* S32K3XX FlexIO with SENT and UART endpoints
* S32K3XX GMAC
* S32K3XX Low Power IIC
* STM32H7 Crypto Accelerator
* STM32H7 QuadSPI
* STM32WBA GP DMA
* UT32 CAN
* VirtIO Filesystem device
* ZynqMP Inter Processor Interrupt controller
* ZynqMP Platform Management Unit
* ZMOD4410 and ZMOD4510 air quality sensors
* AK09916 and AK09918 3-axis electronic compass sensors
* generic configurable Pulse Generator block

Added demos and tests:

* I2C echo test for Renesas DA14592
* addtional unit tests for CRCEngine
* I2C mode tests for Renesas RA8M1 SCI
* BeagleV-StarLight ethernet tests
* serialization tests for Armv8-A and Armv8-R cores
* Cortex-R8 Zephyr tests
* configuration signals tests for Cortex-R8
* NXP S32K388 Low Power SPI test
* HiRTOS samples (including multicore) on Cortex-R52
* Renesas RA6M5 platform tests including SCI SPI, ICM20948, HS3001, IIC
* EXT2 filesystem Zephyr tests based on SiFive FU740
* STM32H7 Nucleo test for CRYPTO and SPI
* tests for GDB accessing peripheral space
* regression tests for ARMv8 Security State and Exception Level after core initialization
* VirtIO Filesystem directory sharing test
* Zephyr SMP test for Cortex-R52
* aws_cc test for the Renesas CK-RA6M5 board
* machine log level test
* range locking tests in sysbus.robot

Added features:

* mechanism for integrating Renode with SystemC simulations
* VirtIO-based directory sharing with host OS
* new GIC redistributor regions registration methods for multi-core platforms
* CAN analyzer support in Wireshark integration
* CPU-specific function names lookup support
* ability to clear CPU-specific or global function names lookups
* SENT protocol support
* LIN protocol support
* IADC interface for generic ADC control
* support for specifying additional offset to function names addresses in lookups
* locking sysbus accesses to specified ranges
* easier access to externals in Python scripts via externals variable
* external control API with C client library
* integration with dts2repl tool
* virtual CAN host integration via SocketCAN bridge
* ability to control log level of the whole machine with the logLevel command
* ability to specify Privileged Architecture Version 1.12 on RISC-V processors
* optional CPU context in locking sysbus accesses to peripherals

Fixed:

* Migrant not keeping track of all child-parent connections in the Reflection mode
* Arm PMSAv8 configuration using stale values in some circumstances
* Armv7 CP15 registers - ADFSR, AIFSR, non-MP BP*, DC* and IC* registers
* Armv7 and older memory barrier instructions and CP15 registers (DMB, DSB and DWB)
* read accesses to write-only Aarch32 coprocessor registers
* Armv7/Armv8 MPIDR register
* breakpoints serialization and deserialization
* calculation of target EL and interrupt masking for Armv8 Aarch32
* crashes in certian register configurations for Armv8 Aarch32
* FIQs being disabled with no way of enabling them for GICv3 and onwards
* NA4 range end address calculation in RISC-V PMP
* effective PMP configuration calculation in RISC-V when mstatus.MPRV is set
* RISC-V vector load and store segment instructions
* crashes when a breakpoint and a watchpoint trigger at the same instruction
* RISC-V PMP NAPOT grain check implementation
* TranslationCPU's CyclesPerInstruction changes during runtime not being automatically applied to ArmPerformanceMonitoringUnit's cycle counters
* unmapping of memory segments
* unregistering peripherals
* valid Ethernet frames sometimes getting rejected due to CRC mismatch
* virtual time advancing too far when pausing the emulation
* CCSIDR for L1 data cache in Arm Cortex-R8
* CCSIDR for L2 cache in Arm Cortex-R5/R8
* renode-test --include behavior for NUnit test suites
* atomic instructions handling when running multithreaded program on a single CPU machine
* automatic 64-bit access translations on system bus
* crashes on Cortex-M construction if NVIC is already attached to a different core
* exclusive load/store instructions on Armv8
* failures in monitor-tests.Should Pause Renode under certain conditions
* invalid Asciinema generation if the UART output contains a backslash character
* logging value written on an unhandled tag write
* names of Arm TCM registers
* pausing on SemihostingUart events in Xtensa CPUs
* reporting thread ID as decimal number in GDB's query command - cpuId restricted to 32
* selecting PMP access mode for RISC-V cores
* serialization for Armv8-A and Armv8-R cores
* suppressed SP and PC initialization on halted Cortex-M cores
* cache selection in Armv7 and older CPUs, now verified with CLIDR when reading CCSIDR
* precise pausing causing parts of the instruction to be executed twice
* ARM MPU ignoring memory restriction check to the page that was previously accessed even if region/subregion permissions don't match
* Armv8-R AArch32 executing in Secure State instead on Non-Secure
* Armv8-R changing Security State, while it should never do so
* Armv8 cores not propagating their Exception Level and Security State outside tlib correctly after creation
* DMAEngine memory transactions with when not incrementing source or destination addresses
* RISC-V BEXT instruction handling
* RISC-V xRET instructions not changing status bits correctly
* SocketServerProvider not closing correctly without any connected clients
* detection of test failures which should be retried when renode-test's --retry option is used
* handling peripheral accesses when debugging with GDB
* initialization of PC and SP on leaving reset on Cortex-M
* printing of possible values for invalid Enum arguments in Monitor commands
* heterogeneous platforms handling in GDB
* single step execution mode in Xtensa cores
* variable expansion in Monitor


Changed:

* Terminal Tester delayed typing now relies on virtual time
* removed AdvancedLoggerViewer plugin
* improved TAP networking performance on Linux
* reduced overhead of calling tlib exports
* TranslationCPU's CyclesPerInstruction now accepts non-integer values
* CPU Step call now automatically starts the emulation
* upgraded Robot Framework to 6.1, to work with Python 3.12
* renamed the ID property of Arm cores to ModelID
* improved Arm core performance
* improved logging performance if lower log levels are not enabled
* added host memory barrier generation to TCG
* actions delayed with machine.ScheduleAction can now execute as soon as the end of the current instructions block (it used to be quantum)
* CPU's SingleStepBlocking and SingleStepNonBlocking ExecutionModes were replaced by SingleStep and emulation.SingleStepBlocking was added
* blockOnStep was removed from StartGdbServer
* single-step-based tests were refactored due to automatic start on Step and ExecutionMode changes

Improvements in peripherals:

* Andes AndeStarV5Extension.cs - Added Configuration and Crash Debug CSRs
* Arm Generic Interrupt Controller, with changes to v1, v2 and v3 versions, focused on improving multicore support for both Armv7 and Armv8 platforms
* Gaisler APBUART
* Gaisler GPTimer
* Gaisler Ethernet
* Gaisler MIC
* Kinetis LPUART
* NPCX FIU
* NPCX Flash
* NXP LPSPI
* Renesas RA8M1 SCI
* Renesas DA I2C
* Renesas DA Watchdog
* Renesas DA14 DMA
* Renesas RA6M5 SCI
* Renesas DA DMABase
* S32K3XX LowPowerInterIntegratedCircuit
* SDCard
* STM32 PWR
* STM32F4 CRC
* STM32H7 RCC
* Synopsys DWCEthernetQualityOfService
* Synopsys EthernetMAC
* VirtIOBlockDevice, now based on VirtIO MMIO version v1.2
* Xilinx IPI mailbox
* BME280 sensor
* ICM20948 sensor
* SHT45 sensor


1.15.0 - 2024.03.18
-------------------

Added architecture support:

* initial support for ARMv7-R and Cortex-R8, verified with ThreadX and Zephyr
* initial support for Cortex-A55
* initial support for Cortex-M23 and Cortex-M85
* support for RISC-V Bit Manipulation extensions - Zba, Zbb, Zbc and Zbs
* support for RISC-V Half-precision Floating Point (Zfh) extension, including vector operations
* support for RISC-V Andes AndeStar V5 ISA extension

Added and improved platform descriptions:

* generic Cortex-R8 platform
* Renesas EK-RA2E1 board with R7FA2E1A9 SoC
* Arduino Uno R4 Minima platform with Renesas F7FA4M1A SoC
* Renesas CK-RA6M5 board with R7FA6M5B SoC, with initial radio support
* Renesas EK-RA8M1 board with R7FA8M1A SoC
* Renesas R7FA2L1A SoC
* Renesas DA14592 SoC
* Renesas RZ/T2M-RSK board with RZ/T2M SoC
* Gaisler GR712RC SoC with UART, timer, GPIO, FTMC and Ethernet
* Gaisler GR716 SoC with UART, timer and GPIO
* Gaisler UT32M0R500 SoC with UART, timer and GPIO
* NXP S32K388 with UART, timers, watchdog, SIUL2, SPI, Mode entry module and others
* NXP LPC2294 SoC with UART, CAN, timer and interrupts support
* Xilinx Zynq UltraScale+ MPSoC platform support with single core Cortex-A53, UART, GPIO and I2C
* singlecore Cortex-R5 part of Zynq UltraScale+ MPSoC platform with UART, TTC, Ethernet and GPIO
* Nuvoton NPCX9 platform support with UART, various timers, SPI, flash and other peripherals
* ST Nucleo H753ZI with STM32H753 SoC with a range of ST peripherals
* updates to Armv8-A platforms
* updates to Ambiq Apollo4
* updates to Xilinx Zynq 7000
* various updates in STM32 platform files

Added peripheral models:

* ABRTCMC, I2C-based RTC
* Altera JTAG UART
* Ambiq Apollo4 Watchdog
* Arm Global Timer
* Arm Private Timer
* Arm SP804 Timer
* ArmSnoopControlUnit
* BCM2711 AUX UART
* BME280 sensor
* Betrusted EC I2C
* Betrusted SoC I2C
* Bosch M_CAN
* CAN to UART converter
* Cadence Watchdog Timer
* Gaisler APBUART
* Gaisler GPIO
* GigaDevice GD32 UART
* HS3001 sensor
* ICM20948 sensor
* ICP10101 sensor
* Infineon SCB UART
* LINFlexD UART
* MB85RC1MT Ferroelectric Random Access Memory
* MXIC MX66UM1G45G flash
* NPCX FIU
* NPCX Flash
* NPCX HFCG
* NPCX ITIM32
* NPCX LFCG
* NPCX MDMA
* NPCX Monotonic Counter
* NPCX SPIP
* NPCX Timer and Watchdog
* NPCX UART
* NXP LPC CAN
* NXP LPC CTimer
* NXP LPC USART
* OB1203A sensor
* PL190 vectored interrupt controller
* PL330_DMA (CoreLink DMA-330) Controller
* Renesas DA14 DMA peripheral
* Renesas DA14 GPIO
* Renesas DA14 General Purpose Timer
* Renesas DA14 UART
* Renesas DA14 I2C
* Renesas DA16200 Wi-Fi module
* Renesas RA series AGT
* Renesas RA series GPIO
* Renesas RA series GPT
* Renesas RA series ICU
* Renesas RA series SCI
* Renesas RZ/T2M GPIO
* Renesas RZ/T2M SCI
* S32K3XX Miscellaneous System Control Module
* S32K3XX Periodic Interrupt Timer
* S32K3XX Real Time Clock
* S32K3XX Software Watchdog Timer
* S32K3XX System Integration Unit Lite 2
* S32K3XX System Timer Module
* S32K3XX FlexIO stub
* S32K3XX Mode Entry Module
* SHT45 temperature/humidity sensor
* SPI NAND flash
* STM32WBA PWR
* Samsung K9 NAND Flash
* Smartbond UART
* Universal Flash Storage (JESD220F)
* Universal Flash Storage Host Controller (JESD223E)
* XMC4XXX UART
* ZMOD4xxx sensor
* Zynq 7000 System Level Control Registers


1.14.0 - 2023.08.08
-------------------

Added architecture support:

* initial support for ARMv8-A, verified with a range of software, from Coreboot and U-Boot to Linux
* initial support for ARMv8-R, verified with U-Boot and Zephyr

Added and improved platform descriptions:

* generic Cortex-A53 platform, in flavors with GICv3 and GICv2
* generic Cortex-A78 platform
* generic Cortex-R52 platform
* HiFive Unmatched platform support, with UART, PWM, I2C, GPIO, Ethernet, QSPI and other peripherals
* Nucleo WBA52CG with STM32WBA52
* updated OpenTitan and EarlGrey platform to a newer version
* various updates in STM32 platform files
* translation support for Espressif ESP32 chips

Added peripheral models:

* ARM GIC, compatible with various specification versions
* ARM generic timer
* CMSDK APB UART
* Cypress S25H Flash
* EFR32xG2 I2C
* EFR32xG2 RTCC
* EFR32xG2 UART
* Marvell Armada Timer
* MXC UART
* OMAP Timer
* OpenTitan Entropy Distribution Network
* Quectel BC66
* Quectel BG96
* SI7210 Temperature sensor
* SPI multiplexer
* STM32F4 CRC
* STM32F4 Flash
* STM32H7 Flash
* STM32WBA Flash
* STM32H7 Hardware Semaphore
* STM32H7 SPI
* STM32WBA SPI
* STM32WBA ADC
* Synopsys DWC Ethernet QoS model, along with Linux-based tests
* TMP108 Temperature sensor

Added demos and tests:

* Cortex-A53 and Cortex-A78 running Coreboot, ATF and Linux
* Zephyr running echo_client demo on STM32F7-disco with Quectel BG96
* basic Cortex-A53 Zephyr ``hello-world`` test and sample
* additional Zephyr tests for Cortex-A53: ``synchronization``, ``philosophers``, kernel FPU sharing
* seL4 Adder Sample test for Cortex-A53
* range of Zephyr tests for Cortex-R52, along with custom-made, synthetic tests
* precise pausing tests for LED and terminal tester

Added features:

* renode-test allows to run tests with a specified tag via the ``--include`` switch
* DPI interface for external HDL simulators, supporting AXI4 interface
* portable package creation on dotnet
* option to have Robot test pause execution deterministically after a match in various testers: UART, LED, log
* duty cycle detection in LED tester
* option to load files (e.g. raw binaries, hex files) to different localizations, like memories
* support for relative paths in REPL file ``using`` directive
* MPU support for Cortex-M
* ``FAULTMASK`` register in Cortex-M
* support for Trace Based Model performance simulator by Google
* read and write hooks for peripherals
* DPI interface support for co-simulating with RTL, with initial support for AXI4 bus
* build.sh ``--profile-build`` switch to enable easier profiling of translation libraries
* mechanism for progressing virtual time without executing instructions
* support for subregions in Cortex-M MPU
* support for FPU exceptions for Cortex-M
* quad word (64-bit) peripherals API
* ``CSV2RESD`` tool, for easy generation of RESD files
* automatic selection of port used to communicate between Renode and Robot
* option to pause emulation of Robot keywords
* support for NMI interrupts in RISC-V
* option to save Renode logs for all tests
* ``Execute Python`` keyword in Robot tests

Changed:

* GDB interacts with Renode much faster
* Renode now uses Robot Framework 6.0.2 for testing (with an option to use other versions at your own risk)
* RESD format now accepts negative ``sampleOffsetTime``
* HEX files loader now supports extended segment address and start segment address sections
* GDB ``autostart`` parameter now starts the simulation as soon as the debugger is connected
* VerilatorIntegrationLibrary is now part of Renode packages
* improved performance of the virtual time handling loop
* improved parsing of RESD files
* improved memory allocation mechanism to allocate memory regions larger than 2GiB
* support for mapping memories on very high offsets
* improved GDB connection robustness
* exposed Monitor as a variable in Python hooks
* improved the GDB compare helper script
* improved handling of input files in TFTP server module

Fixed:

* cursor blinking in terminal on Windows
* crash when NetworkServer tried to log an invalid packet
* race condition when trying to pause during the machine startup
* platform serialization when CPU profiler is enabled
* limit buffer behavior in verilated peripherals when they are reset
* registration is no longer taken into account when looking for dependency cycles in REPL files
* exception when issuing a DMA transaction during register access
* reported PC on exception when executing vector instructions in RISC-V
* several RISC-V vector instructions handling, e.g. ``vfredosum``, ``vsetivli`` and ``vector_fpu``
* invalid instruction block exiting on RISC-V
* handling of ``c.ebreak`` instruction in RISC-V, allowing for software breakpoints
* building fixes on dotnet
* removing of IO access flag from memory pages
* invalidation of dirty translation blocks
* handling of MMU faults on address translations
* serialization of RESD files
* automatic creation of TAP interface on Linux
* ARM LDA/STL instructions decoding
* handling of platforms containing both 32- and 64-bit CPUs
* file permissions in .NET portable packages
* handling of non-resettable register fields
* several RISC-V vector instructions
* handling of the context menu in the Monitor window
* support for Cortex-M4F in LLVMDisassembler
* packets matching method in NetworkInterfaceTester
* address calculations in DMA engine
* custom build properties handling in Renode build script
* handling of time reporting and empty test cases in renode-test

Improvements in peripherals:

* AmbiqApollo4 Timer
* ArrayMemory
* AS6221 Temperature sensor
* AT Command Modem
* AT91 Timer
* Cadence UART
* Cortex-M Systick
* EF32MG12 LDMA
* Ibex
* LIS2DW12 Accelerometer
* LiteX I2C
* LSM6DSO
* MAX30208 Temperature sensor
* MAX32650 GPIO
* MAX32650 I2C
* MAX32650 RTC
* MAX32650 SPI
* MAX32650 Timer
* MAX32650 TPU
* MAX32650 WDT
* MAX86171 AFE
* nRF52840 SPI
* nRF52840 I2C
* nRF52840 GPIO
* OpenTitan HMAC
* OpenTitan PLIC
* OpenTitan ROM
* OpenTitan OTP
* OpenTitan Key Manager
* OpenTitan Flash
* OpenTitan Reset Manager
* OpenTitan KMAC
* OpenTitan CSRNG
* OpenTitan Alert Handler
* OpenTitan Timer
* OpenTitan OTBN
* PL011 UART
* Quectel BC660K
* SAMD5 UART
* SiFive GPIO
* Silencer
* STM32 DMA
* STM32G0 DMA
* STM32 EXTI, with specific implementations for STM32F4, STM32H7 and STM32WBA
* STM32 GPIO
* STM32F7 I2C
* STM32L0 LPTimer
* STM32L0 RCC
* STM32H7 RCC
* STM32F4 RTC
* STM32 SPI
* STM32 Timer
* STM32F7 USART

1.13.3 - 2023.02.22
-------------------

Added and improved platform descriptions:

* basic Adafruit ItsyBitsy M4 Express platform with UART and memories
* various STM32 platforms with improved EXTI connections, IWDG configuration, and new CRC, Flash, PWR, RCC, and LPTimer models added to selected platforms
* MAX32650 with a new I2C model
* Zynq 7000 with new I2C, SPI, UART and TTC models
* Apollo 4 with a new Timer model and a ``program_main2`` bootrom function mock
* OpenTitan Earlgrey with new OTBN accelerator, AON Timer, System Reset controller, Entropy source, and SRAM controller models
* nRF52840 with a new EGU model
* EFR32MG1x with a new LDMA model and improved USART interrupt connections

Added peripheral models:

* Apollo4 IOMaster I2C mode
* Apollo4 Timer
* AS6221 skin temperature sensor
* Cadence I2C controller
* Cadence SPI controller
* Cadence TTC
* Cadence UART
* Cadence xSPI controller
* EFR32MG12 LDMA controller
* LIS2DW12 accelerometer sensor
* LC709205F Fuel Gauge
* Macronix MX25R flash
* MAX30208 temperature sensor
* MAX32650 I2C controller
* MAX77818 Fuel Gauge
* MAX86171 Optical AFE
* NRF52840 EGU
* OpenTitan AON Timer
* OpenTitan Big Number Accelerator (OTBN) full model
* OpenTitan ClockManager stub
* OpenTitan Entropy Source controller
* OpenTitan SRAM controller
* OpenTitan SystemReset controller
* Quectel BC660K radio
* RV8803 RTC
* STM32F0 CRC
* STM32H7 RCC
* STM32L0 Flash controller
* STM32L0 Low Power Timer
* STM32L0 PWR
* TMP103 temperature sensor

Added demos and tests:

* RTC mode unit test
* Adafruit ItsyBitsy M4 Express Zephyr shell_module test
* STM32L072 tests for: DMA, PVD interrupt, SPI flash, IWDG, LPUART, EEPROM, and CRC
* STM32F4 tests for RTC and running an STM32CubeMX app
* Zynq tests for I2C, TTC, SPI flash, xSPI, and UART based on Linux

Added features:

* support for RESD - Renode Sensor Data format, allowing users to provide multiple sensors with time-coordinated data specific for a given sensor; currently supported in MAX86171, MAX30208, AS6221, and LSM6DSO
* reorganized CPU classes and interfaces, allowing for easier integration of external CPU simulators
* IOMMU, with example usage in WindowIOMMU, WindowMMUBusController, and SimpleDMA
* new key bindings in the Monitor: Ctrl+D for closing the window and Ctrl+U for clearing the current input
* new key bindings in all terminal windows: Shift+Up/Down arrow for line scrolling and Shift+Home/End for jumping to the beginning and the end of the buffer
* option to configure UART window location offsets via the config file
* support for 64-bit bus accesses and 64-bit peripherals
* support non-resettable peripheral registers and register fields
* option to register hooks to be called whenever a RISC-V register is accessed - this can be used to emulate non-standard implementation of these registers
* option to set CPU exceptions from the outside of the CPU
* Robot keyword to verify that GPIO has a specified state for a given period of time
* verbose mode in Robot tests

Changed:

* Robot tests do not need a header with settings and keywords anymore
* changed the conditional syntax in Robot tests to use IF/ELSE for compatibility with newer Robot Framework versions
* cleaned up tests-related file organization in the repository
* simplified flags for renode-test under dotnet
* added skip_mono and skip_dotnet tags to Robot tests
* removed internal signal mappings from STM32 EXTI, making the interrupt routing more explicit in REPL files
* console mode will be started instead of telnet when the UI fails to start
* reset can now be executed on a not started machine
* expanded the Execution Tracer with ``TrackMemoryAccesses`` and ``TrackVectorConfiguration`` options, along with disassembler-generated info
* OnMemoryAccess hooks now receive the current PC as a parameter
* changed the CRCEngine API and improved implementation
* ELF symbol lookup will now skip several types of unimportant symbols
* tags can now have zero width to ease the creation of variable width registers
* added option to invert reset logic in AXI4Lite
* added handling of the ``WSTRB`` signal in AXI4Lite
* added support for various address lines connections in Wishbone
* added various access lengths support for verilated peripherals
* timeout value for Verilator connections can now be defined in compile time
* all architectures now sync their PC on memory accesses
* UARTBase is now a container for IUART devices
* added option to clear all event subscribers in LimitTimer
* added ITimer interface for handling basic timer properties
* extended the excluded assembly list in TypeManager to speed up startup on dotnet

Fixed:

* flushing of the log when using the ``lastLog`` command
* deadlock when using the ``--console`` mode on dotnet with collapsed log entries enabled
* Wireshark handling on macOS
* TAP support on macOS
* Asciinema usage in multi-machine setups
* closing of Renode in several problematic scenarios
* handling of end of file detection in HEX parsing
* robustness of BLESniffer
* timestamps discrepancies in file logs and console logs
* compilation under Visual Studio on Windows
* compilation on Windows when the PLATFORM environment variable is set
* graph titles for metrics visualizer
* handling of peripheral regions in Profiles
* file sharing and access type settings for open files
* floating point registers access on RV32
* several RISC-V Vector instructions
* crash when the CPU is created with an invalid type
* RISC-V PMP config reading and writing and NAPOT decoding
* translation cache invalidation in multicore RISC-V scenarios
* SEV generation on Cortex-M
* handling of multi-instructions blocks in Xtensa
* execution of too many instructions in a single block
* button sample tests for STM32F072q
* fastvdma co-simulation test
* qCRC packet handling in GDB
* decoding of GDB packets, selecting the command handler based on the longest match for a packet
* address translation in GDB
* UARTToSpiConverter logic and user experience
* handling of Step parameter in ClockEntry
* changing of frequency for divider calculation in ComparingTimer
* cleanup of old clock entries

Improvements in peripherals:

* AmbiqApollo4 IOMaster
* AmbiqApollo4 RTC
* AthenaX5200
* Cadence TTC
* Dummy I2C Slave
* EFR32 CMU
* EFR32 USART
* EFR32 RTCC
* Generic SPI Flash
* HiMax HM01B0
* I2C dummy device
* LSM6DSO IMU
* Mapped Memory
* Micron MT25Q
* MPFS PDMA
* NRF52840 SPI
* NRF52840 I2C
* NRF52840 RTC
* NVIC interrupt controller
* OpenCores I2C
* OpenTitan I2C
* OpenTitan Flash controller
* OpenTitan LifeCycle controller
* OpenTitan ROM controller
* SAMD5 UART
* SI70xx temperature sensor
* SiFive GPIO
* STM32 GPIO
* STM32 SPI
* STM32 Timer
* STM32F4 IndependentWatchdog
* STM32F4 RTC
* STM32F7 I2C
* STM32F7 USART
* STM32L0 RCC
* STM32G0 DMA

1.13.2 - 2022.10.03
-------------------

Added platforms:

* Ambiq Apollo4 with ADC, GPIO, IO Master, System Timer, RTC, UART and other peripherals
* STM32L07x with ADC, GPIO, I2C ,RTC, SPI, Timer, USART, IWDG, DMA and other peripherals (RCC)
* verilated Ibex core with the rest of the platform natively in Renode

Added models:

* MAX32650 TPU with CRC32 support
* basic support for MAX32650 ADC
* MAX32650 SPI
* MAX32650 Watchdog
* LSM6DSO IMU
* EFR32xG12DeviceInformation
* External CPU stub as a base for integration of other CPU simulators
* OpenTitan SPI host
* OpenTitan I2C host
* OpenTitan Alert Handler, along with updates to other OpenTitan peripherals with alert functionality
* new algorithms and cores in AthenaX5200
* EFR32MG1 BitAccess
* i.MX RT GPTimer

Added demos and tests:

* STM32L072 Zephyr shell_module demo and test
* Ambiq Apollo4 Hello World example from Ambiq Suite and various peripheral tests
* MAX32652 EVKIT Hello World example from MAX32652 SDK
* FPGA ISP co-simulation demo and test

Added features:

* experimental support for .NET 6 framework
* guest-application profiling for ARM
* Interrupt hooks for ARM
* BLE sniffer support for Wireshark
* Perfetto profiler format support in guest-application profiling, along with process detection on RISC-V
* binary output format of execution tracer, along with a Python helper script to decode data
* new Run Until Breakpoint keyword for Robot tests
* verbose mode in Robot tester
* region of interest support in FrameBufferTester
* framework for providing timestamped sensor data
* WishboneInitiator bus in Verilator support
* nightly “sources” package with the whole content required for building Renode offline

Organizational improvements:

* added GitHub issue and PR templates, along with an `issue reproduction repository <https://github.com/renode/renode-issue-reproduction-template>`_
updated contributing instructions

Changed:

* added mapping for l2ZeroDevice in PolarFire SoC
* added caching of canvas bounds in TermSharp for improved performance
* restructured height map storage in TermSharp
* updated descriptions of SLTB004A and EFR32MG12 targets
* restructured CPU-related class hierarchy
* disabled TCG optimizations and liveness analysis for improved performance
* updated OpenTitan supported version, changing a range of OpenTitan peripherals
* major refactor of VerilatorIntegrationLibrary, with new interfaces and code restructuration
* updated symbol exclusion rules not to include $x symbol names in SymbolLookup
* disabled TLB flushing in RISC-V on mode change for improved performance
* allowed more than one page permission at a time in RISC-V, reducing the number of address translations
* improved output of Robot tests with timestamps and explicit test results after each suite
* SD card controller now supports more card types

Fixed:

* PMP implementation for RISC-V
* several RISC-V vector instructions including floating-point vector instructions
* 'Take Screenshot' button in VideoAnalyzer
* non-blocking CPU stepping
* crash when loading file without sufficient permissions
* external MMU not respecting the `no_page_fault` flag
* issues with concurrent creation of config file
* indeterminism of sel4_extensions test
* GDB Stub not issuing an error when trying to add zero-sized watchpoint
* handling of watchpoints on big-endian platforms
* portability of MSBuild calls across different host systems
* PolarFire SoC Watchdog test
* serialization of FrameBufferTester
* translation cache flushing after reset

Improvements in peripherals:

* Cortex-M NVIC
* HPSHostController
* NRF52840 Watchdog
* BMC050 accelerometer
* MAX32650 RTC
* MAX32650 GCR
* STM32F7 I2C
* STM32G0 DMA
* Micron MT25Q
* i.MX RT GPIO


1.13.1 - 2022.07.23
-------------------

Added platforms:

* MAX32652 with UART, GPIO, Timer, PWRSEQ, GCR and RTC
* Thunderboard Sense 2 (SLTB004A) based on EFR32MG12

Added models:

* STM32G0 DMA controller
* OpenTitan CSRNG
* OpenTitan OTP controller
* OpenTitan Life Cycle controller
* USBserialport_S3B model for Qomu
* SAMD5 UART
* SAMD20 UART
* AES and Message Authentication cores for AthenaX5200
* LiteX MMCM controller in the 32-bit CSR width configuration
* LiteX Framebuffer in the 32-bit CSR width configuration

Added demos:

* Qomu running Zephyr shell
* SLTB004A running Gecko SDK baremetal CLI sample

Added features:

* guest-application profiling support
* TAP integration on Windows
* interrupt end hooks for RV64
* option for gathering execution metrics when running tests
* tests for logging from a sub-object
* PolarFireSoC Watchdog tests
* the disassembly output format to the Execution Tracer module
* option for filtering messages by log level in the log tester

Changed:

* improved support for ARMv8-M registers
* added option to compare raw values of selected registers in the gdb_compare script
* implemented generation of guest-host PC mappings info on block translation
* added `Frequency` property to ComparingTimer
* monitor-tests: Use virtual time in the pause test
* added static flushing to the logger
* included missing tools (like gdb_compare, sel4_extensions) in all packages
* added precompilation of Python scripts before running (to detect errors early)
* added user-specified file paths handling
* added filtering of ANSI escape codes from Robot tests keyword results
* added option to enable profiler globally in EmulationManager
* added command to disable automatic symbol switching in seL4 GDB extensions
* improved RISC-V kernel breakpoints support in seL4 GDB extensions
* code generator is now compiled with more aggressive optimizations
* changed the CPU class structure, allowing for core implementations not based on translation libraries
* updated the Nexys Video platform description and demo binaries

Fixed:

* 'Should Output Voice Data' test for QuickFeather
* various RISC-V vector instructions
* register values accessing in RISC-V
* help button behavior in AdvancedLoggerViewer
* concurrent access to Pixel Manipulation Tools
* clock residuum handling, e.g. improving the behavior of the BLE demo
* serialization of externals and GDB stub
* stacktrace reporting when exception is rethrown on the native-managed boundary
* packaging of license files from dependency projects
* exception handling on EnsureTypeIsLoaded
* various fixes in file handling layer
* improved handling of variables assigned to variables in the Monitor
* handling of multiple CPUs with different configurations in GDB
* STM32F413 RCC address
* DDR mapping in PolarFire SoC
* TCM memory size in miv_rv32

Improvements in peripherals:

* NVIC
* STM32F4_RCC
* STM32_ADC
* STM32_GPIOPort
* MiV_CoreGPIO
* GigaDevice_GD25LQ
* MC3635
* SynopsysEthernetMAC
* LiteSDCard_CSR32
* ResetPin
* HPSHostController

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

