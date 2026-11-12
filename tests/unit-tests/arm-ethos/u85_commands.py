"""Symbolic U85 command encoding for the register-level Robot tests.

Command IDs and fields follow the U85 TRM, sections 3.10 and 3.11 (r0p0, issue 05),
Unlike Vela's emitter, preserve every write, including invalid test settings.
"""

from enum import IntEnum, IntFlag

from robot.api.deco import keyword

ROBOT_AUTO_KEYWORDS = False


class Cmd0(IntEnum):
    OP_STOP = 0x000
    OP_IRQ = 0x001
    OP_CONV = 0x002
    OP_DEPTHWISE = 0x003
    OP_POOL = 0x005
    OP_ELEMENTWISE = 0x006
    OP_RESIZE = 0x007
    OP_DMA_START = 0x010
    OP_DMA_WAIT = 0x011
    OP_KERNEL_WAIT = 0x012
    OP_PMU_MASK = 0x013
    SET_IFM_PAD_TOP = 0x100
    SET_IFM_PAD_LEFT = 0x101
    SET_IFM_PAD_RIGHT = 0x102
    SET_IFM_PAD_BOTTOM = 0x103
    SET_IFM_DEPTH_M1 = 0x104
    SET_IFM_PRECISION = 0x105
    SET_IFM_UPSCALE = 0x107
    SET_IFM_BROADCAST = 0x108
    SET_IFM_ZERO_POINT = 0x109
    SET_IFM_WIDTH0_M1 = 0x10A
    SET_IFM_HEIGHT0_M1 = 0x10B
    SET_IFM_HEIGHT1_M1 = 0x10C
    SET_IFM_REGION = 0x10F
    SET_OFM_WIDTH_M1 = 0x111
    SET_OFM_HEIGHT_M1 = 0x112
    SET_OFM_DEPTH_M1 = 0x113
    SET_OFM_PRECISION = 0x114
    SET_OFM_BLK_WIDTH_M1 = 0x115
    SET_OFM_BLK_HEIGHT_M1 = 0x116
    SET_OFM_BLK_DEPTH_M1 = 0x117
    SET_OFM_ZERO_POINT = 0x118
    SET_OFM_WIDTH0_M1 = 0x11A
    SET_OFM_HEIGHT0_M1 = 0x11B
    SET_OFM_HEIGHT1_M1 = 0x11C
    SET_OFM_REGION = 0x11F
    SET_KERNEL_WIDTH_M1 = 0x120
    SET_KERNEL_HEIGHT_M1 = 0x121
    SET_KERNEL_STRIDE = 0x122
    SET_ACC_FORMAT = 0x124
    SET_ACTIVATION = 0x125
    SET_ACTIVATION_MIN = 0x126
    SET_ACTIVATION_MAX = 0x127
    SET_WEIGHT_REGION = 0x128
    SET_SCALE_REGION = 0x129
    SET_RESIZE_X_SCALE_N_M1 = 0x12A
    SET_RESIZE_Y_SCALE_N_M1 = 0x12B
    SET_RESIZE_X_OFFSET = 0x12C
    SET_RESIZE_Y_OFFSET = 0x12D
    SET_WEIGHT_FORMAT = 0x12E
    SET_BLOCKDEP = 0x12F
    SET_DMA0_SRC_REGION = 0x130
    SET_DMA0_DST_REGION = 0x131
    SET_DMA0_SIZE0 = 0x132
    SET_DMA0_SIZE1 = 0x133
    SET_DMA0_IDX_REGION = 0x134
    SET_IFM2_BROADCAST = 0x180
    SET_IFM2_PRECISION = 0x185
    SET_IFM2_ZERO_POINT = 0x189
    SET_IFM2_WIDTH0_M1 = 0x18A
    SET_IFM2_HEIGHT0_M1 = 0x18B
    SET_IFM2_HEIGHT1_M1 = 0x18C
    SET_IFM2_REGION = 0x18F


class Cmd1(IntEnum):
    SET_IFM_BASE0 = 0x000
    SET_IFM_BASE1 = 0x001
    SET_IFM_BASE2 = 0x002
    SET_IFM_BASE3 = 0x003
    SET_IFM_STRIDE_X = 0x004
    SET_IFM_STRIDE_Y = 0x005
    SET_IFM_STRIDE_C = 0x006
    SET_OFM_BASE0 = 0x010
    SET_OFM_BASE1 = 0x011
    SET_OFM_BASE2 = 0x012
    SET_OFM_BASE3 = 0x013
    SET_OFM_STRIDE_X = 0x014
    SET_OFM_STRIDE_Y = 0x015
    SET_OFM_STRIDE_C = 0x016
    SET_WEIGHT_BASE = 0x020
    SET_WEIGHT_LENGTH = 0x021
    SET_SCALE_BASE = 0x022
    SET_SCALE_LENGTH = 0x023
    SET_OFM_SCALE = 0x024
    SET_IFM_SCALE = 0x025
    SET_IFM2_SCALE = 0x026
    SET_OP_SCALAR = 0x027
    SET_DMA0_SRC = 0x030
    SET_DMA0_DST = 0x031
    SET_DMA0_LEN = 0x032
    SET_DMA0_SRC_STRIDE0 = 0x033
    SET_DMA0_SRC_STRIDE1 = 0x034
    SET_DMA0_DST_STRIDE0 = 0x035
    SET_DMA0_DST_STRIDE1 = 0x036
    SET_DMA0_IDX = 0x037
    SET_DMA0_IDX_MAX = 0x038
    SET_DMA0_IDX_SKIP1 = 0x039
    SET_IFM2_BASE0 = 0x080
    SET_IFM2_BASE1 = 0x081
    SET_IFM2_BASE2 = 0x082
    SET_IFM2_BASE3 = 0x083
    SET_IFM2_STRIDE_X = 0x084
    SET_IFM2_STRIDE_Y = 0x085
    SET_IFM2_STRIDE_C = 0x086
    SET_WEIGHT1_BASE = 0x090
    SET_WEIGHT1_LENGTH = 0x091
    SET_WEIGHT2_BASE = 0x092
    SET_WEIGHT2_LENGTH = 0x093
    SET_WEIGHT3_BASE = 0x094
    SET_WEIGHT3_LENGTH = 0x095
    SET_RESIZE_X_STEP = 0x096
    SET_RESIZE_Y_STEP = 0x097
    OP_BRANCH = 0x100


class IfmPrecision(IntEnum):
    U8 = 0
    S8 = 1
    U16 = 4
    S16 = 5
    U32 = 8
    S32 = 9
    U64 = 12
    S64 = 13


class OfmPrecision(IntEnum):
    U8 = 0
    S8 = 1
    U16 = 2
    S16 = 3
    U32 = 4
    S32 = 5
    U64 = 6
    S64 = 7


class Layout(IntEnum):
    NHWC = 0
    NHCWB16 = 1


class ActivationReverse(IntEnum):
    NONE = 0
    H = 1
    W = 2
    C = 3


class ActivationTranspose(IntEnum):
    HWC = 0
    WHC = 1
    HCW = 2
    WCH = 3
    CHW = 6
    CWH = 7


class Storage(IntEnum):
    TILE2X2 = 0
    TILE3X1 = 1
    CHAINED = 2
    NONE = 3


class OfmScaleMode(IntEnum):
    PER_CHANNEL = 0
    GLOBAL = 1


class IfmRounding(IntEnum):
    DOUBLE_SYMMETRIC = 0
    NATURAL = 1


class Rounding(IntEnum):
    DOUBLE_SYMMETRIC = 0
    NATURAL = 1
    DOUBLE_ASYMMETRIC = 2
    SYMMETRIC = 3
    TRUNCATE_TO_ZERO = 4
    TRUNCATE_TO_LOWER = 5


class Elementwise(IntEnum):
    MUL = 0b000000
    ADD = 0b000001
    SUB = 0b000010
    MIN = 0b000011
    MAX = 0b000100
    LRELU = 0b000101
    ABS = 0b000110
    CLZ = 0b000111
    SHR = 0b001000
    SHL = 0b001001
    LSR = 0b001010
    DIV = 0b001011
    CMP_EQ = 0b010000
    CMP_NE = 0b010001
    CMP_GE = 0b010010
    CMP_GT = 0b010011
    AND = 0b100001
    OR = 0b100010
    XOR = 0b100011
    NOT = 0b100100
    AND_NOT = 0b101010


class Pooling(IntEnum):
    MAX = 0
    AVERAGE = 1
    REDUCE_SUM = 2
    SUM = 3
    NONE = 4
    MIN = 5
    ARGMAX_X = 6
    ARGMAX_Y = 7


class Resize(IntEnum):
    BILINEAR = 0
    REPLICATE = 1
    NEAREST = 2


class Upscale(IntEnum):
    NONE = 0
    NEAREST = 1
    INSERT_ZEROS = 2


class Accumulator(IntEnum):
    INT32 = 0
    INT48 = 1


class AccumulatorInput(IntEnum):
    RESET = 0
    KEEP = 1
    IFM2 = 2


class AccumulatorOutput(IntEnum):
    ENABLE = 0
    DISABLE = 1


class Microblock(IntEnum):
    U1X1 = 0
    U1X2 = 1
    U1X4 = 2
    U2X2 = 3
    U2X4 = 4
    U4X4 = 5


class WeightOrder(IntEnum):
    DEPTH_FIRST = 0
    PART_KERNEL_FIRST = 1


class KernelDilation(IntEnum):
    NONE = 0
    X2 = 1


class KernelDecomposition(IntEnum):
    D8X8 = 0
    D4X4 = 1


class WeightFormat(IntEnum):
    SWD = 0
    FWD = 1


class WeightSparsity(IntEnum):
    NONE = 0
    SPARSE_2_4 = 1


class Broadcast(IntFlag):
    NONE = 0b0000
    H = 0b0001
    W = 0b0010
    HW = H | W
    C = 0b0100
    CH = C | H
    CW = C | W
    CWH = C | W | H
    SCALAR = 0b1000


class ActivationFunction(IntEnum):
    NONE = 0
    U8_U8 = 1
    S8_S8 = 4
    S8_S16 = 5
    S8_S32 = 7
    S16_S16 = 8
    S16_S32 = 9
    TANH = 10
    SIGMOID = 11


class ClipRange(IntEnum):
    B16 = 0
    NONE = 1


class DmaRegionMode(IntEnum):
    EXTERNAL = 0
    INTERNAL = 1


class DmaIndexMode(IntEnum):
    DISABLED = 0
    ENABLED = 1


class DmaStrideMode(IntEnum):
    D1 = 0
    D2 = 1
    D3 = 2


class BranchCondition(IntEnum):
    ALWAYS = 0
    RF_TRUE = 1


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
    """Encode a 40-bit address or signed stride (U85 Table 3-185)."""
    value = int(value)
    return cmd1(command, value, (value >> 32) & 0xFF)


def scale(command, value, shift=0, double_round=0, rounding=0):
    parameter = (
        (int(shift) & 0x3F)
        | ((int(double_round) & 0x1F) << 6)
        | ((int(rounding) & 0x7) << 13)
    )
    return cmd1(command, value, parameter)


def resize_step(command, one_step_int=0, one_step_mod=0, block_step_int=0, block_step_mod=0):
    """Encode NPU_SET_RESIZE_{X,Y}_STEP (U85 TRM 3.11.38/3.11.39)."""
    parameter = (int(one_step_int) & 0xF) | ((int(block_step_int) & 0x7FF) << 4)
    payload = (int(one_step_mod) & 0x7FF) | ((int(block_step_mod) & 0x7FF) << 16)
    return cmd1(command, payload, parameter)


def ifm_precision(precision, layout=Layout.NHWC, storage=Storage.TILE2X2):
    return int(precision) | (int(layout) << 6) | (int(storage) << 14)


def ofm_precision(precision, layout=Layout.NHWC, global_scale=False, storage=Storage.TILE2X2):
    return (
        int(precision)
        | (int(layout) << 6)
        | (int(global_scale) << 8)
        | (int(storage) << 14)
    )


def activation(function=ActivationFunction.NONE, table=0, clip=ClipRange.B16):
    return int(function) | ((int(table) & 0x7) << 5) | (int(clip) << 12)


def broadcast(height=False, width=False, channel=False, scalar=False):
    if scalar:
        return int(Broadcast.SCALAR)
    return (
        (int(Broadcast.H) if height else 0)
        | (int(Broadcast.W) if width else 0)
        | (int(Broadcast.C) if channel else 0)
    )


def scalar(value):
    return cmd1(Cmd1.SET_OP_SCALAR, value)


def stop(mask=0xFFFF):
    return cmd0(Cmd0.OP_STOP, mask)


@keyword
def build_npu_commands(*commands):
    """Build a U85 command stream from a sequence of commands.

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


@keyword
def pack_npu_words(values, element_bytes: int = 1):
    """Flatten nested integer values into little-endian 32-bit words.

    Values may be signed or unsigned; the final word is zero-padded.
    For example, [[-8, 8], [24, 40]] becomes [0x281808F8].
    """
    if element_bytes not in (1, 2, 4, 8):
        raise ValueError("Element size must be 1, 2, 4, or 8 bytes")

    def pack(value):
        if isinstance(value, (list, tuple)):
            return b"".join(pack(item) for item in value)
        return value.to_bytes(element_bytes, "little", signed=value < 0)

    data = pack(values)
    return [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]
