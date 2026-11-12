"""Symbolic U55 command encoding for the register-level Robot tests.

Command IDs and fields follow U55 TRM tables 4-112/113,
and Vela 4.2.0's ethos_u55_regs and CommandStreamEmitter.
Unlike Vela's emitter, preserve every write, including invalid test settings.
"""

from enum import IntEnum, IntFlag

from robot.api.deco import keyword

ROBOT_AUTO_KEYWORDS = False


class Cmd0(IntEnum):
    OP_STOP = 0x000
    OP_IRQ = 0x001
    OP_POOL = 0x005
    OP_ELEMENTWISE = 0x006
    OP_DMA_START = 0x010
    SET_IFM_DEPTH_M1 = 0x104
    SET_IFM_PRECISION = 0x105
    SET_IFM_UPSCALE = 0x107
    SET_IFM_ZERO_POINT = 0x109
    SET_IFM_WIDTH0_M1 = 0x10A
    SET_IFM_HEIGHT0_M1 = 0x10B
    SET_IFM_IB_END = 0x10D
    SET_OFM_WIDTH_M1 = 0x111
    SET_OFM_HEIGHT_M1 = 0x112
    SET_OFM_DEPTH_M1 = 0x113
    SET_OFM_PRECISION = 0x114
    SET_OFM_ZERO_POINT = 0x118
    SET_OFM_WIDTH0_M1 = 0x11A
    SET_OFM_HEIGHT0_M1 = 0x11B
    SET_OFM_HEIGHT1_M1 = 0x11C
    SET_KERNEL_STRIDE = 0x122
    SET_PARALLEL_MODE = 0x123  # Reserved on the single-core U55.
    SET_ACC_FORMAT = 0x124
    SET_ACTIVATION = 0x125
    SET_ACTIVATION_MIN = 0x126
    SET_ACTIVATION_MAX = 0x127
    SET_AB_START = 0x12D
    SET_DMA0_DST_REGION = 0x131
    SET_IFM2_BROADCAST = 0x180
    SET_IFM2_SCALAR = 0x181
    SET_IFM2_PRECISION = 0x185
    SET_IFM2_ZERO_POINT = 0x189
    SET_IFM2_WIDTH0_M1 = 0x18A
    SET_IFM2_IB_START = 0x18D


class Cmd1(IntEnum):
    SET_IFM_BASE0 = 0x000
    SET_IFM_STRIDE_X = 0x004
    SET_IFM_STRIDE_Y = 0x005
    SET_IFM_STRIDE_C = 0x006
    SET_OFM_BASE0 = 0x010
    SET_OFM_BASE1 = 0x011
    SET_OFM_STRIDE_X = 0x014
    SET_OFM_STRIDE_Y = 0x015
    SET_OFM_SCALE = 0x024
    SET_OPA_SCALE = 0x025
    SET_OPB_SCALE = 0x026
    SET_DMA0_SRC = 0x030
    SET_DMA0_DST = 0x031
    SET_DMA0_LEN = 0x032
    SET_IFM2_BASE0 = 0x080
    SET_IFM2_STRIDE_X = 0x084


class IfmPrecision(IntEnum):
    U8 = 0
    S8 = 1
    U16 = 4
    S16 = 5
    S32 = 9


class OfmPrecision(IntEnum):
    U8 = 0
    S8 = 1
    U16 = 2
    S16 = 3
    S32 = 5


class Layout(IntEnum):
    NHWC = 0
    NHCWB16 = 1
    RESERVED = 2


class InputScale(IntEnum):
    BITS16 = 0
    OPA32 = 1
    OPB32 = 2


class InputRounding(IntEnum):
    DOUBLE = 0
    RESERVED_1 = 1
    NATURAL = 2
    RESERVED_3 = 3


class Rounding(IntEnum):
    TFL = 0
    TRUNCATE = 1
    NATURAL = 2
    RESERVED = 3


class Elementwise(IntEnum):
    MUL = 0
    ADD = 1
    ABS = 6
    CLZ = 7
    SHR = 8


class Pooling(IntEnum):
    MAX = 0
    AVERAGE = 1
    REDUCE_SUM = 2


class Upscale(IntEnum):
    NONE = 0
    NEAREST = 1
    INSERT_ZEROS = 2


class Accumulator(IntEnum):
    INT32 = 0
    INT40 = 1
    FLOAT_S5_10 = 2


class ClipRange(IntEnum):
    OFM_PRECISION = 0
    INT8 = 3
    INT16 = 5


class Broadcast(IntFlag):
    SCALAR = 1 << 7


class DmaRegion(IntFlag):
    INTERNAL = 1 << 8


def cmd0(command, parameter=0):
    """One command word with a signed/unsigned 16-bit parameter."""
    return [int(command) | ((int(parameter) & 0xFFFF) << 16)]


def cmd1(command, payload, parameter=0):
    """A Payload32 command; parameter carries extension bits or a scale shift."""
    return [
        int(command) | 0x4000 | ((int(parameter) & 0xFFFF) << 16),
        int(payload) & 0xFFFFFFFF,
    ]


def address(command, value):
    """Encode a 48-bit address, signed stride, or DMA length (Table 4-113)."""
    return cmd1(command, value, int(value) >> 32)


def scale(command, value, shift=0):
    return cmd1(command, value, shift)


def ifm_precision(
    precision, layout=Layout.NHWC, scale_mode=InputScale.BITS16, rounding=InputRounding.DOUBLE
):
    return int(precision) | (int(layout) << 6) | (int(scale_mode) << 8) | (int(rounding) << 14)


def ofm_precision(precision, layout=Layout.NHWC, global_scale=False, rounding=Rounding.TFL):
    return int(precision) | (int(layout) << 6) | (int(global_scale) << 8) | (int(rounding) << 14)


def activation(lut_index=None, clip=ClipRange.OFM_PRECISION):
    return (0 if lut_index is None else 0x10 + lut_index) | (int(clip) << 12)


def kernel_stride(x=1, y=1):
    return ((x - 1) & 1) | (((y - 1) & 1) << 1) | (((x - 1) >> 1) << 6) | (((y - 1) >> 1) << 9)


def stop(mask=0xFFFF):
    return cmd0(Cmd0.OP_STOP, mask)


@keyword
def build_npu_commands(*commands):
    """Build a command stream from a sequence of commands.

    Each Robot continuation cell is evaluated in this module's namespace.

    Lists such as ${INT32_WORDS} can be included. STOP is explicit
    so tests can also submit unterminated command streams.
    """
    words = []
    for index, command in enumerate(commands, start=1):
        try:
            words.extend(eval(command, globals()) if isinstance(command, str) else command)
        except Exception as error:
            raise ValueError(f"Invalid NPU command {index}: {command!r}: {error}") from error
    return words
