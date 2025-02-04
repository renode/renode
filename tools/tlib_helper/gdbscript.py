#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import ctypes
import dataclasses
import re

from enum import IntEnum, auto
from pathlib import Path


ENV_BREAKPOINT = None
MEMORY_MAPPINGS = []
CPU_POINTERS = []
GUEST_PC = None


class Disassembler:
    def __init__(self, triple, name, flags=0):
        library_path = self._get_library_path()
        assert library_path is not None, 'could not find libllvm-disas.so path'

        self._library = ctypes.CDLL(str(library_path))
        self._library.llvm_create_disasm_cpu_with_flags.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32]
        self._library.llvm_create_disasm_cpu_with_flags.restype = ctypes.c_void_p

        self._library.llvm_disasm_instruction.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint64,ctypes.c_char_p, ctypes.c_uint32]
        self._library.llvm_disasm_instruction.restype = ctypes.c_int
        self._library.llvm_disasm_dispose.argtypes = [ctypes.c_void_p]
        self._context = self._library.llvm_create_disasm_cpu_with_flags(
            triple,
            name,
            flags)
        assert self._context != 0, 'could not initialize llvm disassembler'

    @classmethod
    def _get_library_path(cls):
        if hasattr(cls, '_cached_library_path'):
            return cls._cached_library_path

        inferior = gdb.selected_inferior()
        if not inferior:
            return None

        with open(f'/proc/{inferior.pid}/cmdline', 'rb') as f:
            cmdline = f.read().split(b'\x00')
            cmdline = [arg.decode('ascii') for arg in cmdline]

        if len(cmdline) > 1 and cmdline[1].endswith('Renode.dll'):
            # NOTE: We've built Renode from source code
            start_path = Path(cmdline[1])
        else:
            # NOTE: Running from bundled binary (e.g. portable)
            start_path = Path(f'/proc/{inferior.pid}/exe').resolve()

        path = Path(start_path)
        while not (path / '.renode-root').exists():
            parent = path.parent
            if path == parent:
                return None
            path = parent

        cls._cached_library_path = path / 'lib' / 'resources' / 'llvm' / 'libllvm-disas.so'
        return cls._cached_library_path

    def __del__(self):
        self._library.llvm_disasm_dispose(self._context)
        self._context = 0

    def disassemble(self, data: bytes):
        output = bytes(256)
        op_len = self._library.llvm_disasm_instruction(
            self._context,
            data,
            len(data),
            output,
            len(output))
        return output.rstrip(b'\0').decode('ascii', 'ignore').strip(), op_len


@dataclasses.dataclass
class MemoryMapping:
    REGEX = re.compile(r'\s*0x([0-9a-f]+)\s+0x([0-9a-f]+)\s+0x([0-9a-f]+)\s+0x[0-9a-f]+\s+([^\s]{4})\s+([^\s]*)')

    start: int
    end: int
    size: int
    perms: str
    path: str

    @property
    def executable(self):
        return 'x' in self.perms

    @property
    def data(self):
        return 'rw' in self.perms

    def __post_init__(self):
        for field in dataclasses.fields(self):
            value = getattr(self, field.name)
            if field.type is int and not isinstance(value, int):
                setattr(self, field.name, int(value, 16))


class Architecture(IntEnum):
    AARCH32 = auto()
    AARCH64 = auto()
    RISCV = auto()
    XTENSA = auto()
    I386 = auto()
    UNKNOWN = auto()

    @property
    def insn_start_words(self):
        return ({
            Architecture.AARCH32: 2,
            Architecture.AARCH64: 3,
            Architecture.RISCV: 1,
            Architecture.XTENSA: 1,
            Architecture.I386: 2,
        }).get(self, 1)


def source(callable):
    """Convenience decorator for sourcing gdb commands"""
    callable()
    return callable


@source
class Renode(gdb.Command):
    """Utility functions for debugging Renode"""
    def __init__(self):
        super(self.__class__, self).__init__('renode', gdb.COMMAND_USER, prefix=True)


@source
class ConvenienceRenodeReadBytes(gdb.Function):
    def __init__(self):
        super(self.__class__, self).__init__('_renode_read_bytes')

    def invoke(self, addr, length):
        data = read_guest_bytes(int(addr), int(length))
        return gdb.Value(data, gdb.lookup_type('uint8_t').array(length - 1))


@source
class ConvenienceCpu(gdb.Function):
    def __init__(self):
        super(self.__class__, self).__init__('_cpu')

    def invoke(self, index):
        global CPU_POINTERS
        return gdb.Value(CPU_POINTERS[index]).cast(gdb.lookup_type('CPUState').pointer().pointer()).referenced_value()


@source
class RenodeReadBytes(gdb.Command):
    """Read bytes from guest memory through SystemBus

    renode read-bytes address length

    This command is wrapper over tlib_read_byte function, which
    reads bytes using SystemBus.ReadByte method"""

    def __init__(self):
        super(self.__class__, self).__init__('renode read-bytes', gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        args = gdb.string_to_argv(arg)
        gdb.execute('p/x $_renode_read_bytes(%s, %s)' % (args[0], args[1]))


@source
class RenodeNextInstruction(gdb.Command):
    """Creates a breakpoint on next guest instruction

    renode next-instruction [cpu-index]

    Creates a breakpoint on next guest instruction, potentially waiting on
    new translation block. If <cpu-index> is given, breakpoint will be on
    next instruction for given cpu. When ommited, current cpu will be used instead"""

    def __init__(self):
        super(self.__class__, self).__init__('renode next-instruction', gdb.COMMAND_USER)

    def _create_pending_breakpoint(self, cpu):
        global ENV_BREAKPOINT
        ENV_BREAKPOINT = gdb.Breakpoint(f'{cpu}->current_tb', gdb.BP_WATCHPOINT, gdb.WP_WRITE, True)

    def invoke(self, arg, from_tty):
        global GUEST_PC

        cpu = '$current_cpu'
        if arg:
            cpu = f'$_cpu({arg})'
        elif gdb.convenience_variable('current_cpu') is None:
            gdb.write(f'Could not detect active CPU. Re-run command with specified cpu-index (0-{len(CPU_POINTERS)})\n')
            return

        current_tb = get_current_tb(cpu)
        if current_tb is None:
            self._create_pending_breakpoint(cpu)
            return

        index = 0
        if GUEST_PC is not None:
            for guest_pc, _, _ in current_tb:
                if guest_pc > GUEST_PC:
                    break
                index += 1

        if index >= len(current_tb):
            self._create_pending_breakpoint(cpu)
            return

        guest, host, _ = current_tb[index]
        gdb.write(f'Creating hook on guest pc: 0x{guest:x}\n')
        gdb.execute(f'tbreak *0x{host:x}', from_tty=True)


@source
class RenodePrintTranslationBlock(gdb.Command):
    """Prints disassembly for current TranslationBlock

    renode print-tb"""

    def __init__(self):
        super(self.__class__, self).__init__('renode print-tb', gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        current_tb = get_current_tb()
        if current_tb is None:
            return

        guest_pc = GUEST_PC or int(gdb.parse_and_eval('$current_cpu->pc').const_value())

        for guest, host, _ in current_tb:
            _, instr = disassemble_instruction(guest)
            instr = instr or 'n/a'
            current_line = '=>' if guest == guest_pc else '  '
            gdb.write(f'{current_line} [0x{host:08x}] 0x{guest:08x}: {instr}\n')


def read_host_byte(ptr):
    return int(gdb.parse_and_eval(f'*(uint8_t*)0x{ptr:x}').const_value())


def read_guest_bytes(ptr, len):
    b = []
    for i in range(len):
        b.append(read_guest_byte(ptr + i))
    return bytes(b)


def read_guest_byte(ptr):
    return int(gdb.parse_and_eval(f'tlib_read_byte_callback$({ptr})').const_value())


def decode_sleb128(ptr):
    """
    This function is based on decode_sleb128 from tlib/arch/translate-all.c
    """

    val = 0
    byte, shift = 0, 0

    while True:
        byte = read_host_byte(ptr)
        ptr += 1
        val |= (byte & 0x7f) << shift
        val &= 0xffffffff
        shift += 7

        if (byte & 0x80) == 0:
            break

    if shift < 32 and (byte & 0x40) != 0:
        val |= 0xffffffff << shift
        val &= 0xffffffff

    return val, ptr


def get_current_tb(cpu=None):
    if cpu is None and gdb.convenience_variable('current_cpu') is None:
        return None

    if cpu is None:
        cpu = '$current_cpu'

    tb_defined = int(gdb.parse_and_eval(f'{cpu}->current_tb').const_value()) != 0
    if not tb_defined:
        return None

    tb_pc = int(gdb.parse_and_eval(f'{cpu}->current_tb->pc').const_value())
    host_pc = int(gdb.parse_and_eval(f'{cpu}->current_tb->tc_ptr').const_value())
    search_ptr = int(gdb.parse_and_eval(f'{cpu}->current_tb->tc_search').const_value())
    num_inst = int(gdb.parse_and_eval(f'{cpu}->current_tb->icount').const_value())

    insn_start_words = detect_architecture().insn_start_words
    data = [ tb_pc ]
    data.extend([0 for _ in range(insn_start_words - 1)])
    mapping = []

    for _ in range(num_inst):
        for j in range(insn_start_words):
            data_delta, search_ptr = decode_sleb128(search_ptr)
            data[j] += data_delta

        host_start = host_pc
        host_pc_delta, search_ptr = decode_sleb128(search_ptr)
        host_pc += host_pc_delta
        mapping.append((data[0], host_start, host_pc))

    return mapping


def get_current_guest_pc():
    current_tb = get_current_tb()
    if current_tb is None:
        return None

    current_pc = int(gdb.parse_and_eval('$pc').const_value())
    for guest, _, host_end in current_tb:
        if host_end > current_pc:
            return guest

    return None


def disassemble_instruction(ptr):
    model, triple = get_model_and_triple()
    if model is None:
        return None, None

    opcode = read_guest_bytes(ptr, 4)
    disas = Disassembler(triple.encode('ascii'), model.encode('ascii'))
    result, op_len = disas.disassemble(opcode)
    opcode = opcode[:op_len]

    return int.from_bytes(opcode, 'little'), result


def get_current_instruction():
    guest_pc = get_current_guest_pc()
    if guest_pc is None:
        return None, None, None

    opcode, instr = disassemble_instruction(guest_pc)
    if opcode is None:
        return guest_pc, None, None

    return guest_pc, opcode, instr


def detect_architecture():
    # NOTE: Check if arm
    try:
        gdb.parse_and_eval('$current_cpu->thumb')
        try:
            # NOTE: Check aarch64
            gdb.parse_and_eval('$current_cpu->aarch64')
            return Architecture.AARCH64
        except:
            return Architecture.AARCH32
    except:
        pass

    # NOTE: Check if RISC-V
    try:
        gdb.parse_and_eval('$current_cpu->mhartid')
        return Architecture.RISCV
    except:
        pass

    # NOTE: Check if xtensa
    try:
        gdb.parse_and_eval('$current_cpu->config')
        return Architecture.XTENSA
    except:
        pass

    # NOTE: Check if I386
    try:
        gdb.parse_and_eval('$current_cpu->eip')
        return Architecture.I386
    except:
        pass

    return Architecture.UNKNOWN


def get_model_and_triple():
    arch = detect_architecture()
    if arch is Architecture.UNKNOWN:
        return None, None

    if arch is Architecture.AARCH32 or arch is Architecture.AARCH64:
        this_cpu_id = int(gdb.parse_and_eval('$current_cpu->cp15.c0_cpuid').const_value())
        arm_cpu_names = gdb.parse_and_eval('arm_cpu_names')
        index = 0

        while arm_cpu_names[index]['name'] != None:
            cpu_id = int(arm_cpu_names[index]['id'].const_value())
            if cpu_id == this_cpu_id:
                model = str(arm_cpu_names[index]['name'].string())
                break
            index += 1
        else:
            return None, None

        if model == 'cortex-r52':
            triple = 'arm'
        elif arch is Architecture.AARCH64:
            triple = 'arm64'
        else:
            if 'cortex-m' in model:
                triple = 'thumb'
            else:
                triple = 'armv7a'

        if triple == 'armv7a' and int(gdb.parse_and_eval('$current_cpu->thumb').const_value()) > 0:
            triple = 'thumb'

        return model, triple

    if arch is Architecture.RISCV:
        try:
            gdb.parse_and_eval('get_reg_pointer_64')
            triple = 'riscv64'
            model = 'rv64'
        except:
            triple = 'riscv32'
            model = 'rv32'

        misa = gdb.parse_and_eval('$current_cpu->misa_mask')
        extensions = {chr(ord('a') + index) for index in range(32) if misa & (1 << index) > 0}
        extensions &= set('imafdcv')

        model += ''.join(extensions)
        return model, triple

    return None, None


def cache_memory_mappings():
    global MEMORY_MAPPINGS

    MEMORY_MAPPINGS = []
    mappings = gdb.execute('info proc mappings', from_tty=False, to_string=True)
    for line in mappings.splitlines():
        match = MemoryMapping.REGEX.match(line)
        if match is None:
            continue
        mapping = MemoryMapping(*match.groups())
        if '-Antmicro.Renode.translate-' not in mapping.path:
            continue

        MEMORY_MAPPINGS.append(mapping)
    MEMORY_MAPPINGS.sort(key=lambda m: m.path)


def update_cpu_pointers():
    global CPU_POINTERS, MEMORY_MAPPINGS

    current_cpu = int(gdb.parse_and_eval('cpu').address)
    current_cpu_objfile = gdb.current_progspace().objfile_for_address(current_cpu)
    current_mapping = next((m for m in MEMORY_MAPPINGS if m.data and current_cpu_objfile.filename == m.path), None)
    if current_mapping is None:
        return

    offset = current_cpu - current_mapping.start
    CPU_POINTERS = [m.start + offset for m in MEMORY_MAPPINGS if m.data]


def update_current_cpu_variable():
    global CPU_POINTERS, MEMORY_MAPPINGS

    if len(CPU_POINTERS) <= 1:
        # NOTE: If we are debugging single CPU platform, just fallback to cpu
        gdb.set_convenience_variable('current_cpu', gdb.parse_and_eval('cpu'))
        return

    current_pc = int(gdb.parse_and_eval('$pc').const_value())
    current_mapping = next((m for m in MEMORY_MAPPINGS if current_pc >= m.start and current_pc < m.end), None)
    if current_mapping is None:
        return

    index = next(index for index, mapping in enumerate(m for m in MEMORY_MAPPINGS if m.data) if mapping.path == current_mapping.path)
    current_cpu = gdb.Value(CPU_POINTERS[index]).cast(gdb.lookup_type('CPUState').pointer().pointer()).referenced_value()
    gdb.set_convenience_variable('current_cpu', current_cpu)


def before_prompt():
    cache_memory_mappings()
    update_cpu_pointers()
    update_current_cpu_variable()

    guest_pc, opcode, instruction = get_current_instruction()
    if guest_pc is None:
        return

    global GUEST_PC

    if guest_pc == GUEST_PC:
        return

    GUEST_PC = guest_pc
    gdb.set_convenience_variable('guest_pc', guest_pc)

    if opcode is None:
        return

    instruction = instruction or 'n/a'

    banner = '----- tlib debug ' + '-' * 20
    gdb.write(banner + '\n')
    gdb.write(f'Current PC: 0x{guest_pc:x}\n')
    gdb.write(f'Emulated instruction: {instruction} (0x{opcode:x})\n')
    gdb.write('-' * len(banner) + '\n')


def stop_event(event):
    if not isinstance(event, gdb.BreakpointEvent):
        return

    global ENV_BREAKPOINT
    is_env_breakpoint = any(bkpt == ENV_BREAKPOINT for bkpt in event.breakpoints)
    if not ENV_BREAKPOINT or not is_env_breakpoint:
        return

    # NOTE: Update current CPU variable
    update_current_cpu_variable()

    current_tb = get_current_tb()
    if current_tb is None:
        global GUEST_PC
        GUEST_PC = 0
        gdb.execute('continue')
        return

    ENV_BREAKPOINT.delete()
    ENV_BREAKPOINT = None

    guest, host, _ = current_tb[0]
    gdb.write(f'Creating hook on guest pc: 0x{guest:x}\n')
    gdb.Breakpoint(f'*0x{host:x}', gdb.BP_BREAKPOINT, temporary=True)
    gdb.execute('continue')


gdb.events.before_prompt.connect(before_prompt)
gdb.events.stop.connect(stop_event)
