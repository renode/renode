#!/usr/bin/env python3
import asyncio
import argparse
import pexpect
import psutil
import re
import telnetlib
from time import time
from os import path
from multiprocessing import Process

parser = argparse.ArgumentParser(
    description="Compare Renode execution with hardware/other simulator state using GDB")
parser.add_argument("-r",
                    "--reference-command",
                    dest="reference_command",
                    action="store",
                    required=True,
                    help="Command used to run the GDB server provider used as a reference")
parser.add_argument("-c", "--gdb-command",
                    dest="command",
                    required=True,
                    help="GDB command to run on both instances after each instruction. Outputs of these commands are compared against each other.")
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

SECTION_SEPARATOR = "=================================================="
RENODE_GDB_PORT = 2222
RENODE_TELNET_PORT = 12348
args = parser.parse_args()


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

    def __del__(self):
        self.command("quit", expected_log="Disposed")

    def command(self, input, expected_log=""):
        input = input + "\n"
        self.connection.write(input.encode())
        if expected_log != "":
            try:
                self.proc.expect([expected_log.encode()])
            except pexpect.TIMEOUT as err:
                print(SECTION_SEPARATOR)
                print(f"Renode command '{input}' failed!")
                print(f"Expected regex '{expected_log}' was not found")
                print("Buffer:")
                print(buffer.decode().replace('\\r\\n', '\n'))
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

    def __del__(self):
        self.run_command("quit", dont_wait_for_output=True, async_=False)

    def progress_by(self, delta, type="stepi"):
        adjusted_timeout = max(120, int(delta)/5)
        self.run_command(type + (f" {delta}" if int(delta) > 1 else ""), timeout=adjusted_timeout)

    def get_symbol_at(self, addr):
        self.run_command(f"info symbol {addr}", async_=False)
        return self.output().splitlines()[1]

    def delete_breakpoints(self):
        self.run_command("clear", async_=False)

    def get_pc(self):
        self.run_command("p/x $pc", async_=False)
        pc_match = re.search(r'0x[0-9A-Fa-f]*', self.last_output)
        if pc_match is not None:
            return pc_match[0]
        else:
            raise TypeError

    def output(self):
        self.last_output = self.process.match[0].decode().strip("\r")
        return self.last_output

    def run_command(self, command, timeout=10, confirm=False, dont_wait_for_output=False, async_=True):
        self.process.write(command + "\n")
        if dont_wait_for_output:
            return
        try:
            # Escape regex special characters
            command = command.replace("$", "\\$").replace("+", "\\+").replace("*", "\\*")
            expected_output = command + "(\r?\n.*)+(?=[(]gdb[)])"
            if not confirm:
                self.task = self.process.expect(expected_output, timeout, async_=async_)
            else:
                self.process.expect("[(]y or n[)]")
                self.process.writelines("y")
                self.task = self.process.expect("[(]gdb[)]", async_=async_)
        except pexpect.TIMEOUT:
            print(f"!!! {self.name} GDB: Command '{command}' timed out!")
            print("Buffer:")
            print(self.process.buffer.decode().replace('\\r\\n', '\n'))
            self.last_output = None
            raise pexpect.TIMEOUT("")
            return
        if not async_:
            self.last_output = self.process.match[0].decode().strip("\r")


def setup_processes():
    reference = pexpect.spawn(args.reference_command, timeout=10)
    renode = Renode(args.renode_path, RENODE_TELNET_PORT)
    renode.command("include @" + path.abspath(args.renode_script), expected_log="System bus created")
    renode.command(f"machine StartGdbServer {RENODE_GDB_PORT}", expected_log=f"started on port :{RENODE_GDB_PORT}")
    renode_gdb = GDBInstance(args.gdb_path, RENODE_GDB_PORT, args.debug_binary, "Renode")
    reference_gdb = GDBInstance(args.gdb_path, args.reference_gdb_port, args.debug_binary, "Reference")
    renode.command("logLevel 3")
    renode.command("start")

    return renode, reference, renode_gdb, reference_gdb


def print_state(gdb_instance):
    gdb_instance.run_command(f"x/i {previous_pc}", async_=False)
    print(">> " + gdb_instance.last_output)
    gdb_instance.run_command(f"x/x {previous_pc}", async_=False)
    print(">> " + gdb_instance.last_output)
    gdb_instance.run_command("frame", async_=False)
    print(">> " + gdb_instance.last_output)
    gdb_instance.run_command("info all-registers", async_=False)
    print(">> " + gdb_instance.last_output)

async def main():
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
        renode, reference, renode_gdb, reference_gdb = setup_processes()
        if len(stack) != 0:
            for address, count in stack:
                print("Recreating stack; jumping to breakpoint at " + address + ", " + str(count) +" occurence" )
                renode_gdb.run_command(f"break *{address}")
                reference_gdb.run_command(f"break *{address}")
                await asyncio.gather(renode_gdb.task, reference_gdb.task)

                for _ in range(count):
                    renode_gdb.run_command("continue", timeout=120)
                    reference_gdb.run_command("continue", timeout=120)
                    await asyncio.gather(renode_gdb.task, reference_gdb.task)

                renode_gdb.delete_breakpoints()
                reference_gdb.delete_breakpoints()
            print("Stepping single instruction")
            renode_gdb.progress_by(1, "stepi")
            reference_gdb.progress_by(1, "stepi")
            await asyncio.gather(renode_gdb.task, reference_gdb.task)

        exec_count = {}
        print("Starting stepping")
        while True:
            renode_gdb.progress_by(1, "nexti")
            reference_gdb.progress_by(1, "nexti")
            await asyncio.gather(renode_gdb.task, reference_gdb.task)
            steps_count += 1

            pc = reference_gdb.get_pc()
            ren_pc = renode_gdb.get_pc()
            if pc != ren_pc:
                print("Renode and reference PC differs!")
                print(f"\tRenode PC:   {ren_pc}\tReference PC: {pc}")
                print(f"\tPrevious PC: {previous_pc}")
                break
            if pc in exec_count:
                exec_count[pc] += 1
            else:
                exec_count[pc] = 1

            renode_gdb.run_command(args.command)
            reference_gdb.run_command(args.command)

            await asyncio.gather(renode_gdb.task, reference_gdb.task)

            output_reference = reference_gdb.output().splitlines()
            output_ren = renode_gdb.output().splitlines()

            for line in range(len(output_ren)):
                if output_ren[line] != output_reference[line]:
                    print(SECTION_SEPARATOR)
                    print(f"!!! Difference in line {line + 1} of output:")
                    print(f"\t Renode output:    {output_ren[line]}")
                    print(f"\t Reference output: {output_reference[line]}")
                    break
            else:
                if steps_count % 10 == 0:
                    print(f"{steps_count} steps; current pc = {pc} {reference_gdb.get_symbol_at(pc)}")
                previous_pc = pc
                previous_output = output_ren
                continue

            if len(stack) > 0 and previous_pc == stack[-1][0]:
                print("Found faulting insn at " + previous_pc + " " + reference_gdb.get_symbol_at(previous_pc))
                print(SECTION_SEPARATOR)
                elapsed_time = time() - time_of_start
                print(f"Took {elapsed_time:.2f} seconds [~ {elapsed_time/steps_count:.2f} steps/sec]")
                print(f"Previous step output:\n{previous_output}")
                print(SECTION_SEPARATOR)
                print("Renode state:")
                print_state(renode_gdb)
                print(SECTION_SEPARATOR)
                print("Reference state:")
                print_state(reference_gdb)

                insn_found = True
                break

            print("Found point after which state is different. Adding to `stack` for later iterations")
            occurence = exec_count[previous_pc]
            print(f"\tAddress: {previous_pc}\n\tOccurence: {occurence}")
            stack.append((previous_pc, occurence))
            exec_count = {}
            print(SECTION_SEPARATOR)

            del renode_gdb
            del reference_gdb
            del renode
            del reference
            break

if __name__ == "__main__":
    asyncio.run(main())
    exit(0)