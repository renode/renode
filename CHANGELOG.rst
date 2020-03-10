Renode changelog
================

This document describes notable changes to the Renode framework.

1.9.0 - 2019.03.10
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

