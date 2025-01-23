#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import os
import itertools
from collections import defaultdict
from dataclasses import dataclass, astuple
from typing import Dict, Iterable, List, Set, SupportsBytes
from elftools.common.utils import bytes2str
from elftools.elf.elffile import ELFFile

DEBUG = True
NOISY = False

@dataclass
class AddressRange:
    low: int
    high: int

    def __iter__(self):
        return iter(astuple(self))


class CodeLine:
    def __init__(self, content: str, number: int, filename: str, is_exec: bool):
        self.content = content
        self.number = number
        self.filename = filename
        self.addresses: List[AddressRange] = []
        self.is_exec = is_exec
        self.address_counter = defaultdict(lambda: ExecutionCount())

    def add_address(self, low, high):
        # Try simply merge ranges if they are continuous.
        # since they are incrementing, this check is enough
        if self.addresses and self.addresses[-1].high == low:
            self.addresses[-1].high = high
        else:
            self.addresses.append(AddressRange(low, high))

    def count_execution(self, address):
        self.address_counter[address].count_up()
        return self.address_counter[address]

    def most_executions(self):
        if len(self.address_counter) == 0:
            return 0
        return max(count.count for count in self.address_counter.values())

    def to_lcov_format(self):
        return f"DA:{self.number},{self.most_executions()}"


class Record:
    def __init__(self, name: str):
        self.name = name
        self.lines: List[CodeLine] = []

    def add_code_line(self, cl: CodeLine):
        self.lines.append(cl)

    def get_exec_lines(self):
        for line in self.lines:
            if not line.is_exec:
                continue
            yield line

    def to_lcov_format(self):
        yield "TN:"
        # Fixup in case we don't have a dirname
        yield f'SF:project/{self.name}'
        yield from (l.to_lcov_format() for l in self.get_exec_lines())
        yield 'end_of_record'


class ExecutionCount:
    def __init__(self):
        self.count = 0

    def count_up(self):
        self.count += 1

def get_dwarf_info(elf_file_handler):
    elf_file = ELFFile(elf_file_handler)
    if not elf_file.has_dwarf_info():
        raise ValueError(
            f"The file ({elf_file_handler.name}) doesn't contain DWARF data."
        )
    return elf_file.get_dwarf_info()

def find_code_files(dwarf_info, verbose=True):
    unique_files = set()
    code_files = []
    if verbose:
        print('Attempting to resolve source files by scanning DWARF data...')
    for file_name, _, _, _, directory in get_addresses(dwarf_info):
        absolute_path = os.path.join(directory, file_name)
        unique_files.add(absolute_path)

    code_filenames = list(unique_files)
    for code_filename in code_filenames:
        if verbose:
            print('Found source:', code_filename)
        try:
            code_files.append(open(code_filename))
        except FileNotFoundError:
            print('Source file not found:', code_filename)

    return code_files

def report_coverage(trace_data, elf_file_handler, code_files, print_unmatched_address):
    if not trace_data.has_pc:
        raise ValueError("The trace data doesn't contain PCs.")

    dwarf_info = get_dwarf_info(elf_file_handler)

    code_lines: Dict[str, List[CodeLine]] = defaultdict(lambda: [])
    code_filenames: List[str] = []

    for code_file in code_files:
        file_name = os.path.basename(code_file.name)
        code_filenames += [file_name]
        for no, line in enumerate(code_file):
            # Right now we mark all code lines as non-executable (that is, ignore when calculating coverage)
            # later, when parsing DWARF info, some will be marked as executable
            code_lines[file_name].append(CodeLine(line, no + 1, file_name, False))

    # The lowest and highest interesting (corresponding to our sources' files) addresses, respectively
    files_low_address = None
    files_high_address = 0
    for file_name, line_number, address_low, address_high, _ in get_addresses(dwarf_info):
        if file_name not in code_filenames:
            continue
        if line_number > len(code_lines[file_name]):
            raise ValueError(
                f"Unexpected line number ({line_number}) in ELF file, file with code {file_name} contains only {len(code_lines[file_name])}"
            )
        if file_name in code_lines:
            if DEBUG:
                print(f'file: {file_name}, line {line_number}, addr_low 0x{address_low:x}, addr_high: 0x{address_high:x}')
            code_lines[file_name][line_number - 1].add_address(address_low, address_high)
            code_lines[file_name][line_number - 1].is_exec = True

        if files_low_address is None:
            files_low_address = address_low
            files_high_address = address_high
        else:
            files_low_address = min(files_low_address, address_low)
            files_high_address = max(files_high_address, address_high)

    if files_low_address is None:
        raise RuntimeError("No matching address for provided files found")

    # Note, that this is just a cache to `code_lines`
    # but after eliminating lines that don't correspond to any address
    code_lines_with_address: List[CodeLine] = []
    for file_name in code_lines.keys():
        code_lines_with_address.extend([line for line in code_lines[file_name] if line.addresses])

    # This is also a cache to ExecutionCount
    address_count_cache: Dict[SupportsBytes, ExecutionCount] = {}
    if print_unmatched_address:
        unmatched_address: Set[int] = set()
    for address_bytes, _, _, _ in trace_data:
        if address_bytes in address_count_cache:
            address_count_cache[address_bytes].count_up()
        else:
            address = int.from_bytes(address_bytes, byteorder="little", signed=False)
            # Optimization: cut-off addresses from trace that for sure don't matter to us
            if not (files_low_address <= address < files_high_address):
                if print_unmatched_address:
                    unmatched_address.add(address)
                continue
            if DEBUG and NOISY:
                print(f'parsing new addr in trace: {address:x}')
            # Find a line, for which one of the addresses matches with the address bytes present in the trace
            for line in code_lines_with_address:
                if any(
                    # Check for all address ranges
                    address_range.low <= address < address_range.high
                    for address_range in line.addresses
                ):
                    # One line is likely to exist at several addresses
                    address_count_cache[address_bytes] = line.count_execution(
                        address_bytes
                    )
                    break
            if print_unmatched_address and address_bytes not in address_count_cache:
                unmatched_address.add(address)

    if print_unmatched_address:
        print(f'Found {len(unmatched_address)} unmatched unique addresses')
        for address in sorted(unmatched_address):
            print(f'Address in trace not matching any sources: 0x{address:x}')

    return itertools.chain.from_iterable(code_lines.values())

def convert_to_lcov(code_lines: List[CodeLine], code_files: List):
    records: Dict[str, Record] = {}
    for code_file in code_files:
        file_name = os.path.basename(code_file.name)
        records[file_name] = Record(code_file.name)

    for cl in code_lines:
        records[cl.filename].add_code_line(cl)

    for record in records.values():
        yield from record.to_lcov_format()

def get_addresses(dwarf_info):
    # Go over all the line programs in the DWARF information, looking for
    # one that describes the given address.
    for CU in dwarf_info.iter_CUs():
        yield from get_addresses_for_CU(dwarf_info, CU)

def get_addresses_for_CU(dwarf_info, CU):
    # First, look at line programs to find the file/line for the address
    line_program = dwarf_info.line_program_for_CU(CU)
    delta = 1 if line_program.header.version < 5 else 0
    previous_state = None
    for entry in line_program.get_entries():
        # We're interested in those entries where a new state is assigned
        if entry.state is None:
            continue
        # We need to check if an address changes in the state machine
        # otherwise, the mapping isn't really valid
        if previous_state and previous_state.address < entry.state.address:
            filename = bytes2str(
                line_program["file_entry"][previous_state.file - delta].name
            )
            # Adapted from https://github.com/eliben/pyelftools/blob/3181eedfffc8eaea874152fb67f77d0be4ca969e/examples/dwarf_lineprogram_filenames.py#L71
            dir_index = line_program["file_entry"][previous_state.file - delta]["dir_index"] - delta
            directory_path = bytes2str(
                line_program["include_directory"][dir_index]
            )
            if DEBUG and NOISY:
                print('Parsing:', directory_path, filename)
            yield filename, previous_state.line, previous_state.address, entry.state.address, directory_path
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
