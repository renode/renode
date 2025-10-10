#!/usr/bin/env python3
#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#
from __future__ import annotations

import argparse
import contextlib
import itertools
import platform
import sys
import os
import gzip
from enum import Enum
from dataclasses import dataclass
from typing import IO, BinaryIO, NamedTuple, Optional

from ctypes import cdll, c_char_p, POINTER, c_void_p, c_ubyte, c_uint64, c_byte, c_size_t, cast

# Allow directly using this as a script, without installation
try:
    import execution_tracer.dwarf as dwarf
    import execution_tracer.coverview_integration as coverview_integration
except ImportError:
    import dwarf
    import coverview_integration

FILE_SIGNATURE = b"ReTrace"
FILE_VERSION = b"\x04"
HEADER_LENGTH = 10
MEMORY_ACCESS_LENGTH = 25
RISCV_VECTOR_CONFIGURATION_LENGTH = 16


class AdditionalDataType(Enum):
    Empty = 0
    MemoryAccess = 1
    RiscVVectorConfiguration = 2
    RiscVAtomicInstruction = 3


class MemoryAccessType(Enum):
    MemoryIORead = 0
    MemoryIOWrite = 1
    MemoryRead = 2
    MemoryWrite = 3
    InsnFetch = 4

class RiscVAtomicInstruction(Enum):
    ADD = 0x00
    SWAP = 0x01
    LR = 0x02
    SC = 0x03
    XOR = 0x04
    CAS = 0x05
    AND = 0x0C
    OR = 0x08
    MIN = 0x10
    MAX = 0x14
    MINU = 0x18
    MAXU = 0x1C

class RiscVAtomicInstructionWidth(Enum):
    Word = 0x2
    DoubleWord = 0x3
    QuadWord = 0x4

@dataclass()
class Header:
    pc_length: int
    has_opcodes: bool
    extra_length: int = 0
    uses_multiple_instruction_sets: bool = False
    triple_and_model: Optional[str] = None

    def __str__(self) -> str:
        return "Header: pc_length: {}, has_opcodes: {}, extra_length: {}, uses_multiple_instruction_sets: {}, triple_and_model: {}".format(
            self.pc_length, self.has_opcodes, self.extra_length, self.uses_multiple_instruction_sets, self.triple_and_model)


def read_header(file: BinaryIO) -> Header:
    if file.read(len(FILE_SIGNATURE)) != FILE_SIGNATURE:
        raise InvalidFileFormatException("File signature isn't detected.")

    version = file.read(1)
    if version != FILE_VERSION:
        raise InvalidFileFormatException(f"Unsuported file format version {version}, expected {FILE_VERSION}")

    pc_length_raw = file.read(1)
    opcodes_raw = file.read(1)
    if len(pc_length_raw) != 1 or len(opcodes_raw) != 1:
        raise InvalidFileFormatException("Invalid file header")

    if opcodes_raw[0] == 0:
        return Header(pc_length_raw[0], False, 0, False, None)
    elif opcodes_raw[0] == 1:
        uses_multiple_instruction_sets_raw = file.read(1)
        identifier_length_raw = file.read(1)
        if len(uses_multiple_instruction_sets_raw) != 1 or len(identifier_length_raw) != 1:
            raise InvalidFileFormatException("Invalid file header")
        
        uses_multiple_instruction_sets = uses_multiple_instruction_sets_raw[0] == 1
        identifier_length = identifier_length_raw[0]
        triple_and_model_raw = file.read(identifier_length)
        if len(triple_and_model_raw) != identifier_length:
            raise InvalidFileFormatException("Invalid file header")
            
        triple_and_model = triple_and_model_raw.decode("utf-8")
        extra_length = 2 + identifier_length

        return Header(pc_length_raw[0], True, extra_length, uses_multiple_instruction_sets, triple_and_model)
    else:
        raise InvalidFileFormatException("Invalid opcodes field at file header")


def read_file(file: BinaryIO, disassemble: bool, llvm_disas_path: Optional[str]) -> TraceData:
    header = read_header(file)
    return TraceData(file, header, disassemble, llvm_disas_path)


def bytes_to_hex(bytes: bytes, zero_padded=True) -> str:
    integer = int.from_bytes(bytes, byteorder="little", signed=False)
    format_string = "0{}X".format(len(bytes)*2) if zero_padded else "X"
    return "0x{0:{fmt}}".format(integer, fmt=format_string)

class TraceEntry(NamedTuple):
    pc: bytes
    opcode: bytes
    additional_data: list[str]
    isa_mode: int

class TraceData:
    disassemblers: Optional[dict[int, 'LLVMDisassembler']] = None
    isa_mode: int = 0
    instructions_left_in_block = 0

    def __init__(self, file: IO, header: Header, disassemble: bool, llvm_disas_path: Optional[str]):
        self.file = file
        self.pc_length = int(header.pc_length)
        self.has_pc = (self.pc_length != 0)
        self.has_opcodes = bool(header.has_opcodes)
        self.extra_length = header.extra_length
        self.uses_multiple_instruction_sets = header.uses_multiple_instruction_sets
        self.triple_and_model = header.triple_and_model
        self.disassemble = disassemble
        self.filename = os.path.basename(file.name).split('.')[0]
        if self.disassemble:
            if not header.triple_and_model:
                raise RuntimeError("No architecture triple available in disassembly mode. Trace file might be corrupted")
            if not llvm_disas_path:
                raise RuntimeError("No path to decompiler library provided")
            triple, model = header.triple_and_model.split(" ")
            self.disassemblers = {0: LLVMDisassembler(triple, model, llvm_disas_path)}
            if self.uses_multiple_instruction_sets:
                if triple == "armv7a":
                    # For armv7a the flags are only 1 bit: 0 = ARM, 1 = thumb
                    self.disassemblers[0b01] = LLVMDisassembler("thumb", model, llvm_disas_path)
                elif triple == "arm64":
                    # For arm64 there are two flags: bit[0] means Thumb and bit[1] means AArch32.
                    # The valid values are 00, 10, and 11 (no 64-bit Thumb).
                    self.disassemblers[0b10] = LLVMDisassembler("armv7a", model, llvm_disas_path)
                    self.disassemblers[0b11] = LLVMDisassembler("thumb", model, llvm_disas_path)


    def __iter__(self):
        self.file.seek(HEADER_LENGTH + self.extra_length, 0)
        return self

    def __next__(self) -> TraceEntry:
        additional_data = []

        if self.uses_multiple_instruction_sets and self.instructions_left_in_block == 0:
            isa_mode_raw = self.file.read(1)
            if len(isa_mode_raw) != 1:
                # No more data frames to read
                raise StopIteration

            self.isa_mode = isa_mode_raw[0]
            
            block_length_raw = self.file.read(8)
            if len(block_length_raw) != 8:
                raise InvalidFileFormatException("Unexpected end of file")
            
            # The `instructions_left_in_block` counter is kept only for traces produced by cores that can switch between multiple modes.
            self.instructions_left_in_block = int.from_bytes(block_length_raw, byteorder="little", signed=False)

        if self.uses_multiple_instruction_sets:
            self.instructions_left_in_block -= 1

        pc = self.file.read(self.pc_length)
        opcode_length = self.file.read(int(self.has_opcodes))

        if self.pc_length != len(pc):
            # No more data frames to read
            raise StopIteration
        if self.has_opcodes and len(opcode_length) == 0:
            if self.has_pc:
                raise InvalidFileFormatException("Unexpected end of file")
            else:
                # No more data frames to read
                raise StopIteration

        if self.has_opcodes:
            opcode_length = opcode_length[0]
            opcode = self.file.read(opcode_length)
            if len(opcode) != opcode_length:
                raise InvalidFileFormatException("Unexpected end of file")
        else:
            opcode = b""

        additional_data_type = AdditionalDataType(self.file.read(1)[0])
        while (additional_data_type is not AdditionalDataType.Empty):
            if additional_data_type is AdditionalDataType.MemoryAccess:
                additional_data.append(self.parse_memory_access_data())
            elif additional_data_type is AdditionalDataType.RiscVVectorConfiguration:
                additional_data.append(self.parse_riscv_vector_configuration_data())
            elif additional_data_type is AdditionalDataType.RiscVAtomicInstruction:
                additional_data.append(self.parse_riscv_atomic_instruction_data())

            try:
                additional_data_type = AdditionalDataType(self.file.read(1)[0])
            except IndexError:
                break
        return TraceEntry(pc, opcode, additional_data, self.isa_mode)

    def parse_memory_access_data(self) -> str:
        data = self.file.read(MEMORY_ACCESS_LENGTH)
        if len(data) != MEMORY_ACCESS_LENGTH:
            raise InvalidFileFormatException("Unexpected end of file")
        type = MemoryAccessType(data[0])
        address = bytes_to_hex(data[1:9], zero_padded=False)
        value = bytes_to_hex(data[9:17], zero_padded=False)
        address_physical = bytes_to_hex(data[17:], zero_padded=False)

        if address == address_physical:
            return f"{type.name} with address {address}, value {value}"
        else:
            return f"{type.name} with address {address} => {address_physical}, value {value}"


    def parse_riscv_vector_configuration_data(self) -> str:
        data = self.file.read(RISCV_VECTOR_CONFIGURATION_LENGTH)
        if len(data) != RISCV_VECTOR_CONFIGURATION_LENGTH:
            raise InvalidFileFormatException("Unexpected end of file")
        vl = bytes_to_hex(data[0:8], zero_padded=False)
        vtype = bytes_to_hex(data[8:16], zero_padded=False)
        return f"Vector configured to VL: {vl}, VTYPE: {vtype}"

    def parse_riscv_atomic_instruction_data(self) -> str:
        is_after_execution_raw = self.file.read(1)
        width_raw = self.file.read(1)
        instruction_raw = self.file.read(1)
        if (
            len(is_after_execution_raw) != 1
            or len(width_raw) != 1
            or len(instruction_raw) != 1
        ):
            raise InvalidFileFormatException("Invalid RISC-V atomic instruction data")

        word_size = 0
        width = RiscVAtomicInstructionWidth(width_raw[0])
        if width == RiscVAtomicInstructionWidth.Word:
            word_size = 4
        if width == RiscVAtomicInstructionWidth.DoubleWord:
            word_size = 8
        if width == RiscVAtomicInstructionWidth.QuadWord:
            raise InvalidFileFormatException("Support for QuadWord atomic operands not yet implemented")

        data_size = 4 * word_size
        data = self.file.read(data_size)
        if len(data) != data_size:
            raise InvalidFileFormatException("Unexpected end of file")

        rd = bytes_to_hex(data[0 * word_size:1 * word_size], zero_padded=False)
        rs1 = bytes_to_hex(data[1 * word_size:2 * word_size], zero_padded=False)
        rs2 = bytes_to_hex(data[2 * word_size:3 * word_size], zero_padded=False)
        memory_value = bytes_to_hex(data[3 * word_size:4 * word_size], zero_padded=False)

        is_after_execution = is_after_execution_raw[0]

        prePostText = "after" if is_after_execution else "before"
        return f"AMO operands {prePostText} - RD: {rd}, RS1: {rs1} (memory value: {memory_value}), RS2: {rs2}"

    def format_entry(self, entry: TraceEntry) -> str:
        (pc, opcode, additional_data, isa_mode) = entry
        pc_str: str = ""
        opcode_str: str = ""
        if self.pc_length:
            pc_str = bytes_to_hex(pc)
        if self.has_opcodes:
            opcode_str = bytes_to_hex(opcode)
        output = ""
        if self.pc_length and self.has_opcodes:
            output = f"{pc_str}: {opcode_str}"
        elif self.pc_length:
            output = pc_str
        elif self.has_opcodes:
            output = opcode_str
        else:
            output = ""

        if self.has_opcodes and self.disassemble:
            if not self.disassemblers:
                raise RuntimeError("No disassembly library loaded")
            disas = self.disassemblers[isa_mode]
            _, instruction = disas.get_instruction(opcode)
            output += " " + instruction.decode("utf-8")

        if len(additional_data) > 0:
            output += "\n" + "\n".join(additional_data)

        return output


class InvalidFileFormatException(Exception):
    pass


class LLVMDisassembler():
    def __init__(self, triple: str, cpu: str, llvm_disas_path: str):
        try:
            self.lib = cdll.LoadLibrary(llvm_disas_path)
        except OSError:
            raise FileNotFoundError('Could not find valid `libllvm-disas` library. Please specify the correct path with the --llvm-disas-path argument.')

        self.__init_library()

        self._context = self.lib.llvm_create_disasm_cpu(c_char_p(triple.encode('utf-8')), c_char_p(cpu.encode('utf-8')))
        if not self._context:
            raise RuntimeError('CPU or triple name not detected by LLVM. Disassembling will not be possible.')

    def __del__(self):
        if  hasattr(self, '_context'):
            self.lib.llvm_disasm_dispose(self._context)

    def __init_library(self) -> None:
        self.lib.llvm_create_disasm_cpu.argtypes = [c_char_p, c_char_p]
        self.lib.llvm_create_disasm_cpu.restype = POINTER(c_void_p)

        self.lib.llvm_disasm_dispose.argtypes = [POINTER(c_void_p)]

        self.lib.llvm_disasm_instruction.argtypes = [POINTER(c_void_p), POINTER(c_ubyte), c_uint64, c_char_p, c_size_t]
        self.lib.llvm_disasm_instruction.restype = c_size_t

    def get_instruction(self, opcode) -> tuple[int, bytes]:
        opcode_buf = cast(c_char_p(opcode), POINTER(c_ubyte))
        disas_str = cast((c_byte * 1024)(), c_char_p)

        bytes_read = self.lib.llvm_disasm_instruction(self._context, opcode_buf, c_uint64(len(opcode)), disas_str, 1024)

        if disas_str.value is None:
            raise RuntimeError("Unexpected null pointer when disassembling instruction")

        return (bytes_read, disas_str.value)

def handle_coverage(args, trace_data_per_file) -> None:
    coverage_config = dwarf.Coverage(
        elf_file_handler=args.coverage_binary,
        code_filenames=args.coverage_code,
        substitute_paths=args.sub_source_path,
        debug=args.debug,
        print_unmatched_address=args.print_unmatched_address,
        lazy_line_cache=args.lazy_line_cache,
        load_whole_code_lines=args.legacy,
    )

    remove_common_path_prefix = args.export_for_coverview
    if args.no_shorten_paths:
        remove_common_path_prefix = False

    for trace_data in trace_data_per_file:
        coverage_config.aggregate_coverage(trace_data)
    printed_report = coverage_config.get_printed_report(
        args.legacy,
        remove_common_path_prefix=remove_common_path_prefix
    )

    if args.coverage_output != None:
        with open(args.coverage_output, 'w') as coverage_output:
            if args.export_for_coverview:
                archive_created = coverview_integration.create_coverview_archive(
                    coverage_output,
                    coverage_config,
                    args.coverview_config,
                    tests_as_total=args.tests_as_total,
                    warning_threshold=args.warning_threshold,
                    remove_common_path_prefix=remove_common_path_prefix,
                )
                if not archive_created:
                    sys.exit(1)
            else:
                for line in printed_report:
                    coverage_output.write(f"{line}\n")
    else:
        for line in printed_report:
            print(line)


def find_llvm_disas() -> str:
    p = platform.system()
    if p == 'Darwin':
        ext = '.dylib'
    elif p == 'Windows':
        ext = '.dll'
    else:
        ext = '.so'

    # In portable packages, the name does not contain 'aarch64', so handle both cases, trying the
    # aarch64 version first.
    lib_names = ['libllvm-disas' + ext]

    if platform.uname().machine.lower() in ('arm64', 'aarch64'):
        lib_names.insert(0, 'libllvm-disas-aarch64' + ext)

    lib_search_paths = [
        os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir, os.pardir, os.pardir, "lib", "resources", "llvm"),
        os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir, os.pardir, os.pardir, "bin"),
        os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir, os.pardir, os.pardir),
        os.path.dirname(os.path.realpath(__file__)), 
        os.getcwd()
    ]

    llvm_disas_path = None

    for search_path, lib_name in itertools.product(lib_search_paths, lib_names):
        lib_path = os.path.join(search_path, lib_name)
        if os.path.isfile(lib_path):
            llvm_disas_path = lib_path
            break

    if llvm_disas_path is None:
        raise FileNotFoundError('Could not find ' + " or ".join(lib_names) + ' in any of the following locations: ' + ', '.join([os.path.abspath(path) for path in lib_search_paths]))
    
    return llvm_disas_path

def main():
    parser = argparse.ArgumentParser(description="Renode's ExecutionTracer binary format reader")
    parser.add_argument("--debug", default=False, action="store_true", help="enable additional debug logs to stdout")
    parser.add_argument("--decompress", action="store_true", default=False,
        help="decompress trace file, without the flag decompression is enabled based on a file extension")
    parser.add_argument("--force-disable-decompression", action="store_true", default=False, help="never attempt to decompress the trace file")

    subparsers = parser.add_subparsers(title='subcommands', dest='subcommands', required=True)
    trace_parser = subparsers.add_parser('inspect', help='Inspect the binary trace format')
    trace_parser.add_argument("files", nargs='+', help="binary trace files")

    trace_parser.add_argument("--disassemble", action="store_true", default=False)
    trace_parser.add_argument("--llvm-disas-path", default=None, help="path to libllvm-disas library")

    cov_parser = subparsers.add_parser('coverage', help='Generate coverage reports')
    cov_parser.add_argument("files", nargs='+', help="binary trace files")

    cov_parser.add_argument("--binary", dest='coverage_binary', required=True, default=None, type=argparse.FileType('rb'), help="path to an ELF file with DWARF data")
    cov_parser.add_argument("--sources", dest='coverage_code', default=None, nargs='+', type=str, help="path to a (list of) source file(s)")
    cov_parser.add_argument("--output", dest='coverage_output', default=None, type=str, help="path to the output coverage file")
    cov_parser.add_argument("--legacy", default=False, action="store_true", help="Output data in a legacy text-based format")
    cov_parser.add_argument("--export-for-coverview", default=False, action="store_true", help="Pack data to a format compatible with the Coverview project (https://github.com/antmicro/coverview)")
    cov_parser.add_argument("--coverview-config", default=None, type=str, help="Provide parameters for Coverview integration configuration JSON")
    cov_parser.add_argument("--print-unmatched-address", default=False, action="store_true", help="Print addresses not matched to any source lines")
    cov_parser.add_argument("--sub-source-path", default=[], nargs='*', action='extend', type=dwarf.PathSubstitution.from_arg, help="Substitute a part of sources' path. Format is: old_path:new_path")
    cov_parser.add_argument("--lazy-line-cache", default=False, action="store_true", help="Disable line to address eager cache generation. For big programs, reduce memory usage, but process traces much slower")
    cov_parser.add_argument("--no-shorten-paths", default=False, action="store_true", help="Disable removing common path prefix from coverage output. Only relevant with '--export-for-coverview'")
    cov_parser.add_argument("--tests-as-total", default=False, action="store_true", help="Show executed tests out of total tests in line coverage in coverview. Only relevant with '--export-for-coverview'")
    cov_parser.add_argument("--warning-threshold", required=False, help="Set warning threshold for line coverage in coverview. Only relevant with '--export-for-coverview'")
    args = parser.parse_args()

    # Look for the libllvm-disas library in default location
    if args.subcommands == 'inspect' and args.disassemble and args.llvm_disas_path is None:
        args.llvm_disas_path = find_llvm_disas()

    try:
        with contextlib.ExitStack() as stack:
            files = []
            for file in args.files:
                _, file_extension = os.path.splitext(file)
                if (args.decompress or file_extension == ".gz") and not args.force_disable_decompression:
                    files.append(stack.enter_context(gzip.open(file, "rb")))
                else:
                    files.append(stack.enter_context(open(file, "rb")))

            if args.subcommands == 'coverage':
                trace_data_per_file = [read_file(file, False, None) for file in files]
            else:
                trace_data_per_file = [read_file(file, args.disassemble, args.llvm_disas_path) for file in files]

            if args.subcommands == 'coverage':
                if args.export_for_coverview:
                    if args.legacy:
                        print("'--export-for-coverview' implies LCOV-compatible format")
                        args.legacy = False
                    if not args.coverage_output:
                        raise ValueError("Specify a file with '--output' when packing an archive for Coverview")

                handle_coverage(args, trace_data_per_file)
            else:
                for trace_data in trace_data_per_file:
                    for entry in trace_data:
                        print(trace_data.format_entry(entry))
                    print()
    except BrokenPipeError:
        # Avoid crashing when piping the results e.g. to less
        sys.exit(0)
    except (ValueError, RuntimeError) as err:
        sys.exit(f"Error during execution: {err}")
    except (FileNotFoundError, InvalidFileFormatException) as err:
        sys.exit(f"Error while loading file: {err}")
    except KeyboardInterrupt:
        sys.exit(1)

if __name__ == "__main__":
    main()
