# C and C# debugging on .NET

This file sums up the procedure required to perform debugging of both native code and C# when running on .NET ("interop debugging" in Microsoft nomenclature).

Interop debugging is supported on Mono just by connecting a C# debugger and GDB. Unfortunately it isn’t currently supported on .NET and there is no plan for adding such support: https://github.com/dotnet/runtime/issues/34964#issuecomment-730006892.

With additional scripting we are able to enable it at least partially.

## vsdbg + GDB

Analogically to debugging on Mono it’s possible to connect a C# debugger (vsdbg) and GDB to .NET runtime.

The C# debugger can be used only with IDEs from the Visual Studio family.

1. Checkout the interop-debug branch from https://github.com/renode/renode.
2. Add breakpoints in the following lines

	 * https://github.com/renode/renode-infrastructure/blob/f81c53b221567127c84ae77f1adcbbc0ec4e8f93/src/Emulator/Cores/Arm/ARM_GenericInterruptController.cs#L1895
	 * https://github.com/antmicro/tlib/blob/fa669b4138ca138a944349a6a3504c513743e141/arch/arm/helper.c#L1007

3. Run the "Launch .NET - Debug" configuration in VS Code
4. Run the "(gdb) Tlib .NET Attach" configuration in VS Code and select the process that runs Renode
5. Run the following command in the Monitor:

   * s @scripts/single-node/xilinx_zynqmp_r5.resc

6. Debug both C and C# code at the same time

## Known issues:
1. Adding breakpoints after starting the gdb debugger is not stable.
2. We are still working on stepping support on the C side.
3. VS Code sometimes doesn’t jump to a proper line of code, but reports proper thread and line as `Paused on breakpoint`.
4. It probably doesn’t work with all versions of GDB. It has been tested with GDB 13.1 and 13.2 and with .NET 6.0.417.
5. This procedure requires GDB with Python support
