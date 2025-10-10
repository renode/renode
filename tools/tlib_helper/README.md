# GDB helper functions for debugging tlib

`tlib_helper` is a collection of helper functions that give the user a better context of the whole Renode simulation while debugging the translated guest code execution in [tlib](https://github.com/antmicro/tlib).

## Features

* Create breakpoint on next guest instruction,
* Disassemble current instruction,
* Disassemble current Translation Block,
* Read bytes from the system bus,
* Support for multiple CPUs through the `$_cpu(index)` convenience function,
* Access to current guest PC through the `$guest_pc` variable.

## Usage

All functionality is self-contained in the single `gdbscript.py`, therefore it is enough to just source the script in GDB using the `source` command. For example, to attach GDB to already running dotnet-built Renode instance the following command can be used:

```sh
$ gdb -ex 'source tools/tlib_helper/gdbscript.py' \
      -ex 'handle SIG34 nostop noprint' \
      -p $(pgrep --full 'dotnet.*Renode.dll')"
```

Additional information about commands can be accessed through `help renode` GDB command.
