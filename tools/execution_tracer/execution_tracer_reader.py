#!/usr/bin/env python3
import argparse
import sys
import os
import gzip
from enum import Enum

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
        return (pc_length_raw[0], False)
    elif opcodes_raw[0] == 1:
        return (pc_length_raw[0], True)
    else:
        raise InvalidFileFormatException("Invalid opcodes field at file header")


def read_file(file):
    (pc_length, has_opcodes) = read_header(file)
    return TraceData(file, pc_length, has_opcodes)


def bytes_to_hex(bytes, zero_padded=True):
    integer = int.from_bytes(bytes, byteorder="little", signed=False)
    format_string = "0{}X".format(len(bytes)*2) if zero_padded else "X"
    return "0x{0:{fmt}}".format(integer, fmt=format_string)


class TraceData:
    pc_length = 0
    has_opcodes = False
    file = None

    def __init__(self, file, pc_length, has_opcodes):
        self.file = file
        self.pc_length = int(pc_length)
        self.has_pc = (self.pc_length != 0)
        self.has_opcodes = bool(has_opcodes)

    def __iter__(self):
        self.file.seek(HEADER_LENGTH, 0)
        return self

    def __next__(self):
        additional_data = []

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
        return (pc, opcode, additional_data)

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
        (pc, opcode, additional_data) = entry
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

        if len(additional_data) > 0:
            output += "\n" + "\n".join(additional_data)

        return output


class InvalidFileFormatException(Exception):
    pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Renode's ExecutionTracer binary format reader")
    parser.add_argument("file", help="binary file")
    parser.add_argument("-d", action="store_true", default=False,
        help="decompress file, without the flag decompression is enabled based on a file extension")
    parser.add_argument("--force-disable-decompression", action="store_true", default=False)

    args = parser.parse_args()

    try:        
        filename, file_extension = os.path.splitext(args.file)        
        if (args.d or file_extension == ".gz") and not args.force_disable_decompression:
            file_open = gzip.open
        else:
            file_open = open

        with file_open(args.file, "rb") as file:
            trace_data = read_file(file)
            for entry in trace_data:
                print(trace_data.format_entry(entry))
    except InvalidFileFormatException as err:
        sys.exit(f"Error: {err}")
    except KeyboardInterrupt:
        sys.exit(1)
    except Exception as err:
        sys.exit(err)
