# The subset of the pyrenode3 test_lib API used by the SiLabs crypto keyword libraries,
# implemented with Renode monitor commands issued through the Robot "Execute Command" keyword.
from robot.libraries.BuiltIn import BuiltIn


def execute_monitor_command(command):
    return BuiltIn().run_keyword("Execute Command", command)


def create_unit_test_machine(name, repl_string):
    execute_monitor_command(f'mach create "{name}"')
    execute_monitor_command(f'machine LoadPlatformDescriptionFromString """{repl_string}"""')


def read_doubleword(address):
    return int(execute_monitor_command(f"sysbus ReadDoubleWord {address:#x}").strip(), 0)


def read_bytes(address, count):
    # One monitor command per buffer, as each command is a separate connection to Renode
    output = execute_monitor_command(f"sysbus ReadBytes {address:#x} {count}")
    return [int(value, 0) for value in output.replace("[", " ").replace("]", " ").replace(",", " ").split()]


def write_bytes(address, data):
    if data:
        execute_monitor_command(f"sysbus WriteBytes [{', '.join(f'{value:#x}' for value in data)}] {address:#x}")


def write_doublewords(address, values):
    write_bytes(address, [byte for value in values for byte in (value & 0xFFFFFFFF).to_bytes(4, "little")])


def write_doubleword(address, value):
    execute_monitor_command(f"sysbus WriteDoubleWord {address:#x} {value:#x}")


def read_register(peripheral, offset):
    return int(execute_monitor_command(f"sysbus.{peripheral} ReadDoubleWord {offset}").strip(), 0)


def write_register(peripheral, offset, value):
    execute_monitor_command(f"sysbus.{peripheral} WriteDoubleWord {offset} {value}")


def write_register_words(peripheral, writes):
    # Writes (offset, value) pairs in order, with a single monitor command
    execute_monitor_command("; ".join(f"sysbus.{peripheral} WriteDoubleWord {offset} {value}" for offset, value in writes))


def test_assert(condition, message):
    if not condition:
        raise AssertionError(message)
