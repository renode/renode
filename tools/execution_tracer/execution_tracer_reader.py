#!/usr/bin/env python3
import argparse
import platform
import sys
import os
import gzip
from enum import Enum

from ctypes import cdll, c_char_p, POINTER, c_void_p, c_ubyte, c_uint64, c_byte, c_size_t, cast


FILE_SIGNATURE = b"ReTrace"
FILE_VERSION = b"\x02"
HEADER_LENGTH = 10
MEMORY_ACCESS_LENGTH = 9
RISCV_VECTOR_CONFIGURATION_LENGTH = 16


class AdditionalDataType(Enum):
    Empty = 0
    MemoryAccess = 1
    RiscVVectorConfiguration = 2


class MemoryAccessType(Enum):
    MemoryIORead = 0
    MemoryIOWrite = 1
    MemoryRead = 2
    MemoryWrite = 3
    InsnFetch = 4

class Header():
    def __init__(self, pc_length, has_opcodes, extra_length=0, uses_thumb_flag=False, triple_and_model=None):
        self.pc_length = pc_length
        self.has_opcodes = has_opcodes
        self.extra_length = extra_length
        self.uses_thumb_flag = uses_thumb_flag
        self.triple_and_model = triple_and_model

    def __str__(self):
        return "Header: pc_length: {}, has_opcodes: {}, extra_length: {}, uses_thumb_flag: {}, triple_and_model: {}".format(
            self.pc_length, self.has_opcodes, self.extra_length, self.uses_thumb_flag, self.triple_and_model)


def read_header(file):
    if file.read(len(FILE_SIGNATURE)) != FILE_SIGNATURE:
        raise InvalidFileFormatException("File signature isn't detected.")

    version = file.read(1)
    if version != FILE_VERSION:
        raise InvalidFileFormatException("Unsuported file format version")

    pc_length_raw = file.read(1)
    opcodes_raw = file.read(1)
    if len(pc_length_raw) != 1 or len(opcodes_raw) != 1:
        raise InvalidFileFormatException("Invalid file header")

    if opcodes_raw[0] == 0:
        return Header(pc_length_raw[0], False, 0, False, None)
    elif opcodes_raw[0] == 1:
        uses_thumb_flag_raw = file.read(1)
        identifier_length_raw = file.read(1)
        if len(uses_thumb_flag_raw) != 1 or len(identifier_length_raw) != 1:
            raise InvalidFileFormatException("Invalid file header")
        
        uses_thumb_flag = uses_thumb_flag_raw[0] == 1
        identifier_length = identifier_length_raw[0]
        triple_and_model_raw = file.read(identifier_length)
        if len(triple_and_model_raw) != identifier_length:
            raise InvalidFileFormatException("Invalid file header")
            
        triple_and_model = triple_and_model_raw.decode("utf-8")
        extra_length = 2 + identifier_length

        return Header(pc_length_raw[0], True, extra_length, uses_thumb_flag, triple_and_model)
    else:
        raise InvalidFileFormatException("Invalid opcodes field at file header")


def read_file(file, disassemble, llvm_disas_path):
    header = read_header(file)
    return TraceData(file, header, disassemble, llvm_disas_path)


def bytes_to_hex(bytes, zero_padded=True):
    integer = int.from_bytes(bytes, byteorder="little", signed=False)
    format_string = "0{}X".format(len(bytes)*2) if zero_padded else "X"
    return "0x{0:{fmt}}".format(integer, fmt=format_string)


class TraceData:
    pc_length = 0
    has_opcodes = False
    file = None
    disassembler = None
    disassembler_thumb = None
    thumb_mode = False
    instructions_left_in_block = 0

    def __init__(self, file, header, disassemble, llvm_disas_path):
        self.file = file
        self.pc_length = int(header.pc_length)
        self.has_pc = (self.pc_length != 0)
        self.has_opcodes = bool(header.has_opcodes)
        self.extra_length = header.extra_length
        self.uses_thumb_flag = header.uses_thumb_flag
        self.triple_and_model = header.triple_and_model
        self.disassemble = disassemble
        if self.disassemble:
            triple, model = header.triple_and_model.split(" ")
            self.disassembler = LLVMDisassembler(triple, model, llvm_disas_path)
            if self.uses_thumb_flag:
                self.disassembler_thumb = LLVMDisassembler("thumb", model, llvm_disas_path)

    def __iter__(self):
        self.file.seek(HEADER_LENGTH + self.extra_length, 0)
        return self

    def __next__(self):
        additional_data = []

        if self.uses_thumb_flag and self.instructions_left_in_block == 0:
            thumb_flag_raw = self.file.read(1)
            if len(thumb_flag_raw) != 1:
                # No more data frames to read
                raise StopIteration

            self.thumb_mode = thumb_flag_raw[0] == 1
            
            block_length_raw = self.file.read(8)
            if len(block_length_raw) != 8:
                raise InvalidFileFormatException("Unexpected end of file")
            
            # The `instructions_left_in_block` counter is kept only for traces produced by cores that can switch between ARM and Thumb mode.
            self.instructions_left_in_block = int.from_bytes(block_length_raw, byteorder="little", signed=False)

        if self.uses_thumb_flag:
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

            try:
                additional_data_type = AdditionalDataType(self.file.read(1)[0])
            except IndexError:
                break
        return (pc, opcode, additional_data, self.thumb_mode)

    def parse_memory_access_data(self):
        data = self.file.read(MEMORY_ACCESS_LENGTH)
        if len(data) != MEMORY_ACCESS_LENGTH:
            raise InvalidFileFormatException("Unexpected end of file")
        type = MemoryAccessType(data[0])
        address = bytes_to_hex(data[1:])

        return f"{type.name} with address {address}"

    def parse_riscv_vector_configuration_data(self):
        data = self.file.read(RISCV_VECTOR_CONFIGURATION_LENGTH)
        if len(data) != RISCV_VECTOR_CONFIGURATION_LENGTH:
            raise InvalidFileFormatException("Unexpected end of file")
        vl = bytes_to_hex(data[0:8], zero_padded=False)
        vtype = bytes_to_hex(data[8:16], zero_padded=False)
        return f"Vector configured to VL: {vl}, VTYPE: {vtype}"

    def format_entry(self, entry):
        (pc, opcode, additional_data, thumb_mode) = entry
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
            disas = self.disassembler_thumb if thumb_mode else self.disassembler
            _, instruction = disas.get_instruction(opcode)
            output += " " + instruction.decode("utf-8")

        if len(additional_data) > 0:
            output += "\n" + "\n".join(additional_data)

        return output


class InvalidFileFormatException(Exception):
    pass


class LLVMDisassembler():
    def __init__(self, triple, cpu, llvm_disas_path):
        try:
            self.lib = cdll.LoadLibrary(llvm_disas_path)
        except OSError:
            raise Exception('Could not find valid `libllvm-disas` library. Please specify the correct path with the --llvm-disas-path argument.')

        self.__init_library()

        self._context = self.lib.llvm_create_disasm_cpu(c_char_p(triple.encode('utf-8')), c_char_p(cpu.encode('utf-8')))
        if not self._context:
            raise Exception('CPU or triple name not detected by LLVM. Disassembling will not be possible.')

    def __del__(self):
        if  hasattr(self, '_context'):
            self.lib.llvm_disasm_dispose(self._context)

    def __init_library(self):
        self.lib.llvm_create_disasm_cpu.argtypes = [c_char_p, c_char_p]
        self.lib.llvm_create_disasm_cpu.restype = POINTER(c_void_p)

        self.lib.llvm_disasm_dispose.argtypes = [POINTER(c_void_p)]

        self.lib.llvm_disasm_instruction.argtypes = [POINTER(c_void_p), POINTER(c_ubyte), c_uint64, c_char_p, c_size_t]
        self.lib.llvm_disasm_instruction.restype = c_size_t

    def get_instruction(self, opcode):
        opcode_buf = cast(c_char_p(opcode), POINTER(c_ubyte))
        disas_str = cast((c_byte * 1024)(), c_char_p)

        bytes_read = self.lib.llvm_disasm_instruction(self._context, opcode_buf, c_uint64(len(opcode)), disas_str, 1024)

        return (bytes_read, disas_str.value)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Renode's ExecutionTracer binary format reader")
    parser.add_argument("file", help="binary file")
    parser.add_argument("-d", action="store_true", default=False,
        help="decompress file, without the flag decompression is enabled based on a file extension")
    parser.add_argument("--force-disable-decompression", action="store_true", default=False)

    parser.add_argument("--disassemble", action="store_true", default=False)
    parser.add_argument("--llvm_disas_path", default=None, help="path to libllvm-disas library")

    args = parser.parse_args()

    # Look for the libllvm-disas library in default location
    if args.disassemble and args.llvm_disas_path == None:
        p = platform.system()
        if p == 'Darwin':
            ext = '.dylib'
        elif p == 'Windows':
            ext = '.dll'
        else:
            ext = '.so'

        lib_name = 'libllvm-disas' + ext

        lib_search_paths = [
            os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir, os.pardir, "lib", "resources", "llvm"), 
            os.path.dirname(os.path.realpath(__file__)), 
            os.getcwd()
        ]

        for search_path in lib_search_paths:
            lib_path = os.path.join(search_path, lib_name)
            if os.path.isfile(lib_path):
                args.llvm_disas_path = lib_path
                break

        if args.llvm_disas_path == None:
            raise Exception('Could not find ' + lib_name + ' in any of the following locations: ' + ', '.join([os.path.abspath(path) for path in lib_search_paths]))

    try:        
        filename, file_extension = os.path.splitext(args.file)        
        if (args.d or file_extension == ".gz") and not args.force_disable_decompression:
            file_open = gzip.open
        else:
            file_open = open

        with file_open(args.file, "rb") as file:
            trace_data = read_file(file, args.disassemble, args.llvm_disas_path)
            for entry in trace_data:
                print(trace_data.format_entry(entry))
    except InvalidFileFormatException as err:
        sys.exit(f"Error: {err}")
    except KeyboardInterrupt:
        sys.exit(1)
    except Exception as err:
        sys.exit(err)