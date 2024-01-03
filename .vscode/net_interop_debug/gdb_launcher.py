#! /usr/bin/env python3

import sys
import os
import asyncio
from gdb_common import *


class TrapsFilter:
    latest_trap = None

    async def async_filter(self, input_stream, output_stream):
        while not input_stream.at_eof():
            line = await input_stream.readline()
            self.filter(line, output_stream.buffer)
            output_stream.flush()

    def filter(self, line, output):
        if DONT_IGNORE_LATEST_TRAP.is_valid(line.decode()):
            output.write(self.latest_trap)
        else:
            if line.startswith(b"*stopped"):
                self.latest_trap = line
            else:
                output.write(line)


async def run_commmand_with_filter(command, filter):
    process = await asyncio.create_subprocess_exec(
        *command, limit=512*1024, stdout=asyncio.subprocess.PIPE
    )
    await asyncio.gather(filter.async_filter(process.stdout, sys.stdout))
    await process.communicate()


def main():
    # Add the directory to allow imports in scripts that run in GDB.
    os.environ["PYTHONPATH"] = os.path.dirname(__file__)

    # The miDebuggerArgs contains an argument with GDB that will be launched.
    # The agrument are passed to script as the second one.
    args = [sys.argv[2], sys.argv[1], *sys.argv[3:]]
    asyncio.run(run_commmand_with_filter(args, TrapsFilter()))


if __name__ == "__main__":
    main()
