## Compare execution using reference GDB

This directory contains script comparing Renode execution with a given reference using GDB.

### Requirements

To install required python packages run:
```
    python3 -m pip install -r tools/gdb_compare/requirements.txt
```

### Usage

```
usage: gdb_compare.py [-h] -r REFERENCE_COMMAND -c COMMAND -s RENODE_SCRIPT -p REFERENCE_GDB_PORT [--renode-gdb-port RENODE_GDB_PORT] [-P RENODE_TELNET_PORT]
                      -b DEBUG_BINARY [-x RENODE_PATH] [-g GDB_PATH] [-f START_FRAME] [-i IPS] [-S STOP_ADDRESS]

Compare Renode execution with hardware/other simulator state using GDB

optional arguments:
  -h, --help            show this help message and exit
  -r REFERENCE_COMMAND, --reference-command REFERENCE_COMMAND
                        Command used to run the GDB server provider used as a reference
  -c COMMAND, --gdb-command COMMAND
                        GDB command to run on both instances after each instruction. Outputs of these commands are compared against each other.
  -s RENODE_SCRIPT, --renode-script RENODE_SCRIPT
                        Path to the '.resc' script
  -p REFERENCE_GDB_PORT, --reference-gdb-port REFERENCE_GDB_PORT
                        Port on which the reference GDB server can be reached
  --renode-gdb-port RENODE_GDB_PORT
                        Port on which Renode will comunicate with GDB server
  -P RENODE_TELNET_PORT, --renode-telnet-port RENODE_TELNET_PORT
                        Port on which Renode will comunicate with telnet
  -b DEBUG_BINARY, --binary DEBUG_BINARY
                        Path to ELF file with symbols
  -x RENODE_PATH, --renode-path RENODE_PATH
                        Path to the Renode runscript
  -g GDB_PATH, --gdb-path GDB_PATH
                        Path to the GDB binary to be run
  -f START_FRAME, --start-frame START_FRAME
                        Sequence of jumps to reach target frame. Formated as 'addr, occurence', separated with ';'. Eg. '_start,1;printf,7'
  -i IPS, --interest-points IPS
                        Sequence of address, interest points, after which state will be compared. Formated as ';' spearated list of hexadecimal addresses.
                        Eg. '0x8000;0x340eba3c'
  -S STOP_ADDRESS, --stop-address STOP_ADDRESS
                        Stop condition, if reached script will stop
```

Example:
```
python gdb_compare.py -r 'openocd -f my_board.cfg' -c 'info registers' -s my_board.resc -p 3333 -b firmware.elf -g `arm-zephyr-eabi-gdb` -f 'main,1;printf,5'
```
