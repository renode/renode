#!/usr/bin/env python3
import asyncio
import argparse
import pexpect
import psutil
import re
import telnetlib
import difflib
from time import time
from os import path
from multiprocessing import Process

RENODE_GDB_PORT = 2222
RENODE_TELNET_PORT = 12348
RE_HEX = re.compile(r'0x[0-9A-Fa-f]+')
RE_VEC = re.compile(r'v\d+')

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
                    help="Sequence of register names to compare. Formated as ';' spearated list of register names. Eg. 'pc;ra'")

parser.add_argument("-r",
                    "--reference-command",
                    dest="reference_command",
                    action="store",
                    required=True,
                    help="Command used to run the GDB server provider used as a reference")
parser.add_argument("-s",
                    "--renode-script",
                    dest="renode_script",
                    action="store",
                    required=True,
                    help="Path to the '.resc' script")
parser.add_argument("-p", "--reference-gdb-port",
                    dest="reference_gdb_port",
                    action="store",
                    required=True,
                    help="Port on which the reference GDB server can be reached")
parser.add_argument("--renode-gdb-port",
                    dest="renode_gdb_port",
                    action="store",
                    default=RENODE_GDB_PORT,
                    help="Port on which Renode will comunicate with GDB server")
parser.add_argument("-P", "--renode-telnet-port",
                    dest="renode_telnet_port",
                    action="store",
                    default=RENODE_TELNET_PORT,
                    help="Port on which Renode will comunicate with telnet")
parser.add_argument("-b", "--binary",
                    dest="debug_binary",
                    action="store",
                    required=True,
                    help="Path to ELF file with symbols")
parser.add_argument("-x",
                    "--renode-path",
                    dest="renode_path",
                    action="store",
                    default="renode",
                    help="Path to the Renode runscript")
parser.add_argument("-g",
                    "--gdb-path",
                    dest="gdb_path",
                    action="store",
                    default="/usr/bin/gdb",
                    help="Path to the GDB binary to be run")
parser.add_argument("-f", "--start-frame",
                    dest="start_frame",
                    action="store",
                    default=None,
                    help="Sequence of jumps to reach target frame. Formated as 'addr, occurence', separated with ';'. Eg. '_start,1;printf,7'")
parser.add_argument("-i", "--interest-points",
                    dest="ips",
                    action="store",
                    default=None,
                    help="Sequence of address, interest points, after which state will be compared. Formated as ';' spearated list of hexadecimal addresses. Eg. '0x8000;0x340eba3c'")
parser.add_argument("-S", "--stop-address",
                    dest="stop_address",
                    action="store",
                    default=None,
                    help="Stop condition, if reached script will stop")

SECTION_SEPARATOR = "=================================================="


class Renode:
    def __init__(self, binary, port):
        print(f"* Starting Renode instance on telnet port {port}")
        # making sure there is only one instance of Renode on this port
        for p in psutil.process_iter():
            process_name = p.name().casefold()
            if "renode" in process_name and str(port) in process_name:
                print("!!! Found another instance of Renode running on the same port. Killing it before proceeding")
                p.kill()
        self.proc = pexpect.spawn(f"{binary} --disable-xwt --plain --port {port}", timeout=20)
        self.proc.stripcr = True
        self.proc.expect("Monitor available in telnet mode on port")
        self.connection = telnetlib.Telnet("localhost", port)
        # Sometimes first command does not work, hence we send this dummy one to make sure we got functional connection right after initialization
        self.command("echo 'Connected to GDB comparer'")

    def close(self):
        self.command("quit", expected_log="Disposed")

    def command(self, input, expected_log=""):
        input = input + "\n"
        self.connection.write(input.encode())
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

    def get_output(self):
        return self.connection.read_all()


class GDBInstance:
    def __init__(self, gdb_binary, port, debug_binary, name):
        self.name = name
        self.last_output = ""
        print(f"* Connecting {self.name} GDB instance to target on port {port}")
        self.process = pexpect.spawn(f"{gdb_binary} --silent --nx --nh", timeout=10)
        self.process.timeout = 120
        self.run_command("clear", async_=False)
        self.run_command("set pagination off", async_=False)
        self.run_command(f"file {debug_binary}", async_=False)
        self.run_command(f"target remote :{port}", async_=False)

    def close(self):
        self.run_command("quit", dont_wait_for_output=True, async_=False)

    def progress_by(self, delta, type="stepi"):
        adjusted_timeout = max(120, int(delta)/5)
        self.run_command(type + (f" {delta}" if int(delta) > 1 else ""), timeout=adjusted_timeout)

    def get_symbol_at(self, addr):
        self.run_command(f"info symbol {addr}", async_=False)
        return self.last_output.splitlines()[-1]

    def delete_breakpoints(self):
        self.run_command("clear", async_=False)

    async def get_pc(self):
        self.run_command("i r pc")
        await self.expect()
        pc_match = RE_HEX.search(self.last_output)
        if pc_match is not None:
            return pc_match[0]
        else:
            raise TypeError

    async def expect(self, timeout=10):
        await self.task
        line = self.process.match[0].decode().strip("\r")
        self.last_output = ""
        while "(gdb)" not in line:
            self.last_output += line
            self.task = self.process.expect([r".+\n", r"\(gdb\)"], timeout, async_=True)
            await self.task
            line = self.process.match[0].decode().strip("\r")

    def run_command(self, command, timeout=10, confirm=False, dont_wait_for_output=False, async_=True):
        self.process.write(command + "\n")
        if dont_wait_for_output:
            return
        try:
            # Escape regex special characters
            command = command.replace("$", "\\$").replace("+", "\\+").replace("*", "\\*")
            if not confirm:
                self.task = self.process.expect(command + r".+\n", timeout, async_=async_)
                if not async_:
                    self.last_output = ""
                    line = self.process.match[0].decode().strip("\r")
                    while "(gdb)" not in line:
                        self.last_output += line
                        self.process.expect([r".+\n", r"\(gdb\)"], timeout)
                        line = self.process.match[0].decode().strip("\r")
            else:
                self.process.expect("[(]y or n[)]")
                self.process.writelines("y")
                self.task = self.process.expect("[(]gdb[)]", async_=async_)
                self.last_output = self.process.match[0].decode().strip("\r")

        except pexpect.TIMEOUT:
            print(f"!!! {self.name} GDB: Command '{command}' timed out!")
            print("Process:")
            print(str(self.process))
            self.last_output = None
            raise pexpect.TIMEOUT("")

    def print_state(self, previous_pc):
        for cmd in [f"x/i {previous_pc}", f"x/x {previous_pc}", "frame", "info all-registers"]:
            self.run_command(cmd, async_=False)
            print(">> " + self.last_output)

    def print_stack(self, stack):
        print("Address\t\tOccurence\t\tSymbol")
        for address, occurence in stack:
            print(f"{address}\t{occurence}\t{self.get_symbol_at(address)}")


class GDBComparator:
    COMMAND_NAME = "gdb_compare__print_registers"
    COMMANDS = None

    # [(tester of register name, commands builder for register group)]
    # List<Tuple<str -> bool, List<str> -> List<str>>>
    REGISTER_CASES = [
        (lambda reg: RE_VEC.fullmatch(reg), lambda regs:[f"p/x (char[])${reg}.b" for reg in regs]),
        (lambda _: True, lambda regs: ["printf \"" + ":  0x%x\\n".join(regs) + ":  0x%x\\n\",$" + ",$".join(regs)]),
    ]

    def __init__(self, args):
        self.instances = [
            GDBInstance(args.gdb_path, args.renode_gdb_port, args.debug_binary, "Renode"),
            GDBInstance(args.gdb_path, args.reference_gdb_port, args.debug_binary, "Reference"),
        ]
        self.cmd = args.command if args.command else self.build_command_from_register_list(args.registers)

    def close(self):
        for i in self.instances:
            i.close()

    def build_command_from_register_list(self, regs):
        regs = regs.split(';')
        if GDBComparator.COMMANDS is None:
            reg_groups = {}
            for reg in regs:
                for (test, cmds_builder) in GDBComparator.REGISTER_CASES:
                    if test(reg):
                        reg_groups.setdefault(cmds_builder, []).append(reg)
                        break
            GDBComparator.COMMANDS = [
                f"define {GDBComparator.COMMAND_NAME}",
                *[cmd for cmds_builder, reg_group in reg_groups.items() for cmd in cmds_builder(reg_group)],
                "end"
            ]

            for i in self.instances:
                i.run_command("i r all", async_=False)
                reported_regs = list(map(lambda x: x.split()[0], i.last_output.split("\n")[1:-1]))
                not_found = list(filter(lambda reg: not reg in reported_regs, regs))
                if not_found:
                    print("WARNING: " + ", ".join(not_found) + " register[s] not found when executing 'info registers all' for " + i.name)
        commands = GDBComparator.COMMANDS

        for i in self.instances:
            for cmd in commands[:-1]:
                i.run_command(cmd, dont_wait_for_output=True, async_=False)
            i.run_command(commands[-1], async_=False)

        return GDBComparator.COMMAND_NAME

    async def run_command(self, cmd=None, **kwargs):
        cmd = cmd if cmd else self.cmd
        for i in self.instances:
            i.run_command(cmd, **kwargs)
        await asyncio.gather(*[i.expect(**kwargs) for i in self.instances])
        return [i.last_output for i in self.instances]

    async def get_pcs(self):
        return await asyncio.gather(*[i.get_pc() for i in self.instances])

    def delete_breakpoints(self):
        for i in self.instances:
            i.delete_breakpoints()

    async def progress_by(self, delta, type="stepi"):
        adjusted_timeout = max(120, int(delta)/5)
        await self.run_command(type + (f" {delta}" if int(delta) > 1 else ""), timeout=adjusted_timeout)

    async def compare_instances(self, previous_pc):
        for name, command in [("Opcode at previous pc", f"x/i {previous_pc}"), ("Frame", "frame"), ("Registers", "info registers all")]:
            print("*** " + name + ":")
            GDBComparator.compare_outputs(await self.run_command(command))

    @staticmethod
    def compare_outputs(outputs):
        assert(len(outputs) == 2)
        output1_dict = {}
        output2_dict = {}

        for (output, output_dict) in zip(outputs,[output1_dict, output2_dict]):
            # Drop command repl
            output = output.split("\n")[1:]
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

    def get_symbol_at(self, addr):
        return self.instances[0].get_symbol_at(addr)

    def print_stack(self, stack):
        return self.instances[0].print_stack(stack)


def setup_processes(args):
    reference = pexpect.spawn(args.reference_command, timeout=10)
    renode = Renode(args.renode_path, args.renode_telnet_port)
    renode.command("include @" + path.abspath(args.renode_script), expected_log="System bus created")
    renode.command(f"machine StartGdbServer {args.renode_gdb_port}", expected_log=f"started on port :{args.renode_gdb_port}")
    gdb_comparator = GDBComparator(args)
    renode.command("start")
    return renode, reference, gdb_comparator

def string_compare(renode_string, reference_string):
    BOLD = '\033[1m'
    END = '\033[0m'
    RED = '\033[91m'
    GREEN = '\033[92m'

    renode_string = re.sub(r"\x1b\[[0-9]*m", "", renode_string)
    reference_string = re.sub(r"\x1b\[[0-9]*m", "", reference_string)

    assert(len(RED) == len(GREEN))
    formatting_length = len(BOLD+RED+END)

    s1_insertions = 0
    s2_insertions = 0
    diff = difflib.SequenceMatcher(None, renode_string, reference_string)

    for type, s1_start, s1_end, s2_start, s2_end in diff.get_opcodes():
        if type == 'equal':
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
    STOP = 1
    CONTINUE = 2
    FOUND = 3
    MISMATCH = 4


async def check(stack, gdb_comparator, previous_pc, previous_output, steps_count, exec_count, time_of_start, args):
    ren_pc, pc = await gdb_comparator.get_pcs()
    pc_mismatch = False
    if pc != ren_pc:
        print("Renode and reference PC differs!")
        print(string_compare(ren_pc, pc))
        print(f"\tPrevious PC: {previous_pc}")
        pc_mismatch = True
    if pc in exec_count:
        exec_count[pc] += 1
    else:
        exec_count[pc] = 1

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

    if not previous_pc in exec_count:
        previous_pc = pc
    print("Found point after which state is different. Adding to `stack` for later iterations")
    occurence = exec_count[previous_pc]
    print(f"\tAddress: {previous_pc}\n\tOccurence: {occurence}")
    stack.append((previous_pc, occurence))
    exec_count = {}
    print(SECTION_SEPARATOR)

    return previous_pc, previous_output, CheckStatus.MISMATCH

async def main():
    args = parser.parse_args()
    if args.stop_address:
        args.stop_address = int(args.stop_address, 16)

    pcs = [ args.stop_address ] if args.stop_address else []
    if args.ips:
        pcs += [ pc for pc in args.ips.split(';') ]

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
            addr, occur = jump.split(',')
            address = addr.strip()
            occurence = int(occur.strip())
            stack.append((address, occurence))

    insn_found = False

    while not insn_found:
        iterations_count += 1
        print("Preparing processes for iteration number " + str(iterations_count))
        renode, reference, gdb_comparator = setup_processes(args)
        if len(stack) != 0:
            print("Recreating stack; jumping to breakpoint at:")
            for address, count in stack:
                print("\t" + address + ", " + str(count) +" occurence" )
                await gdb_comparator.run_command(f"break *{address}")

                for _ in range(count):
                    await gdb_comparator.run_command("continue", timeout=120)

                gdb_comparator.delete_breakpoints()
            print("Stepping single instruction")
            await gdb_comparator.progress_by(1)

        for pc in pcs:
            await gdb_comparator.run_command(f"br *{pc}")

        exec_count = {}
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
