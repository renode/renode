#!/usr/bin/env python3
#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

from typing import List

from execution_tracer.execution_tracer_reader import find_llvm_disas, read_file


def parse_binary_trace(
    path: str,
    disassemble: bool = True,
) -> List[str]:
    llvm_disas_path = None
    if disassemble:
        llvm_disas_path = find_llvm_disas()

    entries = []
    with open(path, "rb") as file:
        trace_data = read_file(file, disassemble, llvm_disas_path)
        entries = [trace_data.format_entry(entry) for entry in trace_data]

    return entries
