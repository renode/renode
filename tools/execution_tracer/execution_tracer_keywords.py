#!/usr/bin/env python3
#
# Copyright (c) 2010-2026 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import re
from itertools import islice
from typing import List

from execution_tracer.execution_tracer_reader import find_llvm_disas, read_file


def parse_binary_trace(
    path: str,
    disassemble: bool = True,
) -> List[str]:
    """Return the entries of the binary trace file at `path` as formatted lines.

    With `disassemble`, each line also shows the disassembled instruction.
    """
    llvm_disas_path = None
    if disassemble:
        llvm_disas_path = find_llvm_disas()

    entries = []
    with open(path, "rb") as file:
        trace_data = read_file(file, disassemble, llvm_disas_path)
        entries = [trace_data.format_entry(entry) for entry in trace_data]

    return entries

# Used in execution_tracer_reader.robot
# It takes the path of a trace with millions of lines. Passing the lines through Robot instead
# would make Robot log all of them at the TRACE log level, which takes gigabytes of memory.
# This is the hot path for checking symbol lookup
# By keeping it on python side a 10x speedup was observed
def validate_symbol_lookup_slice(trace_path: str, slice_start: int, slice_end: int, line_regex_pattern: str, function_rules: dict[str, tuple[int, int]] ):
    """Check the resolved symbols in lines `[slice_start:slice_end]` of the trace file at `trace_path`.

    Each line must match `line_regex_pattern`, whose three groups capture the address, the opcode
    and the symbol. When the address is in the `[low_pc, high_pc)` range of a `function_rules`
    entry, the symbol must match the regex of that entry.
    """
    compiled_line_regex = re.compile(line_regex_pattern)

    compiled_rules = [
    (re.compile(regex_str), int(str(start_hex), 0), int(str(end_hex), 0))
        for regex_str, (start_hex, end_hex) in function_rules.items()
    ]

    with open(trace_path) as file:
        for line in islice(file, int(slice_start), int(slice_end)):
            line = line.rstrip("\n")
            match = compiled_line_regex.match(str(line))
            if not match:
                raise AssertionError(f"Line format error: '{line}' did not match line regex pattern.")

            addr_str, opc, symbol = match.groups()
            addr = int(addr_str, 16)

            for pattern, start_int, end_int in compiled_rules:
                if start_int <= addr < end_int:
                    if not pattern.match(symbol):
                        raise AssertionError(
                            f"Symbol verification failed!\n"
                            f"Address: {hex(addr)}\n"
                            f"Symbol: '{symbol}'\n"
                            f"Expected pattern: '{pattern.pattern}'"
                        )
                    break
