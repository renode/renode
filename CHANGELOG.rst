Renode changelog
================

This document describes notable changes to the Renode framework.

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

