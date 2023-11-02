#
# Copyright (c) 2010-2023 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import os
import array
from collections import defaultdict
from elftools.common.utils import bytes2str
from elftools.elf.elffile import ELFFile


class CodeLine:
    def __init__(self, content):
        self.content = content
        self.addresses = []
        self.address_counter = defaultdict(lambda: ExecutionCount())

    def add_address(self, low, high):
        # Try simply merge ranges if they are continuous.
        if len(self.addresses) > 0 and self.addresses[-1][1] == low:
            self.addresses[-1][1] = high
        else:
            self.addresses.append(array.array("Q", [low, high]))

    def count_execution(self, address):
        self.address_counter[address].count_up()
        return self.address_counter[address]

    def most_executions(self):
        if len(self.address_counter) == 0:
            return 0
        return max(count.count for count in self.address_counter.values())


class ExecutionCount:
    def __init__(self):
        self.count = 0

    def count_up(self):
        self.count += 1


def report_coverage(trace_data, elf_file_handler, code_file):
    if not trace_data.has_pc:
        raise ValueError("The trace data doesn't contain PCs.")

    elf_file = ELFFile(elf_file_handler)
    if not elf_file.has_dwarf_info():
        raise ValueError(
            f"The file ({elf_file_handler.name}) doesn't contain DWARF data."
        )
    dwarf_info = elf_file.get_dwarf_info()

    code_filename = os.path.basename(code_file.name)
    code_lines = [CodeLine(line) for line in code_file]

    file_low_address = None
    file_high_address = 0
    for file_name, line_number, address_low, address_high in get_addresses(dwarf_info):
        if file_name != code_filename:
            continue
        if line_number > len(code_lines):
            raise ValueError(
                f"Unexpected line number ({line_number}) in ELF file, file with code contains only {len(code_lines)}"
            )
        code_lines[line_number - 1].add_address(address_low, address_high)
        if file_low_address is None:
            file_low_address = address_low
            file_high_address = address_high
        else:
            file_low_address = min(file_low_address, address_low)
            file_high_address = max(file_high_address, address_high)

    if file_low_address is None:
        return code_lines

    code_lines_with_address = [line for line in code_lines if line.addresses]
    address_count_cache = {}
    for address_bytes, _, _, _ in trace_data:
        if address_bytes in address_count_cache:
            address_count_cache[address_bytes].count_up()
        else:
            address = int.from_bytes(address_bytes, byteorder="little", signed=False)
            if file_low_address <= address < file_high_address:
                for line in code_lines_with_address:
                    if any(
                        address_range[0] <= address < address_range[1]
                        for address_range in line.addresses
                    ):
                        address_count_cache[address_bytes] = line.count_execution(
                            address_bytes
                        )
                        break

    return code_lines


def get_addresses(dwarf_info):
    # Go over all the line programs in the DWARF information, looking for
    # one that describes the given address.
    for CU in dwarf_info.iter_CUs():
        # First, look at line programs to find the file/line for the address
        line_program = dwarf_info.line_program_for_CU(CU)
        delta = 1 if line_program.header.version < 5 else 0
        previous_state = None
        for entry in line_program.get_entries():
            # We're interested in those entries where a new state is assigned
            if entry.state is None:
                continue
            if previous_state:
                filename = bytes2str(
                    line_program["file_entry"][previous_state.file - delta].name
                )
                line = previous_state.line
                yield filename, line, previous_state.address, entry.state.address
            if entry.state.end_sequence:
                # For the state with `end_sequence`, `address` means the address
                # of the first byte after the target machine instruction
                # sequence and other information is meaningless. We clear
                # prevstate so that it's not used in the next iteration. Address
                # info is used in the above comparison to see if we need to use
                # the line information for the prevstate.
                previous_state = None
            else:
                previous_state = entry.state
