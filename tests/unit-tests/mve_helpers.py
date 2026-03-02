from collections.abc import Callable
from functools import partial
from typing import Tuple, Union


def assert_starts_with_0x_prefix(string: str):
    assert string[0:2] == "0x", f"String '{string}' must start with '0x' prefix"


def assert_is_n_chars(string: str, n: int):
    length = len(string)
    assert (
        length == n
    ), f"String '{string}' must be {n} characters long but it's {length}"


def split_n_bit_value_into_m_bit_values(n: int, m: int, value_n_bit: str) -> list[str]:
    """
    Converts a string containing an n-bit base-16 number (with 0x prefix) into
    a list of strings containing base-16 m-bit values (with 0x prefix).
    The list is ordered such that the indices correspond to lane numbers.
    """
    assert_starts_with_0x_prefix(value_n_bit)
    value_n_bit = value_n_bit[2:]
    expected_hex_chars = n // 4
    assert_is_n_chars(value_n_bit, expected_hex_chars)
    assert n % 4 == 0, f"`n` must be divisible by 4. {n} is not"
    assert m % 4 == 0, f"`m` must be divisible by 4. {m} is not"

    chars_in_m_bit_hex = m // 4
    return [
        "0x" + value_n_bit[i : i + chars_in_m_bit_hex]
        # The indexing is reversed because we place the most significant bits first in the list.
        for i in reversed(range(0, len(value_n_bit), chars_in_m_bit_hex))
    ]


def combine_n_bit_values_into_m_bit_value(
    n: int, m: int, values_n_bit: list[str]
) -> str:
    """
    Converts a list of strings containing base-16 n-bit values (with 0x prefix)
    into a string containing an m-bit base-16 number (with 0x prefix).
    The input list is expected to be ordered such that indices correspond to lane numbers.
    """
    list(map(assert_starts_with_0x_prefix, values_n_bit))
    assert m % n == 0, f"`m`={m} must be divisible by `n`, but {n} is not"
    length = len(values_n_bit)
    expected_values = m // n
    assert (
        length == expected_values
    ), f"Input list must contain {expected_values} values, but it contains {length}"
    values_n_bit = [value[2:] for value in values_n_bit]

    chars_in_n_bit_hex = n // 4
    return "0x" + "".join(
        [
            value.zfill(chars_in_n_bit_hex)
            # The values are reversed because we want to place the most significant bits
            # (i.e. the higher indices/lane numbers) first in the hexadecimal string.
            for value in reversed(values_n_bit)
        ]
    )


def prepare_vector_op(
    element_size: Union[str, int], treat_elements_as_signed: bool
) -> Tuple[Callable[[str], int], Callable[[int], str], int]:
    element_size = int(element_size)  # Robot insists on passing it as a string :(

    if treat_elements_as_signed:
        hex_to_int = lambda hexstr: twos_complement(element_size, hexstr)
        int_to_hex = lambda integer: signed_to_hex(element_size, integer)
    else:
        # AND with a mask of all 1s just to force the result into the correct range.
        # This prevents signs on unsigned results.
        hex_to_int = lambda hexstr: int(hexstr, 16) & mask(element_size)
        int_to_hex = lambda integer: hex(integer & mask(element_size))

    assert (
        128 % element_size == 0
    ), f"128 must be divisible by element size, {element_size} is not"

    return hex_to_int, int_to_hex, element_size


def compute_vector_vector_op(
    op: Callable[[int, int], int],
    element_size_str: str,
    operand1_128_bit: str,
    operand2_128_bit: str,
    treat_elements_as_signed: bool,
) -> str:
    hex_to_int, int_to_hex, element_size = prepare_vector_op(
        element_size_str, treat_elements_as_signed
    )

    elements1 = [
        hex_to_int(value)
        for value in split_n_bit_value_into_m_bit_values(
            128, element_size, operand1_128_bit
        )
    ]
    elements2 = [
        hex_to_int(value)
        for value in split_n_bit_value_into_m_bit_values(
            128, element_size, operand2_128_bit
        )
    ]
    result_elements = [int_to_hex(op(e1, e2)) for (e1, e2) in zip(elements1, elements2)]
    return combine_n_bit_values_into_m_bit_value(element_size, 128, result_elements)


def op_with_complex_rotation(
    op: Callable[[complex, complex], complex],
    op1: complex,
    op2: complex,
    rotation: int,
) -> complex:
    assert (
        rotation == 90 or rotation == 270
    ), f"`rotation` must be 90 or 270, but it is {rotation}"

    def rotate_operand(operand):
        # Rotating by 90 degrees in the complex plane is the same as multiplying by i.
        # Rotating by 270 degrees in the complex plane is the same as multiplying by -i.
        # j is the imaginary number i in python
        return operand * 1j if rotation == 90 else operand * -1j

    return op(op1, rotate_operand(op2))


# As this is a special case, handle it separately from the other vector operations.
def compute_vector_complex_rotation_op_result(
    op: Callable[[complex, complex], complex],
    element_size_str: str,
    operand1_128_bit: str,
    operand2_128_bit: str,
    rotation_str: str,
) -> str:
    rotation = int(rotation_str)

    hex_to_int, int_to_hex, element_size = prepare_vector_op(
        element_size_str, treat_elements_as_signed=True
    )

    def split_into_ints(val: complex) -> Tuple[int, int]:
        return int(val.real), int(val.imag)

    elements1 = [
        hex_to_int(value)
        for value in split_n_bit_value_into_m_bit_values(
            128, element_size, operand1_128_bit
        )
    ]
    elements2 = [
        hex_to_int(value)
        for value in split_n_bit_value_into_m_bit_values(
            128, element_size, operand2_128_bit
        )
    ]

    # The complex numbers are encoded as pairs of elements,
    # where the element with the even lane number is the real part
    # and the odd lane-numbered one is the imaginary part.
    complex1 = [
        complex(elements1[i], elements1[i + 1]) for i in range(0, len(elements1), 2)
    ]
    complex2 = [
        complex(elements2[i], elements2[i + 1]) for i in range(0, len(elements2), 2)
    ]

    # For now, we always apply rotation to the second operand.
    op_with_rotation = partial(op_with_complex_rotation, op)

    result_elements = [
        int_to_hex(component)
        for (e1, e2) in zip(complex1, complex2)
        for component in split_into_ints(op_with_rotation(e1, e2, rotation))
    ]
    return combine_n_bit_values_into_m_bit_value(element_size, 128, result_elements)


def compute_vector_scalar_op(
    op: Callable[[int, int], int],
    element_size_str: str,
    operand1_128_bit: str,
    operand2_32_bit: str,
    treat_elements_as_signed: bool,
) -> str:
    hex_to_int, int_to_hex, element_size = prepare_vector_op(
        element_size_str, treat_elements_as_signed
    )

    elements1 = [
        hex_to_int(value)
        for value in split_n_bit_value_into_m_bit_values(
            128, element_size, operand1_128_bit
        )
    ]
    op2 = hex_to_int(operand2_32_bit)
    result_elements = [int_to_hex(op(e1, op2)) for e1 in elements1]
    return combine_n_bit_values_into_m_bit_value(element_size, 128, result_elements)


def compute_bitwise_vector_vector_op(
    op: Callable[[int, int], int],
    operand1_128_bit: str,
    operand2_128_bit: str = None,
) -> str:
    # We can do operation on the whole register at once
    element1 = int(operand1_128_bit, 16)
    if operand2_128_bit:
        element2 = int(operand2_128_bit, 16)
        result_elements = op(element1, element2)
    else:
        result_elements = op(element1)

    return f"0x{result_elements:0>32x}"


def mask(bits: int) -> int:
    """An integer of `bits` 1s. Useful for forcing python integers into specific ranges."""
    return (1 << bits) - 1


def signed_to_hex(bits: int, signed_value: int) -> str:
    """Converts a signed python integer into an unsigned hexadecimal value of size `bits`."""
    result = hex(signed_value & mask(bits))
    return result


def twos_complement(bits: int, hexstr: str) -> int:
    """Converts a string containing a signed base-16 integer of size `bits` into a signed python integer."""
    value = int(hexstr, 16)  # This int will be unsigned.
    if value & (1 << (bits - 1)):  # Check if sign bit is set (i.e. number is negative).
        value -= 1 << bits  # Convert to negative version of the same number.
    return value


def floor_div_complex(number: complex, divisor: int) -> complex:
    """Performs integer division on a complex number."""
    return complex(number.real // divisor, number.imag // divisor)


def get_max_value(size: int, is_signed: bool) -> int:
    if is_signed:
        return (1 << (size - 1)) - 1
    else:
        return mask(size)


def get_min_value(size: int, is_signed: bool) -> int:
    if is_signed:
        return -(1 << (size - 1))
    else:
        return 0


def saturate(size: int, is_signed: bool, number: int) -> Tuple[int, bool]:
    """Saturates number"""
    max_element = get_max_value(size, is_signed)
    min_element = get_min_value(size, is_signed)

    if number > max_element:
        return max_element, True
    if number < min_element:
        return min_element, True
    return (number, False)


def not_128(number: int):
    """Does bitwise not on the number like it was 128 bit unsigned integer"""
    return number ^ ((1 << 128) - 1)


def compare(a: int, b: int, op: str) -> bool:
    """Does comparison between a and b based on op string"""
    if op == "EQ":
        return a == b
    if op == "NE":
        return a != b
    if op == "GT" or op == "HI":
        return a > b
    if op == "GE" or op == "CS":
        return a >= b
    if op == "LT":
        return a < b
    if op == "LE":
        return a <= b
    raise ValueError(f"Invalid comparison type: {op}")


def compute_vpr_mask(
    element_size_str: str,
    operand1_str: str,
    operand2_str: str,
    comparison_operator: str,
    is_signed: bool,
    with_scalar: bool,
):
    """
    Creates mask according to VPT instruction, the resulting mask is a boolean list, where True elements represent activated lanes and False elements represent deactivated lanes.
    It doesn't represent exactly the mask in VPR.P0, but it'll work the same for masking python versions of operations.
    """
    hex_to_int, _, element_size = prepare_vector_op(element_size_str, is_signed)
    assert element_size in [8, 16, 32], f"Invalid VPT operation size: {element_size}"

    operand1 = [
        hex_to_int(value)
        for value in split_n_bit_value_into_m_bit_values(128, element_size, operand1_str)
    ]

    if with_scalar:
        operand2 = hex_to_int(operand2_str[-(element_size // 4) :])
    else:
        operand2 = [
            hex_to_int(value)
            for value in split_n_bit_value_into_m_bit_values(128, element_size, operand2_str)
        ]

    mask = []
    for i, op1 in enumerate(operand1):
        op2 = operand2 if with_scalar else operand2[i]
        mask.append(compare(op1, op2, comparison_operator))
    return mask


def apply_vpr_mask(original: str, update: str, mask: list[bool], action: str):
    """Applies VPR mask to results"""
    if action == "":
        return update  # Just update whole register
    elif action == "T":
        pass  # Leave mask as is
    elif action == "E":
        mask = [not m for m in mask]  # Invert mask
    else:
        raise ValueError(f"Invalid mask update action: {action}")

    element_count = len(mask)
    assert element_count in [16, 8, 4, 1], f"Invalid mask size: {element_count}"
    element_size = 128 // element_count

    original = split_n_bit_value_into_m_bit_values(128, element_size, original)
    update = split_n_bit_value_into_m_bit_values(128, element_size, update)
    result = []

    for from_original, from_update, active in zip(original, update, mask):
        result.append(from_update if active else from_original)

    return combine_n_bit_values_into_m_bit_value(element_size, 128, result)


# Partial applications of `compute_vector_op`.
# The functions below only provide the first argument (`op`),
# leaving the others to be specified by the caller.

# Vector-vector variants
compute_vector_vhadd_result = partial(
    compute_vector_vector_op, lambda a, b: (a + b) // 2
)
compute_vector_vhsub_result = partial(
    compute_vector_vector_op, lambda a, b: (a - b) // 2
)


# Vector-vector complex number variants
compute_vector_vcadd_result = partial(
    compute_vector_complex_rotation_op_result, lambda a, b: a + b
)
compute_vector_vhcadd_result = partial(
    compute_vector_complex_rotation_op_result, lambda a, b: floor_div_complex(a + b, 2)
)

# Vector-scalar variants
compute_scalar_vhadd_result = partial(
    compute_vector_scalar_op, lambda a, b: (a + b) // 2
)
compute_scalar_vhsub_result = partial(
    compute_vector_scalar_op, lambda a, b: (a - b) // 2
)


# vmin and vmax
compute_vector_vmax_result = partial(compute_vector_vector_op, max)
compute_vector_vmin_result = partial(compute_vector_vector_op, min)

# Bitwise vector-vector variants
compute_vector_vand_result = partial(
    compute_bitwise_vector_vector_op, lambda a, b: a & b
)
compute_vector_vbic_result = partial(
    compute_bitwise_vector_vector_op, lambda a, b: a & not_128(b)
)
compute_vector_vorr_result = partial(
    compute_bitwise_vector_vector_op, lambda a, b: a | b
)
compute_vector_vorn_result = partial(
    compute_bitwise_vector_vector_op, lambda a, b: a | not_128(b)
)
compute_vector_veor_result = partial(
    compute_bitwise_vector_vector_op, lambda a, b: a ^ b
)

compute_vector_vmvn_result = partial(
    compute_bitwise_vector_vector_op, lambda a: not_128(a)
)


def compute_vdup_result(element_size_str: str, operand_32_bit: str):
    return compute_vector_scalar_op(
        lambda _, b: b,
        element_size_str,
        "0x00000000000000000000000000000000",
        operand_32_bit,
        False,
    )
