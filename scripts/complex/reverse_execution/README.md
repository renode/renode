# Reverse Execution Demo

This is a demo showcasing Renode's support for GDB reverse execution.

## Running the demo

1. `gdb_reverse_execution.resc` Renode script creates a RISC-V machine with small assembly printing to UART.

```bash
renode scripts/complex/reverse_execution/gdb_reverse_execution.resc
```

2. Use `script.gdb` GDB script to easily connect to Renode with preset breakpoints.

```bash
gdb -x script.gdb
```

3. Follow the flow of the demonstration

```
Breakpoint 1, 0x80000000 in ?? ()
(gdb) continue
Continuing.

Breakpoint 2, 0x80000014 in ?? ()
(gdb) continue
Continuing.

Breakpoint 3, 0x8000003a in ?? ()
```

Now you can see `:(` printed on UART.

4. Execute `reverse-*` commands in GDB:

```
(gdb) reverse-continue
Continuing.

Breakpoint 2, 0x80000014 in ?? ()
(gdb) reverse-stepi
0x80000010 in ?? ()
(gdb) rsi
0x8000000e in ?? ()
(gdb) rc
Continuing.

Breakpoint 1, 0x80000000 in ?? ()
(gdb)
```

5. Set `t4` register to `0x1337` to branch in `beq t3, t4, ok` test.

```
(gdb) set $t4=0x1337
(gdb) continue
Continuing.

Breakpoint 2, 0x80000014 in ?? ()
(gdb) continue
Continuing.

Breakpoint 3, 0x8000003a in ?? ()
(gdb)
```

Spot `OK` on UART console!

---

For more information visit [Renode documentation](https://renode.readthedocs.io/en/latest/debugging/gdb.html#reverse-execution)
