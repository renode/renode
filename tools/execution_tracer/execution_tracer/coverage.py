#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#
from __future__ import annotations

import os
import itertools
import functools
import sys
import typing
from collections import defaultdict
from dataclasses import dataclass, astuple, field
from typing import TYPE_CHECKING, BinaryIO, TextIO, Generator, Iterable, IO, NamedTuple, Optional
from elftools.common.utils import bytes2str
from elftools.elf.elffile import ELFFile

from execution_tracer.common_utils import extract_common_prefix, remove_prefix, PathSubstitution, apply_path_substitutions
import execution_tracer.dwarf as dwarf
import execution_tracer.pc2line as pc2line

if TYPE_CHECKING:
    from execution_tracer_reader import TraceData # type: ignore
    from elftools.elf.elffile import DWARFInfo
    from elftools.dwarf.compileunit import CompileUnit
    from elftools.dwarf.lineprogram import LineProgramEntry

@dataclass
class AddressRange:
    low: int
    high: int

    def __iter__(self):
        return iter(astuple(self))


class CodeLine:
    def __init__(self, content: Optional[str], number: int, filename: str, is_exec: bool) -> None:
        self.content = content
        self.number = number
        self.filename = filename
        self.addresses: list[AddressRange] = []
        self.is_exec = is_exec
        self.address_counter = defaultdict(lambda: ExecutionCount())
        self.labels = set()

    def add_address(self, low: int, high: int) -> None:
        # Try simply merge ranges if they are continuous.
        # since they are incrementing, this check is enough
        if self.addresses and self.addresses[-1].high == low:
            self.addresses[-1].high = high
        else:
            self.addresses.append(AddressRange(low, high))

    def count_execution(self, address, label):
        self.address_counter[address].count_up()
        self.labels.add(label)

    def most_executions(self) -> int:
        if len(self.address_counter) == 0:
            return 0
        return max(count.count for count in self.address_counter.values())

    def to_lcov_format(self) -> str:
        return f"DA:{self.number},{self.most_executions()}"

    def to_desc_format(self) -> str:
        return f"TEST:{self.number},{';'.join(self.labels)}"


class Record:
    def __init__(self, name: str):
        self.name = name
        self.lines: list[CodeLine] = []

    def add_code_line(self, cl: CodeLine) -> None:
        self.lines.append(cl)

    def get_exec_lines(self) -> Generator[CodeLine, None, None]:
        for line in self.lines:
            if not line.is_exec:
                continue
            yield line

    def to_lcov_format(self, *, name: Optional[str] = None) -> Generator[str, None, None]:
        yield "TN:"
        yield f'SF:{name if name else self.name}'
        yield from (l.to_lcov_format() for l in self.get_exec_lines())
        yield 'end_of_record'

    def to_desc_format(self, *, name: Optional[str] = None) -> Generator[str, None, None]:
        yield f'SN:{name if name else self.name}'
        yield from (l.to_desc_format() for l in self.get_exec_lines() if l.most_executions() > 0)
        yield 'end_of_record'

class ExecutionCount:
    def __init__(self):
        self.count = 0

    def count_up(self) -> None:
        self.count += 1


@dataclass
class Coverage:
    elf_file_handler: BinaryIO
    pc2line_file_stream: TextIO
    code_filenames: list[str]
    substitute_paths: list[PathSubstitution]
    print_unmatched_address: bool = False
    debug: bool = False
    noisy: bool = False
    lazy_line_cache: bool = False
    load_whole_code_lines: bool = True

    _code_files: list[IO] = field(init=False)

    def __post_init__(self):
        assert self.elf_file_handler or self.pc2line_file_stream
        if not self.code_filenames:
            print("No sources provided, will attempt to discover automatically")
            if self.elf_file_handler:
                self._code_files = dwarf.find_code_files(dwarf.get_dwarf_info(self.elf_file_handler), self.substitute_paths)
            if self.pc2line_file_stream:
                self._code_files = pc2line.find_code_files(self.pc2line_file_stream, self.substitute_paths)
            self.code_filenames = [apply_path_substitutions(code_filename.name, self.substitute_paths) for code_filename in self._code_files]
        else:
            self._code_files = [open(file) for file in self.code_filenames]

        if self.elf_file_handler:
            dwarf_info = dwarf.get_dwarf_info(self.elf_file_handler)
            self.files_low_address, self.files_high_address, self.code_lines = self._get_code_lines_by_file_from_dwarf(dwarf_info)
        if self.pc2line_file_stream:
            self.files_low_address, self.files_high_address, self.code_lines = self._get_code_lines_by_file_from_pc2line(self.pc2line_file_stream)


    def _approx_file_match(self, file_name: str) -> Optional[str]:
        for file in self.code_filenames:
            if file_name == file:
                return file_name
        for file in self.code_filenames:
            if os.path.basename(file) == os.path.basename(file_name):
                return file
        return None

    def _build_addr_map(self, code_lines_with_address: list[CodeLine], pc_length: int) -> dict[bytes, CodeLine]:
        # This is a dictionary of references, that will be used to quickly update counters for each code line.
        # We can walk only once over all code lines and pre-generate mappings between PCs (addresses) and code lines.
        # This way, when we'll later parse the trace, all we do are quick look-ups into this dictionary to get relevant code line by address.
        address_count_cache: dict[bytes, CodeLine] = {}

        for line in code_lines_with_address:
            for addr in line.addresses:
                addr_lo = addr.low
                while addr_lo < addr.high:
                    if not addr_lo in address_count_cache:
                        address_count_cache[addr_lo.to_bytes(pc_length, byteorder='little', signed=False)] = line
                    else:
                        print(f'Address {addr_lo} is already mapped to another line. Ignoring this time')
                    # This is a naive approach. If memory usage is of greater concern, find a better way to store ranges
                    addr_lo += 1
        return address_count_cache

    def _build_code_lines_dict(self) -> dict[str, list[CodeLine]]:
        code_lines: dict[str, list[CodeLine]] = defaultdict(list)
        for code_file in self._code_files:
            for line_no, line in enumerate(code_file, start=1):
                # Right now we mark all code lines as non-executable (that is, ignore when calculating coverage)
                # later, when parsing the DWARF/PC2Line# file, some will be marked as executable
                code_lines[code_file.name].append(CodeLine(None if not self.load_whole_code_lines else line, line_no, code_file.name, False))
        return code_lines
    
    # Get list of code lines, grouped by the file where they belong
    # Result is a tuple: lowest address in the binary, highest address in the binary, and a dictionary of code lines
    def _get_code_lines_by_file_from_dwarf(self, dwarf_info: 'DWARFInfo') -> tuple[int, int, dict[str, list[CodeLine]]]:
        code_lines: dict[str, list[CodeLine]] = self._build_code_lines_dict()

        # The lowest and highest interesting (corresponding to our sources' files) addresses, respectively
        files_low_address = None
        files_high_address = 0
        for file_name, file_path, line_number, address_low, address_high in dwarf.get_addresses(dwarf_info, debug=self.debug, noisy=self.noisy):
            file_full_name = os.path.join(file_path, file_name)
            file_full_name = apply_path_substitutions(file_full_name, self.substitute_paths)
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

    # Get list of code lines, grouped by the file where they belong
    # Result is a tuple: lowest address in the binary, highest address in the binary, and a dictionary of code lines
    def _get_code_lines_by_file_from_pc2line(self, pc2line_file_handle: TextIO) -> tuple[int, int, dict[str, list[CodeLine]]]:
        code_lines: dict[str, list[CodeLine]] = self._build_code_lines_dict()

        # The lowest and highest interesting (corresponding to our sources' files) addresses, respectively
        files_low_address = None
        files_high_address = 0

        for file_path, line_number, address in pc2line.get_entries(pc2line_file_handle):
            file = apply_path_substitutions(file_path, self.substitute_paths)

            if (file := self._approx_file_match(file)) is None:
                continue
            if line_number > len(code_lines[file]):
                raise ValueError(
                    f"Unexpected line number ({line_number}) in pc2line file, file with code {file} contains only {len(code_lines[file])}"
                )

            if file in code_lines:
                if self.debug:
                    print(f'file: {file}, line {line_number}, addr 0x{address:x}')
                # Pessimisticly assuming all instructions are 1 byte long. 
                # The end address is only used for merging entries for performance reasons
                # so having a smaller than actual value here is fine
                code_lines[file][line_number - 1].add_address(address, address + 1)
                code_lines[file][line_number - 1].is_exec = True

            if files_low_address is None:
                files_low_address = address
            
            files_low_address = min(files_low_address, address)
            files_high_address = max(files_high_address, address + 1)

        if files_low_address is None:
            raise RuntimeError("No matching address for provided files found")

        return files_low_address, files_high_address, code_lines

    def aggregate_coverage(self, trace_data: 'TraceData'):
        if not trace_data.has_pc:
            raise ValueError("The trace data doesn't contain PCs.")

        # Note, that this is just a cache to `code_lines`
        # but after eliminating lines that don't correspond to any address
        code_lines_with_address: list[CodeLine] = []
        for file_name in self.code_lines.keys():
            code_lines_with_address.extend(line for line in self.code_lines[file_name] if line.addresses)

        # This is also a cache to CodeLines
        address_count_cache: dict[bytes, CodeLine] = {}
        unmatched_address: set[int] = set()

        if not self.lazy_line_cache:
            print('Populating address cache...')
            address_count_cache = self._build_addr_map(code_lines_with_address, trace_data.pc_length)

        # This step takes some time for large traces and codebases, let's advise the user to wait
        print(f'Processing trace file {trace_data.file.name}, please wait...')
        for address_bytes, _, _, _ in trace_data:
            if address_bytes in address_count_cache:
                address_count_cache[address_bytes].count_execution(address_bytes, trace_data.filename)
            else:
                address = int.from_bytes(address_bytes, byteorder="little", signed=False)
                if address in unmatched_address:
                    # Is marked as unmatched, short cut!
                    # For unmatched address, a walk over all lines is very slow, since we need to check the entire map each time
                    # So make sure that we mark the address as "unmatched" on the first try, and don't care about it later on
                    continue
                # Optimization: cut-off addresses from trace that for sure don't matter to us
                if not (self.files_low_address <= address < self.files_high_address):
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
                        line.count_execution(address_bytes, trace_data.filename)
                        address_count_cache[address_bytes] = line
                        break
                if address_bytes not in address_count_cache:
                    unmatched_address.add(address)

        if self.print_unmatched_address:
            print(f'Found {len(unmatched_address)} unmatched unique addresses')
            print('Addresses in trace not matching any sources:', ', '.join(f'0x{addr:X}' for addr in sorted(unmatched_address)))

    def get_report(self) -> Iterable[CodeLine]:
        return itertools.chain.from_iterable(self.code_lines.values())

    def get_printed_report(self, legacy=False, *, remove_common_path_prefix: bool = False) -> Generator[str, None, None]:
        if legacy:
            yield from self.get_legacy_printed_report()
        else:
            yield from self.get_lcov_printed_report(remove_common_path_prefix=remove_common_path_prefix)

    def get_legacy_printed_report(self) -> Generator[str, None, None]:
        for line in self.get_report():
            if line.content is None:
                raise RuntimeError(f"No code line contents found for address: {line.addresses}, file {line.filename}, number: {line.number}")
            yield f"{line.most_executions():5d}:\t {line.content.rstrip()}"

    def get_lcov_printed_report(self, *, remove_common_path_prefix: bool = False) -> Generator[str, None, None]:
        records: dict[str, Record] = {}

        if remove_common_path_prefix:
            common_prefix = extract_common_prefix(self._code_files)

        for code_file in self._code_files:
            records[code_file.name] = Record(code_file.name)

        for line in self.get_report():
            records[line.filename].add_code_line(line)

        for record in records.values():
            yield from record.to_lcov_format(
                name=remove_prefix(record.name, common_prefix) if remove_common_path_prefix else None # type: ignore
            )

    def get_desc_printed_report(self, *, remove_common_path_prefix: bool = False) -> Generator[str, None, None]:
        records: dict[str, Record] = {}

        if remove_common_path_prefix:
            common_prefix = extract_common_prefix(self._code_files)

        for code_file in self._code_files:
            records[code_file.name] = Record(code_file.name)

        for line in self.get_report():
            records[line.filename].add_code_line(line)

        for record in records.values():
            yield from record.to_desc_format(
                name=remove_prefix(record.name, common_prefix) if remove_common_path_prefix else None # type: ignore
            )
