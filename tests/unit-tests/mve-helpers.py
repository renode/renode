from collections.abc import Callable
from functools import partial
from typing import Tuple


def assert_starts_with_0x_prefix(string: str):
    assert string[0:2] == "0x", f"String '{string}' must start with '0x' prefix"


def assert_is_n_chars(string: str, n: int):
    length = len(string)
    assert (
        length == n
    ), f"String '{string}' must be {n} characters long but it's {length}"


def split_into_n_bit_values(n: int, value_128_bit: str) -> list[str]:
    """
    Converts a string containing a base-16 number (with 0x prefix) into
    a list of strings containing base-16 n-bit values (with 0x prefix).
    The list is ordered such that the indices correspond to lane numbers.
    """
    assert_starts_with_0x_prefix(value_128_bit)
    value_128_bit = value_128_bit[2:]
    assert_is_n_chars(value_128_bit, 32)
    assert n % 4 == 0, f"`n` must be divisible by 4. {n} is not"

    chars_in_n_bit_hex = n // 4
    return [
        "0x" + value_128_bit[i : i + chars_in_n_bit_hex]
        # The indexing is reversed because we place the most significant bits first in the list.
        for i in reversed(range(0, len(value_128_bit), chars_in_n_bit_hex))
    ]


def combine_n_into_128_bit_value(n: int, values_n_bit: list[str]) -> str:
    """
    Converts a list of strings containing base-16 n-bit values (with 0x prefix)
    into a string containing a base-16 number (with 0x prefix).
    The input list is expected to be ordered such that indices correspond to lane numbers.
    """
    list(map(assert_starts_with_0x_prefix, values_n_bit))
    assert 128 % n == 0, f"128 must be divisible by `n`, but {n} is not"
    length = len(values_n_bit)
    expected_values = 128 // n
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
    element_size_str: str, treat_elements_as_signed: bool
) -> Tuple[Callable[[str], int], Callable[[int], str], int]:
    element_size = int(element_size_str)  # Robot insists on passing it as a string :(

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
        for value in split_into_n_bit_values(element_size, operand1_128_bit)
    ]
    elements2 = [
        hex_to_int(value)
        for value in split_into_n_bit_values(element_size, operand2_128_bit)
    ]
    result_elements = [int_to_hex(op(e1, e2)) for (e1, e2) in zip(elements1, elements2)]
    return combine_n_into_128_bit_value(element_size, result_elements)


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
        for value in split_into_n_bit_values(element_size, operand1_128_bit)
    ]
    elements2 = [
        hex_to_int(value)
        for value in split_into_n_bit_values(element_size, operand2_128_bit)
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
    return combine_n_into_128_bit_value(element_size, result_elements)


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
        for value in split_into_n_bit_values(element_size, operand1_128_bit)
    ]
    op2 = hex_to_int(operand2_32_bit)
    result_elements = [int_to_hex(op(e1, op2)) for e1 in elements1]
    return combine_n_into_128_bit_value(element_size, result_elements)


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
