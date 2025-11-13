import decimal
from typing import Union


def get_interrupt_timeout_seconds(control_register_value, clock_frequency):
    # Robot passes values as strings, so convert them.
    control_register_value = int(control_register_value.strip(), 0)
    interrupt_interval_power = control_register_value & 0b1110000  # bits 7:4

    # Interrupt interval starts at 2^6 when value is 0.
    power_offset = 6

    return get_timeout_seconds(interrupt_interval_power, power_offset, clock_frequency)


def get_reset_timeout_seconds(control_register_value, clock_frequency):
    # Robot passes values as strings, so convert them.
    control_register_value = int(control_register_value.strip(), 0)
    reset_interval_power = control_register_value & 0b11100000000  # bits 10:8

    # Reset interval starts at 2^7 when value is 0.
    power_offset = 7

    return get_timeout_seconds(reset_interval_power, power_offset, clock_frequency)


def get_timeout_seconds(interval_power, power_offset, clock_frequency):
    # Robot passes values as strings, so convert them.
    clock_frequency = int(clock_frequency.strip(), 0)

    interval_cycles = pow(2, interval_power + power_offset)
    seconds_per_cycle = 1 / clock_frequency
    timeout_seconds = interval_cycles * seconds_per_cycle

    # Round the number so we wait for slightly longer than necessary,
    # otherwise we risk waiting too little due to precision loss.
    return round_to_n_significant_digits(timeout_seconds, 3)


def round_to_n_significant_digits(value: Union[str, float], digits: int):
    with decimal.localcontext() as context:
        # Adjust precision to match the number of significant digits we want.
        context.prec = digits
        # Always round up, since we don't want to accidentally wait for too little time.
        context.rounding = decimal.ROUND_UP

        rounded_number = decimal.Decimal(value).normalize(context)
        return format(rounded_number, "f")
