from collections.abc import Callable
from functools import partial


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
    """
    assert_starts_with_0x_prefix(value_128_bit)
    value_128_bit = value_128_bit[2:]
    assert_is_n_chars(value_128_bit, 32)
    assert n % 4 == 0, f"`n` must be divisible by 4. {n} is not"

    chars_in_n_bit_hex = n // 4
    return [
        "0x" + value_128_bit[i : i + chars_in_n_bit_hex]
        for i in range(0, len(value_128_bit), chars_in_n_bit_hex)
    ]


def combine_n_into_128_bit_value(n: int, values_n_bit: list[str]) -> str:
    """
    Converts a list of strings containing base-16 n-bit values (with 0x prefix)
    into a string containing a base-16 number (with 0x prefix).
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
    return "0x" + "".join([value.zfill(chars_in_n_bit_hex) for value in values_n_bit])


def compute_vector_op(
    op: Callable[[int, int], int],
    element_size_str: str,
    operand1_128_bit: str,
    operand2_128_bit: str,
    treat_elements_as_signed: bool,
) -> str:
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


def mask(bits: int) -> int:
    """An integer of `bits` 1s. Useful for forcing python integers into specific ranges."""
    return (1 << bits) - 1


def signed_to_hex(bits: int, signed_value: int) -> str:
    """Converts a signed python integer into an unsigned hexadecimal value of size `bits`."""
    return hex(signed_value & mask(bits))


def twos_complement(bits: int, hexstr: str) -> int:
    """Converts a string containing a signed base-16 integer of size `bits` into a signed python integer."""
    value = int(hexstr, 16)  # This int will be unsigned.
    if value & (1 << (bits - 1)):  # Check if sign bit is set (i.e. number is negative).
        value -= 1 << bits  # Convert to negative version of the same number.
    return value


# Partial applications of `compute_vector_op`.
# The functions below only provide the first argument (`op`),
# leaving the others to be specified by the caller.
compute_vhadd_result = partial(compute_vector_op, lambda a, b: (a + b) // 2)
compute_vhsub_result = partial(compute_vector_op, lambda a, b: (a - b) // 2)
