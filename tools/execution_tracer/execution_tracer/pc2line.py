#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#
import os
from typing import IO, Generator, Iterable, NamedTuple, TextIO
from execution_tracer.common_utils import PathSubstitution, apply_path_substitutions

def find_code_files(pc2line_file_stream: TextIO, substitute_paths: Iterable[PathSubstitution], verbose=True) -> list[IO]:
    unique_files: set[str] = set()
    code_files: list[IO] = []
    if verbose:
        print('Attempting to resolve source files by scanning pc2line file...')
    for line in pc2line_file_stream:
        entry = PC2LineEntry.from_line(line)
        unique_files.add(entry.file_path)

    for code_filename in unique_files:
        code_filename = apply_path_substitutions(code_filename, substitute_paths)
        if verbose:
            print('Found source:', code_filename)
        try:
            code_files.append(open(code_filename))
        except FileNotFoundError:
            print('Source file not found:', code_filename)
    # Reset file stream
    pc2line_file_stream.seek(0)
    return code_files

class PC2LineEntry(NamedTuple):
    file_path: str
    line_number: int
    address: int

    @classmethod
    def from_line(cls, line: str):
        address_raw, rest = line.split(' ', 1)
        file, line_number = rest.split(':', 1)
        return cls(file, int(line_number), int(address_raw, 16))

def get_entries(pc2line_file_handle: TextIO) -> Generator[PC2LineEntry, None, None]:
    for line in pc2line_file_handle:
        yield PC2LineEntry.from_line(line)
