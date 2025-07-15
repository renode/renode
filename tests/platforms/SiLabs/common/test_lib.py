from pyrenode3.wrappers import Analyzer, Emulation, Monitor, TerminalTester
from Antmicro.Renode.Time import TimeInterval
from Antmicro.Renode.Peripherals.Wireless import IEEE802_15_4Medium
from Antmicro.Renode.Peripherals.CPU import ICpuSupportingGdb
import System
import sys
import argparse
import os

DEFAULT_QUANTUM_TIME = 0.000020
DEFAULT_TESTER_TIMEOUT = 10
DEFAULT_DEBUG_PRINT = False
DEFAULT_LOG_LEVEL = 1

_machine_name_to_machine_mapping = {}
_tester_to_machine_mapping = {}

def parse_arguments():
    """
    Parses command-line arguments for the Silicon Labs pyrenode3-based testing library.

    Returns:
        tuple: A tuple containing:
            - board (str): The board to use for emulation, for example "brd4186c". (required).
            - uart (str): The UART interface to interact with the emulated nodes (required).
            - elf (str): The ELF file to be loaded into the emulated nodes (required).
            - rng_seed (int or None): The random number generator seed to be used for emulation (default: None).
            - log_file (str or None): The file to log all activity (default: None).

    Raises:
        SystemExit: If required arguments are not provided or parsing fails.
    """
    global _cli_rng_seed, _cli_log_file
    parser = argparse.ArgumentParser(description="Silicon Labs pyrenode3-based testing library")
    parser.add_argument("-b", "--board", help="The board to use for emulation.", required=True)
    parser.add_argument("-u", "--uart", help="The UART interface to be used to interact with the emulated nodes", required=True)
    parser.add_argument("-e", "--elf", help="The ELF file to be loaded into the emulated nodes", required=True)
    parser.add_argument("-l", "--log_file", help="The file to log all activity", required=False)
    parser.add_argument(
        "-r", "--rng_seed",
        help="The random number generator seed to be used for emulation (decimal or hex, e.g., 1234 or 0x1234ABCD)",
        required=False,
        type=lambda x: int(x, 0) if x is not None else None
    )
    args = parser.parse_args()
    _cli_rng_seed = args.rng_seed
    _cli_log_file = args.log_file
    return args.board, args.uart, args.elf

def create_emulation(debug=DEFAULT_DEBUG_PRINT, quantum_time=DEFAULT_QUANTUM_TIME, rng_seed=None, log_file=None):
    """
    Initializes and configures the emulation environment.

    Parameters:
        debug (callable, optional): Function to handle debug printing. Defaults to DEFAULT_DEBUG_PRINT.
        quantum_time (float, optional): The quantum time interval in seconds for the emulation. Defaults to DEFAULT_QUANTUM_TIME.
        rng_seed (int, optional): Seed value for the random number generator. If None, it shall use the seed parsed out from the command line arguments, if available. Otherwise, a random seed is used.
        log_file (str, optional): The file to log all activity. If None, it shall use the log filename parsed out from the command line arguments, if available. Otherwise, a no logging is performed.

    Side Effects:
        - Sets global variables _e (Emulation instance), _m (Monitor instance), and _debug_print.
        - Configures the emulation environment with serial execution, quantum time, and immediate advancement.
        - Creates an IEEE 802.15.4 wireless medium.
        - Sets the RNG seed if provided.
        - Prints the RNG seed in hexadecimal format.

    Returns:
        None
    """
    global _e, _m, _debug_print
    _debug_print = debug
    _e = Emulation()
    _m = Monitor()
    _e.SetGlobalSerialExecution(True)
    _e.SetQuantum(TimeInterval.FromSeconds(quantum_time))
    _e.SetAdvanceImmediately(True)
    _e.CreateIEEE802_15_4Medium("wireless")
    if rng_seed is not None:
        _e.SetSeed(rng_seed)
    elif _cli_rng_seed is not None:
        _e.SetSeed(_cli_rng_seed)
    if log_file is not None:
        set_log_file(log_file)
    elif _cli_log_file is not None:
        set_log_file(_cli_log_file)
    print(f"RNG SEED: {hex(_e.GetSeed())}")

def create_node(name, board, elf_file, tester_interface, tester_timeout = DEFAULT_TESTER_TIMEOUT, function_stubs=None):
    """
    Creates and configures a simulation node with the specified parameters.

    Args:
        name (str): The name of the node/machine to create.
        board (str): The Silicon Labs emulated board to be used.
        elf_file (str): Path to the ELF binary file to load into the node.
        tester_interface (str): The name of the interface on the node to attach the TerminalTester to.
        tester_timeout (int, optional): Timeout value for the TerminalTester. Defaults to DEFAULT_TESTER_TIMEOUT.
        function_stubs (dict or None, optional): Optional dictionary of function stubs to add to the node.

    Returns:
        TerminalTester: An instance of TerminalTester attached to the specified interface.

    Raises:
        SystemExit: If no testerInterface is provided.

    Side Effects:
        - Adds the created node to internal mappings for machine and tester tracking.
        - Loads the specified ELF files into the node.
        - Connects the node's radio to the system bus via the wireless connector.
        - Adds any provided function stubs to the node.
    """
    node = _e.add_mach(name)
    node.load_repl("platforms/boards/silabs/" + board + ".repl")
    node.load_elf(elf_file)
    node.sysbus.cpu.VectorTableOffset = node.sysbus.GetSymbolAddress("__Vectors")
    _m.execute(f"mach set \"{name}\"")
    _m.execute("connector Connect sysbus.radio wireless")
    if tester_interface is not None:
        tester = TerminalTester(getattr(node.sysbus, tester_interface), tester_timeout)
    else:
        fail("No TerminalTester interface provided")
    _machine_name_to_machine_mapping[name] = node
    _tester_to_machine_mapping[tester] = node
    _add_stubs(node, function_stubs)
    return tester

def wait_for(tester, line):
    """
    Waits for a specific line or pattern to appear in the tester's output.

    Args:
        tester: An object or identifier returned by the create_node function.
        line (str): The string or regex pattern to wait for in the output.

    Returns:
        str: The line from the output that matches the given pattern.

    Raises:
        SystemExit: If the pattern is not found before a timeout occurs.

    Side Effects:
        Prints debug information about the wait status.
    """
    result = tester.WaitFor(pattern=line, treatAsRegex=True, includeUnfinishedLine=True, pauseEmulation=True)
    if result is None or result.isFailingString:
        fail(f"Timed out waiting for: {line}")
    debug_print("WAIT_FOR: " + result.line)
    return result.line

def write_line(tester, line):
    """
    Sends a line of text to the tester and logs the action for debugging.

    Args:
        tester: An object or identifier returned by the create_node function.
        line (str): The line of text to be sent to the tester.

    Returns:
        None
    """
    debug_print("WRITE_LINE: " + line)
    result = tester.WriteLine(line)

def delay(secs):
    """
    Pauses the execution for a specified number of seconds in the Renode simulation environment.

    Args:
        secs (float): The number of seconds to delay the simulation.

    Raises:
        Any exceptions raised by the underlying _e.RunFor or TimeInterval.FromSeconds methods.

    Example:
        delay(1.5)  # Delays the simulation for 1.5 seconds
    """
    _e.RunFor(TimeInterval.FromSeconds(secs))

def get_machine_from_name(machine_name):
    """
    Retrieve a machine object based on its name.

    Args:
        machine_name (str): The name of the machine to retrieve.

    Returns:
        object: The machine object associated with the given name.

    Raises:
        KeyError: If the machine_name does not exist in the mapping.
    """
    return _machine_name_to_machine_mapping[machine_name]

def get_machine_name_from_machine(machine):
    """
    Returns the name of a machine given its machine object.

    Args:
        machine: The machine object to look up.

    Returns:
        str or None: The name of the machine if found in the mapping, otherwise None.
    """
    for name, m in _machine_name_to_machine_mapping.items():
        if m == machine:
            return name
    return None

def get_machine_name_from_tester(tester):
    """
    Returns the machine name associated with a given tester.

    Args:
        tester: An object or identifier returned by the create_node function.

    Returns:
        The name of the machine associated with the provided tester.

    Raises:
        KeyError: If the tester is not found in the mapping.
    """
    return get_machine_name_from_machine(_tester_to_machine_mapping[tester])

def get_machine_from_tester(tester):
    """
    Retrieve the machine associated with a given tester.

    Args:
        tester: An object or identifier returned by the create_node function.

    Returns:
        The machine associated with the provided tester, or None if the tester is not found in the mapping.
    """
    return _tester_to_machine_mapping.get(tester)

def create_socket(tester, port, interface):
    """
    Creates a server socket terminal in the emulation environment and connects it to a specified interface.

    Args:
        tester: An object or identifier returned by the create_node function.
        port (int): The port number on which to create the server socket.
        interface (str): The name of the interface on the sysbus to connect to the socket.

    Raises:
        Exception: If any of the underlying commands fail to execute.

    Side Effects:
        - Sets the current machine context in the emulation environment.
        - Creates a server socket terminal.
        - Connects the specified sysbus interface to the created socket terminal.
    """
    machine_name = get_machine_name_from_tester(tester)
    cli_name = f"cli_{machine_name}"
    _m.execute(f"mach set \"{machine_name}\"")
    _m.execute(f"emulation CreateServerSocketTerminal {port} \"{cli_name}\" false")
    _m.execute(f"connector Connect sysbus.{interface} {cli_name}")

def debug_print(message):
    """
    Prints a debug message to the console if debugging is enabled.

    Args:
        message (str): The message to be printed for debugging purposes.
    """
    if (_debug_print):
        print(f"DEBUG: {message}")

def enable_debug_prints(enable):
    """
    Enables or disables debug prints.

    Args:
        enable (bool): If True, enables debug prints; otherwise, disables them.
    """
    global _debug_print
    _debug_print = enable

def log_radio_activity_as_error():
    """
    Enable logging radio activity as errors in the Renode simulation environment.
    """
    for name, machine in _machine_name_to_machine_mapping.items():
        machine.sysbus.radio.LogBasicRadioActivityAsError = True
    
def set_log_file(filename, log_level=DEFAULT_LOG_LEVEL):
    """
    Enables logging to a file. It enables logging for all peripherals of all nodes at the specified log level.

    Args:
        filename (str): The name of the file where all activity will be logged.
        logLevel (int, optional): The logging level to set. Defaults to 1 (INFO).
    """
    if os.path.exists(filename):
        os.remove(filename)
    result = _m.execute(f"logFile \"{filename}\"")
    result = _m.execute(f"logLevel {log_level}")

def set_log_level(node, peripheral, log_level):
    """
    Sets the logging level for a specific peripheral of a node.

    Args:
        node: An object or identifier returned by the create_node function.
        peripheral (str): The peripheral name to set the logging level for.
        log_level (int): The logging level to set.
    """
    machine_name = get_machine_name_from_tester(node)
    _m.execute(f"mach set \"{machine_name}\"")
    _m.execute(f"logLevel {log_level} {peripheral}")

def fail(message):
    """
    Fails the current test with an error message.
    """
    print("FAIL: " + message)
    sys.exit(1)

def emulation():
    """
    Returns the current emulation environment.
    """
    return _e

def monitor():
    """
    Returns the current monitor instance.
    """
    return _m

########################################################################
# Internals
########################################################################

def _add_stubs(machine, function_stubs):
    if function_stubs is not None:
        for symbol in function_stubs:
            addresses = machine.sysbus.TryGetAllSymbolAddresses(symbol)[1]
            for addr in addresses:
                Action = getattr(System, 'Action`2')
                hook_action = Action[ICpuSupportingGdb, System.UInt64](_skip_function_hook)
                machine.sysbus.cpu.AddHook(addr, hook_action)

def _machine_name_from_cpu(cpu):
    name = str(cpu).split(": ")[1]
    name = name.split(".")[0]
    return name

def _skip_function_hook(cpu, addr):
    cpu.PC = getattr(_e, _machine_name_from_cpu(cpu)).sysbus.cpu.LR