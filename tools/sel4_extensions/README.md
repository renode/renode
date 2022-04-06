# seL4 extensions for GDB

Convenience script for GDB, adding additional facilities for
debugging seL4 applications.

## Features

* Creating and removing breakpoints on address in specific thread,
* Creating and removing breakpoint on context-switches between kernel and userspace,
* Auto-loading symbols for CAmkES project
* Investigating current thread

## Usage

Firstly, `seL4Extensions.cs` and kernel symbols have to be loaded in Renode. This can be accomplished by adding following lines to `.resc` file:
```
include @path/to/seL4Extensions.cs
sysbus LoadSymbolsFrom @path/to/kernel.elf
```
Before simulation is started (using `start` command in Renode), the seL4 extensions have to be loaded on
correct CPU, which can be done using `cpu CreateSeL4` command in Renode. Lastly, the Renode-GDB glue has to be sourced in GDB. All those steps can be done in single command:

```
$ gdb-multiarch -ex 'target remote :3333' -ex 'monitor cpu CreateSeL4' \
                -ex 'source path/to/gdbscript.py' -ex 'monitor start'
```

`start` at the end is optional.
In GDB information about commands can be accessed using `info sel4` command.

## Example

### Create breakpoint on main function in rootserver thread

```
(gdb) # Wait until rootserver thread is known to seL4 extensions
(gdb) sel4 wait-for-thread rootserver
(gdb) # Switch symbols to rootserver's
(gdb) sel4 switch-symbols rootserver
(gdb) # Create temporary breakpoint on main function in rootserver thread
(gdb) sel4 tbreak rootserver main
(gdb) continue
(gdb) # We can confirm, that we are indeed in rootserver thread
(gdb) sel4 thread
rootserver
```

### Return from userspace to kernel

```
(gdb) # Create temporary breakpoint on context-switch to kernel
(gdb) sel4 tbreak kernel
(gdb) continue
(gdb) sel4 thread
kernel
```
