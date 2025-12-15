#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#
from __future__ import annotations

import os
import typing
from typing import IO, TYPE_CHECKING, BinaryIO, Generator, Iterable, NamedTuple
from elftools.common.utils import bytes2str
from elftools.elf.elffile import ELFFile
from execution_tracer.common_utils import PathSubstitution, apply_path_substitutions

if TYPE_CHECKING:
    from elftools.elf.elffile import DWARFInfo
    from elftools.dwarf.compileunit import CompileUnit
    from elftools.dwarf.lineprogram import LineProgramEntry


def get_dwarf_info(elf_file_handler: BinaryIO) -> 'DWARFInfo':
    elf_file = ELFFile(elf_file_handler)
    if not elf_file.has_dwarf_info():
        raise ValueError(
            f"The file ({elf_file_handler.name}) doesn't contain DWARF data."
        )
    return elf_file.get_dwarf_info()

def find_code_files(dwarf_info: 'DWARFInfo', substitute_paths: Iterable[PathSubstitution], verbose=True) -> list[IO]:
    unique_files: set[str] = set()
    code_files: list[IO] = []
    if verbose:
        print('Attempting to resolve source files by scanning DWARF data...')
    for entry in get_addresses(dwarf_info):
        absolute_path = os.path.join(entry.file_path, entry.file_name)
        unique_files.add(absolute_path)

    for code_filename in unique_files:
        code_filename = apply_path_substitutions(code_filename, substitute_paths)
        if verbose:
            print('Found source:', code_filename)
        try:
            code_files.append(open(code_filename))
        except FileNotFoundError:
            print('Source file not found:', code_filename)
    return code_files

def get_addresses(dwarf_info: 'DWARFInfo', *, debug=False, noisy=False) -> Generator[DWARFLineProgramEntry, None, None]:
    # Go over all the line programs in the DWARF information, looking for
    # one that describes the given address.
    for CU in dwarf_info.iter_CUs():
        yield from get_addresses_for_CU(dwarf_info, CU, debug=debug, noisy=noisy)

class DWARFLineProgramEntry(NamedTuple):
    file_name: str
    file_path: str
    line_number: int
    address_low: int
    address_high: int

def get_addresses_for_CU(dwarf_info: DWARFInfo, CU: CompileUnit, *, debug=False, noisy=False) -> Generator[DWARFLineProgramEntry, None, None]:
    # First, look at line programs to find the file/line for the address
    line_program = dwarf_info.line_program_for_CU(CU)
    if not line_program:
        raise RuntimeError("Couldn't extract line program data. Try to recompile the binary with debugging information enabled")
    delta = 1 if line_program.header.version < 5 else 0
    previous_state = None
    for entry in typing.cast(Iterable['LineProgramEntry'], line_program.get_entries()):
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
            yield DWARFLineProgramEntry(filename, directory_path, previous_state.line, previous_state.address, entry.state.address)
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
