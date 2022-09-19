#!/usr/bin/env python3
import argparse
import sys, os
import gzip

FILE_SIGNATURE = b"ReTrace"
FILE_VERSION = b"\x01"
HEADER_LENGTH = 10


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


def bytes_to_hex(bytes):
    integer = int.from_bytes(bytes, byteorder="little", signed=False)
    return "0x{0:0{width}x}".format(integer, width=len(bytes)*2)


class TraceData:
    pc_length = 0
    has_opcodes = False
    file = None

    def __init__(self, file, pc_length, has_opcodes):
        self.file = file
        self.pc_length = int(pc_length)
        self.has_opcodes = bool(has_opcodes)

    def __iter__(self):
        self.file.seek(HEADER_LENGTH, 0)
        return self

    def __next__(self):
        pc = self.file.read(self.pc_length)
        opcode_length = self.file.read(int(self.has_opcodes))
        if not pc and not opcode_length:
            raise StopIteration
        if len(pc) != self.pc_length or len(opcode_length) != int(self.has_opcodes):
            raise InvalidFileFormatException("Unexpected end of file")

        if self.has_opcodes:
            opcode_length = opcode_length[0]
            opcode = self.file.read(opcode_length)
            if len(opcode) != opcode_length:
                raise InvalidFileFormatException("Unexpected end of file")
        else:
            opcode = b""

        return (pc, opcode)

    def format_entry(self, entry):
        (pc, opcode) = entry
        if self.pc_length:
            pc_str = bytes_to_hex(pc)
        if self.has_opcodes:
            opcode_str = bytes_to_hex(opcode)

        if self.pc_length and self.has_opcodes:
            return f"{pc_str}: {opcode_str}"
        elif self.pc_length:
            return pc_str
        elif self.has_opcodes:
            return opcode_str
        else:
            return ""


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
