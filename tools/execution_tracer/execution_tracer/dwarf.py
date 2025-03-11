#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import os
import itertools
import functools
from collections import defaultdict
from dataclasses import dataclass, astuple, field
from typing import TYPE_CHECKING, BinaryIO, Dict, Generator, Iterable, List, Set, IO, Optional, Tuple
from elftools.common.utils import bytes2str
from elftools.elf.elffile import ELFFile

if TYPE_CHECKING:
    from execution_tracer_reader import TraceData
    from elftools.elf.elffile import DWARFInfo

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

    def add_address(self, low: int, high: int):
        # Try simply merge ranges if they are continuous.
        # since they are incrementing, this check is enough
        if self.addresses and self.addresses[-1].high == low:
            self.addresses[-1].high = high
        else:
            self.addresses.append(AddressRange(low, high))

    def count_execution(self, address) -> 'ExecutionCount':
        self.address_counter[address].count_up()
        return self.address_counter[address]

    def most_executions(self) -> int:
        if len(self.address_counter) == 0:
            return 0
        return max(count.count for count in self.address_counter.values())

    def to_lcov_format(self) -> str:
        return f"DA:{self.number},{self.most_executions()}"


class Record:
    def __init__(self, name: str):
        self.name = name
        self.lines: List[CodeLine] = []

    def add_code_line(self, cl: CodeLine):
        self.lines.append(cl)

    def get_exec_lines(self) -> Generator[CodeLine, None, None]:
        for line in self.lines:
            if not line.is_exec:
                continue
            yield line

    def to_lcov_format(self) -> Generator[str, None, None]:
        yield "TN:"
        yield f'SF:{self.name}'
        yield from (l.to_lcov_format() for l in self.get_exec_lines())
        yield 'end_of_record'


class ExecutionCount:
    def __init__(self):
        self.count = 0

    def count_up(self):
        self.count += 1


@dataclass(frozen=True)
class PathSubstitution:
    before: str
    after: str

    def apply(self, path: str) -> str:
        return path.replace(self.before, self.after)

    @classmethod
    def from_arg(cls, s: str) -> 'Self':
        args = s.split(':')
        if len(args) != 2:
            raise ValueError('Path substitution should be in old_path:new_path format')
        return cls(*args)


@dataclass
class Coverage:
    elf_file_handler: BinaryIO
    code_filenames: List[str]
    substitute_paths: List[PathSubstitution]
    print_unmatched_address: bool = False
    debug: bool = False
    noisy: bool = False
    lazy_line_cache: bool = False

    _code_files: List[IO] = field(init=False)

    def __post_init__(self):
        if not self.code_filenames:
            print("No sources provided, will attempt to discover automatically")
            self._code_files = self._find_code_files(get_dwarf_info(self.elf_file_handler), self.substitute_paths)
            self.code_filenames = [self._apply_path_substitutions(code_filename.name, self.substitute_paths) for code_filename in self._code_files]
        else:
            self._code_files = [open(file) for file in self.code_filenames]

    @staticmethod
    def _find_code_files(dwarf_info, substitute_paths: Iterable[PathSubstitution], verbose=True) -> List[IO]:
        unique_files: Set[str] = set()
        code_files: List[IO] = []
        if verbose:
            print('Attempting to resolve source files by scanning DWARF data...')
        for file_name, _, _, _, directory in get_addresses(dwarf_info):
            absolute_path = os.path.join(directory, file_name)
            unique_files.add(absolute_path)

        for code_filename in unique_files:
            code_filename = Coverage._apply_path_substitutions(code_filename, substitute_paths)
            if verbose:
                print('Found source:', code_filename)
            try:
                code_files.append(open(code_filename))
            except FileNotFoundError:
                print('Source file not found:', code_filename)
        return code_files

    @staticmethod
    def _apply_path_substitutions(code_filename: str, substitute_paths: Iterable[PathSubstitution]) -> str:
        return functools.reduce(lambda p, sub: sub.apply(p), substitute_paths, code_filename)

    def _approx_file_match(self, file_name: str) -> Optional[str]:
        for file in self.code_filenames:
            if file_name == file:
                return file_name
        for file in self.code_filenames:
            if os.path.basename(file) == os.path.basename(file_name):
                return file
        return None

    def _build_addr_map(self, code_lines_with_address: List[CodeLine], pc_length: int) -> Dict[bytes, ExecutionCount]:
        # This is a dictionary of references, that will be used to quickly update counters for each code line.
        # We can walk only once over all code lines and pre-generate mappings between PCs (addresses) and code lines.
        # This way, when we'll later parse the trace, all we do are quick look-ups into this dictionary to increment the execution counters.
        address_count_cache: Dict[bytes, ExecutionCount] = {}

        for line in code_lines_with_address:
            for addr in line.addresses:
                addr_lo = addr.low
                while addr_lo < addr.high:
                    if not addr_lo in address_count_cache:
                        address_count_cache[addr_lo.to_bytes(pc_length, byteorder='little', signed=False)] = line.address_counter[addr_lo]
                    else:
                        print(f'Address {addr_lo} is already mapped to another line. Ignoring this time')
                    # This is a naive approach. If memory usage is of greater concern, find a better way to store ranges
                    addr_lo += 1
        return address_count_cache

    # Get list of code lines, grouped by the file where they belong
    # Result is a tuple: lowest address in the binary, highest address in the binary, and a dictionary of code lines
    def _get_code_lines_by_file(self, dwarf_info: 'DWARFInfo') -> Tuple[int, int, Dict[str, List[CodeLine]]]:
        code_lines: Dict[str, List[CodeLine]] = defaultdict(list)
        for code_file in self._code_files:
            for no, line in enumerate(code_file):
                # Right now we mark all code lines as non-executable (that is, ignore when calculating coverage)
                # later, when parsing DWARF info, some will be marked as executable
                code_lines[code_file.name].append(CodeLine(line, no + 1, code_file.name, False))

        # The lowest and highest interesting (corresponding to our sources' files) addresses, respectively
        files_low_address = None
        files_high_address = 0
        for file_name, line_number, address_low, address_high, file_path in get_addresses(dwarf_info, debug=self.debug, noisy=self.noisy):
            file_full_name = os.path.join(file_path, file_name)
            file_full_name = self._apply_path_substitutions(file_full_name, self.substitute_paths)
            # If the files are provided by hand, patch their names
            if (file_full_name := self._approx_file_match(file_full_name)) is None:
                continue
            if line_number > len(code_lines[file_full_name]):
                raise ValueError(
                    f"Unexpected line number ({line_number}) in ELF file, file with code {file_full_name} contains only {len(code_lines[file_full_name])}"
                )
            if file_full_name in code_lines:
                if self.debug:
                    print(f'file: {file_full_name}, line {line_number}, addr_low 0x{address_low:x}, addr_high: 0x{address_high:x}')
                code_lines[file_full_name][line_number - 1].add_address(address_low, address_high)
                code_lines[file_full_name][line_number - 1].is_exec = True

            if files_low_address is None:
                files_low_address = address_low
                files_high_address = address_high
            else:
                files_low_address = min(files_low_address, address_low)
                files_high_address = max(files_high_address, address_high)

        if files_low_address is None:
            raise RuntimeError("No matching address for provided files found")

        return files_low_address, files_high_address, code_lines

    def report_coverage(self, trace_data: 'TraceData') -> Iterable[CodeLine]:
        if not trace_data.has_pc:
            raise ValueError("The trace data doesn't contain PCs.")

        dwarf_info = get_dwarf_info(self.elf_file_handler)
        files_low_address, files_high_address, code_lines = self._get_code_lines_by_file(dwarf_info)

        # Note, that this is just a cache to `code_lines`
        # but after eliminating lines that don't correspond to any address
        code_lines_with_address: List[CodeLine] = []
        for file_name in code_lines.keys():
            code_lines_with_address.extend(line for line in code_lines[file_name] if line.addresses)

        # This is also a cache to ExecutionCount
        address_count_cache: Dict[bytes, ExecutionCount] = {}
        unmatched_address: Set[int] = set()

        if not self.lazy_line_cache:
            print('Populating address cache...')
            address_count_cache = self._build_addr_map(code_lines_with_address, trace_data.pc_length)

        # This step takes some time for large traces and codebases, let's advise the user to wait
        print('Processing the trace, please wait...')
        for address_bytes, _, _, _ in trace_data:
            if address_bytes in address_count_cache:
                address_count_cache[address_bytes].count_up()
            else:
                address = int.from_bytes(address_bytes, byteorder="little", signed=False)
                if address in unmatched_address:
                    # Is marked as unmatched, short cut!
                    # For unmatched address, a walk over all lines is very slow, since we need to check the entire map each time
                    # So make sure that we mark the address as "unmatched" on the first try, and don't care about it later on
                    continue
                # Optimization: cut-off addresses from trace that for sure don't matter to us
                if not (files_low_address <= address < files_high_address):
                    unmatched_address.add(address)
                    continue
                if self.debug and self.noisy:
                    print(f'parsing new addr in trace: {address:x}')
                # Find a line, for which one of the addresses matches with the address bytes present in the trace
                # If we pre-generated the mappings earlier (in `_build_addr_map`), this function will only serve as a back-up to find not matched addresses
                # Walking each time is slow, so it's generally better to pre-generate mappings, if we aren't running out of memory
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
                if address_bytes not in address_count_cache:
                    unmatched_address.add(address)

        if self.print_unmatched_address:
            print(f'Found {len(unmatched_address)} unmatched unique addresses')
            print('Addresses in trace not matching any sources:', ', '.join(f'0x{addr:X}' for addr in sorted(unmatched_address)))

        return itertools.chain.from_iterable(code_lines.values())

    def convert_to_lcov(self, code_lines: Iterable[CodeLine]) -> Generator[str, None, None]:
        records: Dict[str, Record] = {}
        for code_file in self._code_files:
            records[code_file.name] = Record(code_file.name)

        for line in code_lines:
            records[line.filename].add_code_line(line)

        for record in records.values():
            yield from record.to_lcov_format()

def get_dwarf_info(elf_file_handler: BinaryIO) -> 'DWARFInfo':
    elf_file = ELFFile(elf_file_handler)
    if not elf_file.has_dwarf_info():
        raise ValueError(
            f"The file ({elf_file_handler.name}) doesn't contain DWARF data."
        )
    return elf_file.get_dwarf_info()

def get_addresses(dwarf_info, *, debug=False, noisy=False):
    # Go over all the line programs in the DWARF information, looking for
    # one that describes the given address.
    for CU in dwarf_info.iter_CUs():
        yield from get_addresses_for_CU(dwarf_info, CU, debug=debug, noisy=noisy)

def get_addresses_for_CU(dwarf_info, CU, *, debug=False, noisy=False):
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
            if debug and noisy:
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
