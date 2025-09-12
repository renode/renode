#!/usr/bin/env python3
#
# Copyright (c) 2010-2023 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import asyncio
import argparse
import pexpect
import psutil
import re
import difflib
from time import time
from os import path
from typing import Any, Optional, Callable, Awaitable

RENODE_GDB_PORT = 2222
RENODE_TELNET_PORT = 12348
RE_HEX = re.compile(r"0x[0-9A-Fa-f]+")
RE_VEC_REGNAME = re.compile(r"v\d+")
RE_GDB_ERRORS = (
    re.compile(r"\bUndefined .*?\.", re.MULTILINE),
    re.compile(r"\bThe \"remote\" target does not support \".*?\"\.", re.MULTILINE),
    re.compile(r"\bNo symbol \".*?\".*?\.", re.MULTILINE),
    re.compile(r"\bCannot .*$", re.MULTILINE),
    re.compile(r"\bRemote communication error\..*$", re.MULTILINE),
    re.compile(r"\bRemote connection closed", re.MULTILINE),
    re.compile(r"\bThe program has no registers.*?\.", re.MULTILINE),
    re.compile(r"\bThe program is not being run.*?\.", re.MULTILINE),
    re.compile(r"\b.*: cannot resolve name.*$", re.MULTILINE),
    re.compile(r"\b.*: no such file or directory\.", re.MULTILINE),
    re.compile(r"\bArgument required.*?\.", re.MULTILINE),
    re.compile(r'\b.*: .*(not in executable format|file format not recognized)', re.MULTILINE),
    re.compile(r"\bNo symbol table is loaded\.", re.MULTILINE),
)

parser = argparse.ArgumentParser(
    description="Compare Renode execution with hardware/other simulator state using GDB")

cmp_parser = parser.add_mutually_exclusive_group(required=True)
cmp_parser.add_argument("-c", "--gdb-command",
                        dest="command",
                        default=None,
                        help="GDB command to run on both instances after each instruction. Outputs of these commands are compared against each other.")
cmp_parser.add_argument("-R", "--register-list",
                        dest="registers",
                        action="store",
                        default=None,
                        help="Sequence of register names to compare. Formated as ';' separated list of register names, e.g. 'pc;ra'")

parser.add_argument("-r", "--reference-command",
                    dest="reference_command",
                    action="store",
                    required=True,
                    help="Command used to run the GDB server provider used as a reference")
parser.add_argument("-s", "--renode-script",
                    dest="renode_script",
                    action="store",
                    required=True,
                    help="Path to the '.resc' script")
parser.add_argument("-p", "--reference-gdb-port",
                    type=int,
                    dest="reference_gdb_port",
                    action="store",
                    required=True,
                    help="Port on which the reference GDB server can be reached")
parser.add_argument("--renode-gdb-port",
                    type=int,
                    dest="renode_gdb_port",
                    action="store",
                    default=RENODE_GDB_PORT,
                    help="Port on which Renode will comunicate with GDB server")
parser.add_argument("-b", "--binary",
                    dest="debug_binary",
                    action="store",
                    required=True,
                    help="Path to ELF file with symbols")
parser.add_argument("-x", "--renode-path",
                    dest="renode_path",
                    action="store",
                    default="renode",
                    help="Path to the Renode runscript")
parser.add_argument("-g", "--gdb-path",
                    dest="gdb_path",
                    action="store",
                    default="/usr/bin/gdb",
                    help="Path to the GDB binary to be run")
parser.add_argument("-f", "--start-frame",
                    dest="start_frame",
                    action="store",
                    default=None,
                    help="Sequence of jumps to reach target frame. Formated as 'addr, occurrence', separated with ';', e.g. '_start,1;printf,7'")
parser.add_argument("-i", "--interest-points",
                    dest="ips",
                    action="store",
                    default=None,
                    help="Sequence of address, interest points, after which state will be compared. Formatted as ';' spearated list of hexadecimal addresses, e.g. '0x8000;0x340eba3c'")
parser.add_argument("-S", "--stop-address",
                    dest="stop_address",
                    action="store",
                    default=None,
                    help="Stop condition, if reached script will stop")

SECTION_SEPARATOR = "=================================================="

# A stack is a list of (address, nth_occurrence) tuples.
# `address` is a PC value, as a hex string, e.g. "0x00f24710".
# `nth_occurrence` is the number of times `address` was reached since the start of execution.
# Therefore, assuming deterministic runtime, an arbitrary program state can be reached
# by setting a breakpoint at `address` and continuing `nth_occurrence` times.
Stack = list[tuple[str, int]]


class Renode:
    """A class for communicating with a remote instance of Renode."""
    def __init__(self, binary: str):
        """Spawns a new instance of Renode."""
        print(f"* Starting Renode instance")
        try:
            self.proc = pexpect.spawn(f"{binary} --disable-gui --console --plain", timeout=20)
            self.proc.stripcr = True
            self.proc.expect('(monitor)')
        except pexpect.exceptions.EOF as err:
            print("!!! Renode failed to start! (is --renode-path correct?)")
            raise err
        # Sometimes first command does not work, hence we send this dummy one to make sure we got functional connection right after initialization
        self.command("echo 'Connected to GDB comparator'")

    def close(self) -> None:
        """Closes the underlying Renode instance."""
        self.command("quit", expected_log="Disposed")

    def command(self, input: str, expected_log: str = "") -> None:
        """Sends an arbitrary command to the underlying Renode instance."""
        if not self.proc.isalive():
            print("!!! Renode has died!")
            print("Process:")
            print(str(self.proc))
            raise RuntimeError

        self.proc.sendline(input.encode())
        if expected_log != "":
            try:
                self.proc.expect([expected_log.encode()])
            except pexpect.TIMEOUT as err:
                print(SECTION_SEPARATOR)
                print(f"Renode command '{input.strip()}' failed!")
                print(f"Expected regex '{expected_log}' was not found")
                print("Process:")
                print(str(self.proc))
                print(SECTION_SEPARATOR)
                print(f"{err=} ; {type(err)=}")
                exit(1)


class GDBInstance:
    """A class for controlling a remote GDB instance."""
    def __init__(self, gdb_binary: str, port: int, debug_binary: str, name: str, target_process: pexpect.spawn):
        """Spawns a new GDB instance and connects to it."""
        self.dimensions = (0, 4096)
        self.name = name
        self.last_cmd = ""
        self.last_output = ""
        self.task: Awaitable[Any]
        self.target_process = target_process
        print(f"* Connecting {self.name} GDB instance to target on port {port}")
        self.process = pexpect.spawn(f"{gdb_binary} --silent --nx --nh", timeout=10, dimensions=self.dimensions)
        self.process.timeout = 120
        self.run_command("clear", async_=False)
        self.run_command("set pagination off", async_=False)
        self.run_command(f"file {debug_binary}", async_=False)
        self.run_command(f"target remote :{port}", async_=False)

    def close(self) -> None:
        """Closes the underlying GDB instance."""
        self.run_command("quit", dont_wait_for_output=True, async_=False)

    def progress_by(self, delta: int, type: str = "stepi") -> None:
        """Steps `delta` times."""
        adjusted_timeout = max(1200, int(delta) / 5)
        self.run_command(type + (f" {delta}" if int(delta) > 1 else ""), timeout=adjusted_timeout)

    def get_symbol_at(self, addr: str) -> str:
        """Returns the name of the symbol which is stored at `addr` (`info symbol`)."""
        self.run_command(f"info symbol {addr}", async_=False)
        return self.last_output.splitlines()[-1]

    def delete_breakpoints(self) -> None:
        """Deletes all breakpoints."""
        self.run_command("clear", async_=False)

    def run_command(self, command: str, timeout: float = 100, confirm: bool = False, dont_wait_for_output: bool = False, async_: bool = True) -> None:
        """Send an arbitrary command to the underlying GDB instance."""
        if not self.process.isalive():
            print(f"!!! The {self.name} GDB process has died!")
            print("Process:")
            print(str(self.process))
            self.last_output = ""
            raise RuntimeError
        if not self.target_process.isalive():
            print(f"!!! {self.name} GDB's target has died!")
            print("Target process:")
            print(str(self.target_process))
            self.last_output = ""
            raise RuntimeError

        self.last_cmd = command
        self.process.write(command + "\n")
        if dont_wait_for_output:
            return
        try:
            if not confirm:
                result = self.process.expect(re.escape(command) + r".+\n", timeout, async_=async_)
                self.task = result if async_ else None
                if not async_:
                    self.last_output = ""
                    line = self.process.match[0].decode().strip("\r")
                    while "(gdb)" not in line:
                        self.last_output += line
                        self.process.expect([r".+\n", r"\(gdb\)"], timeout)
                        line = self.process.match[0].decode().strip("\r")
                    self.validate_response(self.last_output)
            else:
                self.process.expect("[(]y or n[)]")
                self.process.writelines("y")
                result = self.process.expect("[(]gdb[)]", async_=async_)
                self.task = result if async_ else None
                self.last_output = self.process.match[0].decode().strip("\r")

        except pexpect.TIMEOUT as err:
            print(f"!!! {self.name} GDB: Command '{command}' timed out!")
            print("Process:")
            print(str(self.process))
            self.last_output = ""
            raise err
        except pexpect.exceptions.EOF as err:
            print(f"!!! {self.name} GDB: pexpect encountered an unexpected EOF (is --gdb-path correct?)")
            print("Process:")
            print(str(self.process))
            self.last_output = ""
            raise err

    def print_stack(self, stack: Stack) -> None:
        """Prints a stack."""
        print("Address\t\tOccurrence\t\tSymbol")
        for address, occurrence in stack:
            print(f"{address}\t{occurrence}\t{self.get_symbol_at(address)}")

    def validate_response(self, response: str) -> None:
        """Scans a GDB response for common error messages."""
        for regex in RE_GDB_ERRORS:
            err_match = regex.search(response)
            if err_match is not None:
                print(f"!!! {self.name} GDB: {err_match[0].strip()} (last command: \"{self.last_cmd}\")")
                # Assuming we correctly identified a GDB error, this would be
                # the right place to terminate execution. However, there is
                # a risk of a false positive, so it's safer not to (if it is
                # a critical error, it will most likely cause a timeout anyway).

    async def get_pc(self) -> str:
        """Returns the value of the PC register, as a hex string."""
        self.run_command("i r pc")
        await self.expect()
        pc_match = RE_HEX.search(self.last_output)
        if pc_match is not None:
            return pc_match[0]
        else:
            raise TypeError

    async def expect(self, timeout: float = 100) -> None:
        """Await execution of the last command to finish and update `self.last_output`."""
        try:
            await self.task
            line = self.process.match[0].decode().strip("\r")
            self.last_output = ""
            while "(gdb)" not in line:
                self.last_output += line
                self.task = self.process.expect([r".+\n", r"\(gdb\)"], timeout, async_=True)
                await self.task
                line = self.process.match[0].decode().strip("\r")
            self.validate_response(self.last_output)

        except pexpect.TIMEOUT as err:
            print(f"!!! {self.name} GDB: Command '{self.last_cmd}' timed out!")
            print("Process:")
            print(str(self.process))
            self.last_output = ""
            raise err


class GDBComparator:
    """A helper class to aggregate control over 2 `GDBInstance` objects."""

    COMMAND_NAME = "gdb_compare__print_registers"
    COMMANDS = None

    # REGISTER_CASES is an ordered list of (condition_func, cmd_builder_func) tuples.
    # It is used to assign registers to groups based on their type, and for each such group
    # have a dedicated function that constructs a gdb command to pretty-print those registers.
    # Each tuple in REGISTER_CASES represents a group of registers. condition_func is used to
    # determine whether a register belongs to the group. cmd_builder_func intakes a list of
    # registers belonging to the group and returns a GDB command to print all their values.
    # The order of tuples matters - only the first match is used.
    RegNameTester = Callable[[str], bool]               # condition_func type
    CommandsBuilder = Callable[[list[str]], list[str]]  # cmd_builder_func type
    REGISTER_CASES: list[tuple[RegNameTester, CommandsBuilder]] = [
        (lambda reg: RE_VEC_REGNAME.fullmatch(reg) is not None, lambda regs: [f"p/x (char[])${reg}.b" for reg in regs]),
        # From `info gdb Arrays` (GDB docs, 10.4 Artificial Arrays):
        #   > Another way to create an artificial array is to use a cast.  This
        #   > re-interprets a value as if it were an array.  The value need not be in
        #   > memory:
        #   >      (gdb) p/x (short[2])0x12345678
        #   >      $1 = {0x1234, 0x5678}
        #   >
        #   > As a convenience, if you leave the array length out (as in
        #   > '(TYPE[])VALUE') GDB calculates the size to fill the value (as
        #   > 'sizeof(VALUE)/sizeof(TYPE)':
        #   >      (gdb) p/x (short[])0x12345678
        #   >      $2 = {0x1234, 0x5678}
        # This means we don't have to special-case registers if we're comparing their
        # raw bytes, as `p/x (char[])$reg` will print the full value of the register as
        # a byte (char) array - this also works with vector registers.
        # This is what this fallback does - prints the whole register as a byte array.
        (lambda _: True, lambda regs: [f"p/x (char[])${reg}" for reg in regs]),
    ]

    def __init__(self, args: argparse.Namespace, renode_proc: pexpect.spawn, ref_proc: pexpect.spawn):
        """Creates 2 `GDBInstance` objects, one expecting to connect on port `args.renode_gdb_port` and the other on `args.reference_gdb_port`."""
        self.instances = [
            GDBInstance(args.gdb_path, args.renode_gdb_port, args.debug_binary, "Renode", renode_proc),
            GDBInstance(args.gdb_path, args.reference_gdb_port, args.debug_binary, "Reference", ref_proc),
        ]
        self.cmd = args.command if args.command else self.build_command_from_register_list(args.registers.split(";"))

    def close(self) -> None:
        """Closes all owned instances."""
        for i in self.instances:
            i.close()

    def build_command_from_register_list(self, regs: list[str]) -> str:
        """Defines a custom gdb command for pretty-printing all registers and returns its name."""
        if GDBComparator.COMMANDS is None:
            # Assign registers to groups based on the RegNameTester functions
            reg_groups: dict[GDBComparator.CommandsBuilder, list[str]] = {}
            for reg in regs:
                for test, cmds_builder in GDBComparator.REGISTER_CASES:
                    if test(reg):
                        reg_groups.setdefault(cmds_builder, []).append(reg)
                        break

            # Compose a gdb script that defines a custom command for printing all groups of registers
            GDBComparator.COMMANDS = [
                f"define {GDBComparator.COMMAND_NAME}",
                *[cmd for cmds_builder, reg_group in reg_groups.items() for cmd in cmds_builder(reg_group)],
                "end"
            ]

            # Warn if for any GDBInstance there is a register that was requested by the user
            # but does not appear in the output of "info registers all"
            for i in self.instances:
                i.run_command("i r all", async_=False)
                reported_regs = list(map(lambda x: x.split()[0], i.last_output.split("\n")[1:-1]))
                not_found = list(filter(lambda reg: reg not in reported_regs, regs))
                if not_found:
                    print("WARNING: " + ", ".join(not_found) + " register[s] not found when executing 'info registers all' for " + i.name)

        # Define the custom command
        commands = GDBComparator.COMMANDS
        for i in self.instances:
            for cmd in commands[:-1]:
                i.run_command(cmd, dont_wait_for_output=True, async_=False)
            i.run_command(commands[-1], async_=False)

        return GDBComparator.COMMAND_NAME

    def delete_breakpoints(self) -> None:
        """Deletes all breakpoints in all owned instances."""
        for i in self.instances:
            i.delete_breakpoints()

    def get_symbol_at(self, addr: str) -> str:
        """Returns the name of the symbol which is stored at `addr` (`info symbol`)."""
        return self.instances[0].get_symbol_at(addr)

    def print_stack(self, stack: Stack) -> None:
        """Prints a stack."""
        return self.instances[0].print_stack(stack)

    async def run_command(self, cmd: Optional[str] = None, **kwargs: Any) -> list[str]:
        """Sends an arbitrary command to all owned instances and returns a list of outputs."""
        cmd = cmd if cmd else self.cmd
        for i in self.instances:
            i.run_command(cmd, **kwargs)
        await asyncio.gather(*[i.expect(**kwargs) for i in self.instances])
        return [i.last_output for i in self.instances]

    async def get_pcs(self) -> list[str]:
        """Returns a list containing the values of PC registers of all owned instances, as hex strings."""
        return await asyncio.gather(*[i.get_pc() for i in self.instances])

    async def progress_by(self, delta: int, type: str = "stepi") -> None:
        """Steps `delta` times in all owned instances."""
        adjusted_timeout = max(1200, int(delta) / 5)
        await self.run_command(type + (f" {delta}" if int(delta) > 1 else ""), timeout=adjusted_timeout)

    async def compare_instances(self, previous_pc: str) -> None:
        """Compares the execution states of all owned instances. `previous_pc` must refer to the previous value of PC; it does not offer a choice."""
        for name, command in [("Opcode at previous pc", f"x/i {previous_pc}"), ("Frame", "frame"), ("Registers", "info registers all")]:
            print("*** " + name + ":")
            GDBComparator.compare_outputs(await self.run_command(command))

    @staticmethod
    def compare_outputs(outputs: list[str]) -> None:
        """Prints a comparison of two output strings (same & different values)."""
        assert len(outputs) == 2
        output1_dict: dict[str, str] = {}
        output2_dict: dict[str, str] = {}

        # Truncate 1st elements in outputs, because it's the repl
        for output, output_dict in zip([x.split("\n")[1:] for x in outputs], [output1_dict, output2_dict]):
            for x in output:
                end_of_name = x.strip().find(" ")
                name = x[:end_of_name].strip()
                rest = x[end_of_name:].strip()
                output_dict[name] = rest

        output_same = ""
        output_different = ""

        for name in output1_dict.keys():
            if name in output2_dict:
                if name == "":
                    continue
                if output1_dict[name] != output2_dict[name]:
                    output_different += f">> {name}:\n"
                    output_different += string_compare(output1_dict[name], output2_dict[name]) + "\n"
                else:
                    output_same += f">> {name}:\t{output1_dict[name]}\n"

        if len(output_different) == 0:
            print("Same:")
            print(output_same)
        else:
            print("Same values:")
            print(output_same)
            print("Different values:")
            print(output_different)


def setup_processes(args: argparse.Namespace) -> tuple[Renode, pexpect.spawn, GDBComparator]:
    """Spawns Renode, the reference process, `GDBComparator` and returns their handles (in that order)."""
    reference = pexpect.spawn(args.reference_command, timeout=10)
    renode = Renode(args.renode_path)
    renode.command("include @" + path.abspath(args.renode_script), expected_log="System bus created")
    renode.command(f"machine StartGdbServer {args.renode_gdb_port}", expected_log=f"started on port :{args.renode_gdb_port}")
    gdb_comparator = GDBComparator(args, renode.proc, reference)
    renode.command("start")
    return renode, reference, gdb_comparator

def string_compare(renode_string: str, reference_string: str) -> str:
    """Returns a pretty diff of two single-line strings."""
    BOLD = "\033[1m"
    END = "\033[0m"
    RED = "\033[91m"
    GREEN = "\033[92m"

    renode_string = re.sub(r"\x1b\[[0-9]*m", "", renode_string)
    reference_string = re.sub(r"\x1b\[[0-9]*m", "", reference_string)

    assert len(RED) == len(GREEN)
    formatting_length = len(BOLD + RED + END)

    s1_insertions = 0
    s2_insertions = 0
    diff = difflib.SequenceMatcher(None, renode_string, reference_string)

    for type, s1_start, s1_end, s2_start, s2_end in diff.get_opcodes():
        if type == "equal":
            continue
        elif type == "replace":
            s1_start += s1_insertions * formatting_length
            s1_end += s1_insertions * formatting_length
            s2_end += s2_insertions * formatting_length
            s2_start += s2_insertions * formatting_length
            renode_string = renode_string[:s1_start] + GREEN + BOLD + renode_string[s1_start:s1_end] + END + renode_string[s1_end:]
            reference_string = reference_string[:s2_start] + RED + BOLD + reference_string[s2_start:s2_end] + END + reference_string[s2_end:]
            s1_insertions += 1
            s2_insertions += 1
        elif type == "insert":
            s2_end += s2_insertions * (len(BOLD) + len(RED) + len(END))
            s2_start += s2_insertions * (len(BOLD) + len(RED) + len(END))
            reference_string = reference_string[:s2_start] + RED + BOLD + \
                reference_string[s2_start:s2_end] + END + reference_string[s2_end:]
            s2_insertions += 1
        elif type == "delete":
            s1_end += s1_insertions * (len(BOLD) + len(GREEN) + len(END))
            s1_start += s1_insertions * (len(BOLD) + len(GREEN) + len(END))
            renode_string = renode_string[:s1_start] + GREEN + BOLD + \
                renode_string[s1_start:s1_end] + END + renode_string[s1_end:]
            s1_insertions += 1
    return f"Renode:    {renode_string}\nReference: {reference_string}"


class CheckStatus:
    """This class serves as an enum for possible outcomes of the `check` function."""
    STOP = 1
    CONTINUE = 2
    FOUND = 3
    MISMATCH = 4


async def check(stack: Stack, gdb_comparator: GDBComparator, previous_pc: str, previous_output: str, steps_count: int, exec_count: dict[str, int], time_of_start: float, args: argparse.Namespace) -> tuple[str, str, int]:
    """Executes the next `gdb_comparator` instruction, compares the outputs and returns the new PC value, output and `CheckStatus`."""
    ren_pc, pc = await gdb_comparator.get_pcs()
    pc_mismatch = False
    if pc != ren_pc:
        print("Renode and reference PC differs!")
        print(string_compare(ren_pc, pc))
        print(f"\tPrevious PC: {previous_pc}")
        pc_mismatch = True
    if pc not in exec_count:
        exec_count[pc] = 0
    exec_count[pc] += 1

    if args.stop_address and int(ren_pc, 16) == args.stop_address:
        print("stop address reached")
        return previous_pc, previous_output, CheckStatus.STOP

    if not pc_mismatch:
        output_ren, output_reference = map(lambda s: s.splitlines(), await gdb_comparator.run_command())

        for line in range(len(output_ren)):
            if output_ren[line] != output_reference[line]:
                print(SECTION_SEPARATOR)
                print(f"!!! Difference in line {line + 1} of output:")
                print(string_compare(output_ren[line], output_reference[line]))
                print(f"Previous:  {previous_output}")
                break
        else:
            if steps_count % 10 == 0:
                print(f"{steps_count} steps; current pc = {pc} {gdb_comparator.get_symbol_at(pc)}")
            previous_pc = pc
            previous_output = "\n".join(output_ren[1:])
            return previous_pc, previous_output, CheckStatus.CONTINUE

    if pc_mismatch or (len(stack) > 0 and previous_pc == stack[-1][0]):
        print(SECTION_SEPARATOR)
        print("Found faulting insn at " + previous_pc + " " + gdb_comparator.get_symbol_at(previous_pc))
        elapsed_time = time() - time_of_start
        print(f"Took {elapsed_time:.2f} seconds [~ {elapsed_time/steps_count:.2f} steps/sec]")
        print(SECTION_SEPARATOR)
        print("*** Stack:")
        gdb_comparator.print_stack(stack)
        print("*** Gdb command:")
        print(args.command)
        print(SECTION_SEPARATOR)
        print("Gdb instances comparision:")
        await gdb_comparator.compare_instances(previous_pc)

        return previous_pc, previous_output, CheckStatus.FOUND

    if previous_pc not in exec_count:
        previous_pc = pc
    print("Found point after which state is different. Adding to `stack` for later iterations")
    occurrence = exec_count[previous_pc]
    print(f"\tAddress: {previous_pc}\n\tOccurrence: {occurrence}")
    stack.append((previous_pc, occurrence))
    exec_count = {}
    print(SECTION_SEPARATOR)

    return previous_pc, previous_output, CheckStatus.MISMATCH

async def main() -> None:
    """Script entry point."""
    args = parser.parse_args()
    assert 0 <= args.reference_gdb_port <= 65535, "Illegal reference GDB port"
    assert 0 <= args.renode_gdb_port <= 65535, "Illegal Renode GDB port"
    if args.stop_address:
        args.stop_address = int(args.stop_address, 16)

    pcs = [args.stop_address] if args.stop_address else []
    if args.ips:
        pcs += [pc for pc in args.ips.split(";")]

    execution_cmd = "continue" if args.ips else "nexti"
    print(SECTION_SEPARATOR)
    time_of_start = time()
    previous_pc = "Unknown"
    previous_output = "Unknown"
    steps_count = 0
    iterations_count = 0
    stack = []

    if args.start_frame is not None:
        jumps = args.start_frame.split(";")
        for jump in jumps:
            addr, occur = jump.split(",")
            address = addr.strip()
            occurrence = int(occur.strip())
            stack.append((address, occurrence))

    insn_found = False

    while not insn_found:
        iterations_count += 1
        print("Preparing processes for iteration number " + str(iterations_count))
        renode, reference, gdb_comparator = setup_processes(args)
        if len(stack) != 0:
            print("Recreating stack; jumping to breakpoint at:")
            for address, count in stack:
                print("\t" + address + ", " + str(count) + " occurrence")
                await gdb_comparator.run_command(f"break *{address}")

                for _ in range(count):
                    await gdb_comparator.run_command("continue", timeout=120)

                gdb_comparator.delete_breakpoints()
            print("Stepping single instruction")
            await gdb_comparator.progress_by(1)

        for pc in pcs:
            await gdb_comparator.run_command(f"br *{pc}")

        exec_count: dict[str, int] = {}
        print("Starting execution")
        while True:
            await gdb_comparator.run_command(execution_cmd)
            steps_count += 1

            previous_pc, previous_output, status = await check(stack, gdb_comparator, previous_pc, previous_output, steps_count, exec_count, time_of_start, args)

            if status == CheckStatus.CONTINUE and execution_cmd == "continue":
                await gdb_comparator.run_command("stepi")
                steps_count += 1

                previous_pc, previous_output, status = await check(stack, gdb_comparator, previous_pc, previous_output, steps_count, exec_count, time_of_start, args)

            if status == CheckStatus.STOP:
                return
            elif status == CheckStatus.CONTINUE:
                continue
            elif status == CheckStatus.FOUND:
                insn_found = True
                break
            elif status == CheckStatus.MISMATCH:
                execution_cmd = "nexti"
                gdb_comparator.close()
                renode.close()
                reference.close(force=True)
                break
            else:
                exit(1)

if __name__ == "__main__":
    asyncio.run(main())
    exit(0)
