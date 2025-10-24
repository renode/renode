from pyrenode3.wrappers import Analyzer, Emulation, Monitor, TerminalTester
from Antmicro.Renode.Time import TimeInterval
from Antmicro.Renode.Peripherals.Wireless import IEEE802_15_4Medium
from Antmicro.Renode.Peripherals.CPU import ICpuSupportingGdb
from Antmicro.Renode.Peripherals.CPU import RegisterValue
import System
import sys
import argparse
import os
import threading
import subprocess
import queue
import time
import urllib.request
import tempfile
import stat
import re
import shlex
import atexit

DEFAULT_QUANTUM_TIME = 0.000020
DEFAULT_TESTER_TIMEOUT = 10
DEFAULT_DEBUG_PRINT = False
DEFAULT_LOG_LEVEL = 1
DEFAULT_STUB_RETURN_VALUE = 0
BASE_EXTERNAL_CONTROL_PORT = 3300
HOST_PROCESS_TRIGGER_PERIOD = 1.0

#Location of renode repo relative to working directory;
#for unpackaged renode it is the root of unpackaged contents
RENODE_BASE_PATH = os.environ.get("RENODE_BASE_PATH", "")

def parse_arguments():
    """
    Parses command-line arguments for the Silicon Labs pyrenode3-based testing library.

    Returns:
        tuple: A tuple containing either 3 or 4 elements:
            - board (str): The board to use for emulation, for example "brd4186c". (required).
            - uart (str): The UART interface to interact with the emulated nodes (required).
            - elf (str): The ELF file to be loaded into the emulated nodes (required).
            - elf2 (str): An optional second ELF file to be loaded into the emulated nodes (only included if provided).
            
        Note: If --elf2 is not provided, returns 3 arguments. If --elf2 is provided, returns 4 arguments.

    Raises:
        SystemExit: If required arguments are not provided or parsing fails.
    """
    global _cli_rng_seed, _cli_log_file
    parser = argparse.ArgumentParser(description="Silicon Labs pyrenode3-based testing library")
    parser.add_argument("-b", "--board", help="The board to use for emulation.", required=True)
    parser.add_argument("-u", "--uart", help="The UART interface to be used to interact with the emulated nodes", required=True)
    parser.add_argument("-e", "--elf", help="The ELF file to be loaded into the emulated nodes", required=True)
    parser.add_argument("-e2", "--elf2", help="An optional second ELF file to be loaded into the emulated nodes", required=False)
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
    
    # Return 3 or 4 arguments based on whether elf2 is provided
    if args.elf2 is not None:
        return args.board, args.uart, args.elf, args.elf2
    else:
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
    node.load_repl(RENODE_BASE_PATH + "platforms/boards/silabs/" + board + ".repl")
    node.load_elf(elf_file)
    _add_stubs(node, function_stubs)
    _add_reset_macro(name, elf_file)
    _m.execute("runMacro $reset")
    _m.execute("connector Connect sysbus.radio wireless")
    if tester_interface is not None:
        tester = TerminalTester(getattr(node.sysbus, tester_interface), tester_timeout)
    else:
        fail("No TerminalTester interface provided")
    _machine_name_to_machine_mapping[name] = node
    _tester_to_machine_mapping[tester] = node
    return tester

def launch_host_process(binary, name, args=None, cwd=None, env=None):
    """
    Launches a host process with the specified binary and saves a reference for later interaction.

    Args:
        binary (str): Path to the binary executable to launch, or a URL to download the binary from.
        name (str): Name to assign to this process for later reference.
        args (str or list, optional): Command-line arguments to pass to the binary. 
                                     Can be a string (will be parsed with shlex) or a list of arguments.
        cwd (str, optional): Working directory for the process. Defaults to None (current directory).
        env (dict, optional): Environment variables for the process. Defaults to None (inherit current environment).

    Returns:
        subprocess.Popen: The launched process object.

    Raises:
        FileNotFoundError: If the binary file cannot be found.
        OSError: If the process cannot be launched.

    Examples:
        process = launch_host_process("/path/to/binary", "host1", ["-r", "c"], cwd="/tmp")
        process = launch_host_process("/path/to/binary", "host1", "-p /tmp/sim_ncp1 -r c")
        process = launch_host_process("https://example.com/binary", "host1", "-r c")
    """
    
    # Handle URL download if binary is a URL
    actual_binary = binary
    if binary.startswith(('http://', 'https://')):
        actual_binary = _download_binary_from_url(binary)
        
    # Build the command list
    cmd = [actual_binary]
    if args is not None:
        # Handle both string and list arguments
        if isinstance(args, str):
            # If args is a string, split it properly (handles quoted arguments)
            cmd.extend(shlex.split(args))
        elif isinstance(args, list):
            # If args is already a list, use it directly
            cmd.extend(args)
        else:
            # Convert other iterables to list
            cmd.extend(list(args))
    
    try:
        # Create a dedicated external control server for this process
        # Each server can only handle one connection, so each process needs its own
        process_port = _create_external_control_server_for_process(name)
        
        # Set up environment variables for time synchronization
        # Create a copy of the environment to avoid modifying the original
        if env is None:
            env = os.environ.copy()
        else:
            env = env.copy()
        
        # Set the RENODE_PORT environment variable to the dedicated port for this process
        env['RENODE_PORT'] = str(process_port)
        debug_print(f"Process '{name}' will connect to external control server on port {process_port}")
        
        # Add LD_PRELOAD for time override library (Linux)
        # Look for the library in common locations
        library_paths = [
            "build/librenode_api.so",  # Jenkins CI path
            "../build/librenode_api.so",
            "librenode_api.so",
            os.path.join(RENODE_BASE_PATH, "build/librenode_api.so"),
            os.path.join(RENODE_BASE_PATH, "tools/external_control_client/lib/build/librenode_api.so")
        ]
        
        library_found = None
        for lib_path in library_paths:
            if os.path.exists(lib_path):
                library_found = os.path.abspath(lib_path)
                break
        
        if library_found:
            if 'LD_PRELOAD' in env and env['LD_PRELOAD']:
                # Append to existing LD_PRELOAD
                env['LD_PRELOAD'] = f"{env['LD_PRELOAD']}:{library_found}"
            else:
                # Set new LD_PRELOAD
                env['LD_PRELOAD'] = library_found
            debug_print(f"LD_PRELOAD set to: {env['LD_PRELOAD']}")
        else:
            debug_print("Warning: Time override library not found, host process may use system time")
        
        # Launch the process with stdin/stdout/stderr captured
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,  # Capture stderr for processing
            universal_newlines=True,
        )
        
        # Save the process reference and track its server port
        _process_name_to_process_mapping[name] = process
        _process_to_server_port[process] = process_port
        
        # Track downloaded binary if we downloaded one
        if binary.startswith(('http://', 'https://')):
            # Track this process in the URL cache
            if binary in _url_cache:
                _url_cache[binary]["processes"].add(process)
            
        debug_print(f"Host process '{name}' launched with PID: {process.pid}")
        
        # Start reader threads for continuous output monitoring (stdout and stderr)
        _start_process_reader(process)
        
        return process
        
    except FileNotFoundError as e:
        fail(f"Binary not found: {binary} - {e}")
    except OSError as e:
        fail(f"Failed to launch process: {binary} - {e}")
    
def wait_for(target, pattern, timeout=DEFAULT_TESTER_TIMEOUT):
    """
    Waits for a specific pattern to appear in either tester output or process output.
    
    For host processes, this function monitors both stdout and stderr streams
    simultaneously and returns the first matching line from either stream.

    Args:
        target: Either a TerminalTester object (returned by create_node) or 
                a subprocess.Popen object (returned by launch_host_process).
        pattern (str): The string or regex pattern to wait for in the output.
        timeout (float, optional): Maximum time to wait in seconds. Defaults to DEFAULT_TESTER_TIMEOUT (10).
                                 Only used for process objects; tester objects use their own timeout.

    Returns:
        str: The line from the output that matches the given pattern. For host processes,
             this could be from either stdout or stderr.

    Raises:
        SystemExit: If the pattern is not found before a timeout occurs.

    Examples:
        # Wait for simulation node output
        soc1 = test_lib.create_node(...)
        line = wait_for(soc1, "NETWORK_UP 0x....")
        
        # Wait for host process output (checks both stdout and stderr)
        host1 = test_lib.launch_host_process(...)
        line = wait_for(host1, "Ready")  # Will match from either stdout or stderr
    """
    
    # Check if it's a subprocess.Popen object (host process)
    if isinstance(target, subprocess.Popen):
        # Handle host process using the threaded buffered approach
        
        process = target
        name = get_process_name_from_process(process)
        pattern_re = re.compile(pattern)
        start_time = get_simulation_time()
        end_time = start_time + timeout
        
        if process not in _process_output_threads:
            fail(f"Reader threads not running for process [{name}]")
        
        _m.execute("start")
        
        # Track the last time we sent an empty line for output flushing
        # Initialize to 0 so the first check triggers an immediate flush
        last_flush_time = 0.0

        while get_simulation_time() < end_time:
            current_time = get_simulation_time()

            # If enabled, send empty line periodically to trigger output flushing
            if (_output_flushing_enabled and 
                current_time - last_flush_time >= HOST_PROCESS_TRIGGER_PERIOD):
                try:
                    write_line(target, "", log_write=False)
                    last_flush_time = current_time
                except (OSError, BrokenPipeError):
                    # Process may have terminated, ignore flush errors
                    pass
            
            # Check if process has terminated
            if process.poll() is not None:
                # Process any remaining buffered output before giving up
                remaining_time = 0.5  # Give a small window for final output
            else:
                remaining_time = end_time - current_time
                if remaining_time <= 0:
                    break
            
            # Try to get output from both stdout and stderr buffer queues
            output_found = False
            data = None
            
            # Check stdout first
            try:
                data = _process_stdout_buffers[process].get(timeout=0.05)
                output_found = True
            except queue.Empty:
                # No new stdout data available, continue to check stderr
                try:
                    data = _process_stderr_buffers[process].get(timeout=0.05)
                    output_found = True
                except queue.Empty:
                    # No new output available from either stream
                    continue
            
            if output_found:
                line_content = data.rstrip('\r\n')
                if line_content and pattern_re.search(line_content):
                    debug_print(f"[{name}]:[WAIT_FOR]: {line_content}")
                    _m.execute("pause")
                    return line_content

        fail(f"Timeout waiting for pattern '{pattern}' from process '{name}' after {timeout} seconds")

    else:
        # Handle TerminalTester object (simulation node)
        name = get_machine_name_from_tester(target)
        result = target.WaitFor(pattern=pattern, timeout=TimeInterval.FromSeconds(timeout), treatAsRegex=True, includeUnfinishedLine=True, pauseEmulation=True)
        if result is None or result.IsFailingString:
            fail(f"Timed out waiting for: '{pattern}' from tester '{name}' after {timeout} seconds")
        debug_print(f"[{name}]:[WAIT_FOR]: {result.Line}")
        return result.Line

def write_line(target, line, log_write=True):
    """
    Sends a line of text to either a tester (simulation node) or a host process.

    Args:
        target: Either a TerminalTester object (returned by create_node) or 
                a subprocess.Popen object (returned by launch_host_process).
        line (str): The line of text to be sent.
        log_write (bool, optional): Whether to log the write operation. Defaults to True.

    Returns:
        None

    Raises:
        OSError: If the target is a process and has terminated or stdin is closed.

    Examples:
        # Send to simulation node
        ncp1 = test_lib.create_node(...)
        write_line(ncp1, "network status")
        
        # Send to host process  
        host1 = test_lib.launch_host_process(...)
        write_line(host1, "version")
    """

    name = ""
    
    # Check if it's a subprocess.Popen object (host process)
    if isinstance(target, subprocess.Popen):
        name = get_process_name_from_process(target)
        try:
            target.stdin.write(line + "\n")
            target.stdin.flush()
        except (OSError, BrokenPipeError) as e:
            fail(f"Failed to send command to process PID {target.pid}: {e}")
    else:
        # Assume it's a TerminalTester object (simulation node)
        name = get_machine_name_from_tester(target)
        try:
            result = target.WriteLine(line)
        except Exception as e:
            fail(f"Failed to send line to tester: {e}")
    if log_write:
        debug_print(f"[{name}]:[WRITE_LINE]: {line}")

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

def get_simulation_time():
    """
    Gets the current elapsed virtual time from the simulation.

    Returns:
        float: The elapsed simulation time in seconds.

    Example:
        current_time = get_simulation_time()
        print(f"Simulation has been running for {current_time:.6f} seconds")
    """
    if _machine_name_to_machine_mapping:
        # Get the first available machine
        machine_name, machine = next(iter(_machine_name_to_machine_mapping.items()))
        time_obj = machine.LocalTimeSource.ElapsedVirtualTime
        return float(time_obj.TotalSeconds)
    
    fail("Failed to get time, no machine available")
    return 0.0
            
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

def get_process_from_name(process_name):
    """
    Retrieve a process object based on its name.

    Args:
        process_name (str): The name of the process to retrieve.

    Returns:
        subprocess.Popen: The process object associated with the given name.

    Raises:
        KeyError: If the process_name does not exist in the mapping.
    """
    return _process_name_to_process_mapping[process_name]

def terminate_process(process_name):
    """
    Terminates a process by name and removes it from the tracking dictionary.
    Also cleans up associated resources including reader threads (both stdout and stderr), 
    output buffers, and any downloaded binary files that are no longer in use.

    Args:
        process_name (str): The name of the process to terminate.

    Returns:
        None

    Raises:
        KeyError: If the process_name does not exist in the mapping.
    """
    process = _process_name_to_process_mapping[process_name]
    
    # Clean up the reader thread before terminating
    _cleanup_process_reader(process)
    
    # Clean up downloaded binary if there is one
    url, temp_file = _find_url_for_process(process)
    if url and temp_file:
        # Remove this process from the URL cache process set
        _url_cache[url]["processes"].discard(process)
        
        # If no more processes are using this cached file, we can delete it
        if not _url_cache[url]["processes"]:
            try:
                if os.path.exists(temp_file):
                    os.unlink(temp_file)
                    debug_print(f"Removed temporary binary: {temp_file}")
            except OSError as e:
                debug_print(f"Warning: Failed to remove temporary binary {temp_file}: {e}")
            
            # Remove from URL cache since file is deleted
            del _url_cache[url]
    
    # For cleanup situations, we want to terminate processes as quickly as possible
    # to prevent them from calling clock_gettime() after external control servers are gone
    try:
        # Close stdin first to prevent further input
        if process.stdin and not process.stdin.closed:
            try:
                process.stdin.close()
            except (BrokenPipeError, OSError):
                pass
        
        # Use SIGKILL immediately for faster termination during cleanup
        process.kill()
        process.wait(timeout=0.1)  # Should complete quickly with SIGKILL
        
    except Exception as e:
        debug_print(f"Error during termination of {process_name}: {e}")
    
    del _process_name_to_process_mapping[process_name]

def get_process_name_from_process(process):
    """
    Returns the name of a process given its process object.

    Args:
        process: The subprocess.Popen object to look up.

    Returns:
        str or None: The name of the process if found in the mapping, otherwise None.
    """
    for name, p in _process_name_to_process_mapping.items():
        if p == process:
            return name
    return None

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

def create_pty_terminal(tester, interface):
    """
    Create a PTY (pseudo-terminal) terminal for UART communication in Renode emulation.
    
    This function sets up a UART PTY terminal that allows external applications to 
    communicate with the emulated system through a specified interface. The terminal
    is created with a unique name based on the machine name and connected to the
    specified UART interface.
    
    Args:
        tester: The tester object used to extract machine name information
        interface (str): The UART interface name to connect to (e.g., 'uart0', 'uart1')
    
    Returns:
        str: The file descriptor path (/tmp/sim_{machine_name}) that can be used
             to communicate with the PTY terminal
    
    Example:
        >>> fd_path = create_pty_terminal(my_tester, "uart0")
        >>> print(fd_path)  # /tmp/sim_machine_name
    """
    machine_name = get_machine_name_from_tester(tester)
    cli_name = f"cli_{machine_name}"
    fd_name = f"/tmp/sim_{machine_name}"
    _m.execute(f"mach set \"{machine_name}\"")
    _m.execute(f"emulation CreateUartPtyTerminal \"{cli_name}\" \"{fd_name}\" True")
    _m.execute(f"connector Connect sysbus.{interface} {cli_name}")   
    return fd_name 
    
def debug_print(message, end=None):
    """
    Prints a debug message to the console if debugging is enabled.

    Args:
        message (str): The message to be printed for debugging purposes.
        end (str): The end of the message (optional).
    """
    if _debug_print:
        print(f"DEBUG: {message}", end=end, flush=True)

def enable_debug_prints(enable):
    """
    Enables or disables debug prints.

    Args:
        enable (bool): If True, enables debug prints; otherwise, disables them.
    """
    global _debug_print
    _debug_print = enable

def enable_output_flushing(enable):
    """
    Enables or disables periodic output flushing for host processes.
    
    When enabled, wait_for() will periodically send empty lines to host processes
    to trigger output flushing. This is useful as a workaround for Docker 
    environments where output buffering can cause delays.

    Args:
        enable (bool): If True, enables periodic output flushing; otherwise, disables it.
    """
    global _output_flushing_enabled
    _output_flushing_enabled = enable

def log_radio_activity_as_error():
    """
    Enable logging radio activity as errors in the Renode simulation environment.
    """
    for name, machine in _machine_name_to_machine_mapping.items():
        machine.sysbus.radio.LogBasicRadioActivityAsError = True
    
def set_log_file(filename, log_level=DEFAULT_LOG_LEVEL, flush_every_write=False):
    """
    Enables logging to a file. It enables logging for all peripherals of all nodes at the specified log level.

    Args:
        filename (str): The name of the file where all activity will be logged.
        log_level (int, optional): The logging level to set. Defaults to DEFAULT_LOG_LEVEL (1).
        flush_every_write (bool, optional): Whether to flush the log file after every write operation.
                                            Defaults to False.
    """
    if os.path.exists(filename):
        os.remove(filename)
    result = _m.execute(f"logFile \"{filename}\" {flush_every_write}")
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
    Automatically terminates all tracked processes before exiting.
    """
    print("Test failed: " + message)
        
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

def renode_base_path():
    """
    Returns the base path to the Renode repository as set by the RENODE_BASE_PATH environment variable.
    """
    return RENODE_BASE_PATH

########################################################################
# Internals
########################################################################

# Command-line argument storage
_cli_rng_seed = None
_cli_log_file = None

# Internal mappings
_machine_name_to_machine_mapping = {}
_tester_to_machine_mapping = {}
_process_name_to_process_mapping = {}

# Output flushing control
_output_flushing_enabled = False

# Cleanup control
_cleanup_in_progress = False

# Process output management - threading infrastructure
_process_output_threads = {}  # process -> stdout thread
_process_stdout_buffers = {}  # process -> stdout buffer
_process_stderr_threads = {}  # process -> stderr thread
_process_stderr_buffers = {}  # process -> stderr buffer
_process_reader_lock = threading.Lock()

# External control server management
_next_external_control_port = BASE_EXTERNAL_CONTROL_PORT + 1
_process_to_server_port = {}  # process -> port number
_active_servers = set()  # set of active server names

# Binary download management
_url_cache = {}  # url -> {"path": file_path, "processes": set_of_processes}

def _add_stubs(machine, function_stubs):
    """
    Add function stubs to a machine with configurable return values.
    
    Args:
        machine: The machine object to add stubs to.
        function_stubs: Can be any of these formats:
            - A list of function names: ["func1", "func2"] 
              (uses DEFAULT_STUB_RETURN_VALUE for all)
            - A dict mapping function names to return values: 
              {"func1": 0x42, "func2": 0x100, "func3": None}
            - A dict with detailed config per function:
              {"func1": {"return_value": 0x42}, "func2": {"return_value": 0x100}}
    
    Global Configuration:
        DEFAULT_STUB_RETURN_VALUE: Used when:
            - function_stubs is a list
            - a dict entry has None value  
            - a dict entry doesn't specify "return_value"
            Current value: 0 (can be modified globally)
    
    Examples:
        # Simple list - all functions return DEFAULT_STUB_RETURN_VALUE
        _add_stubs(machine, ["func1", "func2"])
        
        # To change global default for all subsequent calls:
        # DEFAULT_STUB_RETURN_VALUE = 0xFF
        
        # Dict with individual return values
        _add_stubs(machine, {"get_id": 0x1234, "check_status": 1, "init": 0})
        
        # Dict with detailed config (future-extensible)
        _add_stubs(machine, {
            "get_id": {"return_value": 0x1234}, 
            "init": {"return_value": 0}
        })
        
        # Mixed - some with values, some using global default
        _add_stubs(machine, {"special_func": 0x42, "normal_func": None})
    """
    if function_stubs is not None:
        # Handle different input formats
        if isinstance(function_stubs, list):
            # Convert list to dict with default return values
            stubs_dict = {func_name: DEFAULT_STUB_RETURN_VALUE for func_name in function_stubs}
        elif isinstance(function_stubs, dict):
            # Process dict entries to extract return values
            stubs_dict = {}
            for func_name, config in function_stubs.items():
                if config is None:
                    # None means use global default
                    ret_value = DEFAULT_STUB_RETURN_VALUE
                elif isinstance(config, dict):
                    # Detailed config: {"return_value": 0x42}
                    ret_value = config.get("return_value", DEFAULT_STUB_RETURN_VALUE)
                else:
                    # Direct value: "func": 0x42
                    ret_value = config
                stubs_dict[func_name] = ret_value
        else:
            debug_print(f"Warning: function_stubs should be list or dict, got {type(function_stubs)}")
            return
            
        for symbol, ret_value in stubs_dict.items():
            try:
                addresses = machine.sysbus.TryGetAllSymbolAddresses(symbol)[1]
                for addr in addresses:
                    Action = getattr(System, 'Action`2')
                    # Always use the return value hook with the specified return value
                    hook_action = Action[ICpuSupportingGdb, System.UInt64](
                        lambda cpu, addr, rv=ret_value: _skip_function_hook_with_return(cpu, addr, rv)
                    )
                    machine.sysbus.cpu.AddHook(addr, hook_action)
                    debug_print(f"Added stub for '{symbol}' at 0x{addr:x} with return value {ret_value}")
            except:
                debug_print(f"Warning: Symbol '{symbol}' not found, skipping stub")

def _machine_name_from_cpu(cpu):
    name = str(cpu).split(": ")[1]
    name = name.split(".")[0]
    return name

def _skip_function_hook_with_return(cpu, addr, return_value):
    # Set the return value in R0 using the correct RegisterValue type
    try:        
        # Create a RegisterValue from the integer (32-bit for ARM R0)
        reg_value = RegisterValue.Create(return_value, 32)
        
        # Use SetRegister (preferred API) instead of SetRegisterUnsafe
        cpu.SetRegister(0, reg_value)
        
    except Exception as e:
        print("Warning: Could not set R0 register to {} for stubbed function at 0x{:x}. Error: {}".format(return_value, addr, str(e)))
    
    # Skip the function by setting PC to LR
    cpu.PC = getattr(_e, _machine_name_from_cpu(cpu)).sysbus.cpu.LR

def _add_reset_macro(machine_name, elf_file):
    """
    Adds a reset macro for a specified machine.

    This function generates a reset macro that loads an ELF file into the system bus
    and sets the CPU vector table offset to the "__Vectors" symbol address from the
    loaded ELF file. The macro is added (but not executed) on the specified machine.

    Args:
        machine_name (str): The name of the machine to add the reset macro on.
        elf_file (str): The path to the ELF file to be loaded.

    Returns:
        None

    Note:
        This function relies on the global `_m` object to execute machine commands.
        The ELF file must contain a "__Vectors" symbol for proper vector table setup.
    """
    macro_reset_string = f"""macro reset
    \"\"\"
        sysbus LoadSymbolsFrom @{elf_file}
        cpu VectorTableOffset `sysbus GetSymbolAddress "__Vectors"`
    \"\"\"
    """
    _m.execute(f"mach set \"{machine_name}\"")
    _m.execute(f"{macro_reset_string}")

def _start_process_reader(process):
    """
    Starts reader threads for a process's stdout and stderr streams.
    
    Args:
        process: The subprocess.Popen object to start readers for
    """
    with _process_reader_lock:
        if process not in _process_output_threads:
            # Initialize the output buffer queues
            _process_stdout_buffers[process] = queue.Queue()
            _process_stderr_buffers[process] = queue.Queue()
            
            # Start reader thread for stdout
            if process.stdout:
                stdout_thread = threading.Thread(
                    target=_process_stream_reader,
                    args=(process, process.stdout, _process_stdout_buffers, "stdout"),
                    daemon=True
                )
                stdout_thread.start()
                _process_output_threads[process] = stdout_thread
            else:
                debug_print(f"Warning: No stdout available for process {process.pid}")
            
            # Start reader thread for stderr
            if process.stderr:
                stderr_thread = threading.Thread(
                    target=_process_stream_reader,
                    args=(process, process.stderr, _process_stderr_buffers, "stderr"),
                    daemon=True
                )
                stderr_thread.start()
                _process_stderr_threads[process] = stderr_thread
            else:
                debug_print(f"Warning: No stderr available for process {process.pid}")

def _cleanup_process_reader(process):
    """
    Cleans up the reader threads and buffers for a terminated process.

    Args:
        process: The subprocess.Popen object to clean up
    """
    with _process_reader_lock:
        # Clean up stdout thread
        if process in _process_output_threads:
            thread = _process_output_threads[process]
            thread.join(timeout=1.0)  # Wait up to 1 second
            del _process_output_threads[process]
        
        # Clean up stderr thread
        if process in _process_stderr_threads:
            thread = _process_stderr_threads[process]
            thread.join(timeout=1.0)  # Wait up to 1 second
            del _process_stderr_threads[process]
            
        # Clean up stdout buffer
        if process in _process_stdout_buffers:
            del _process_stdout_buffers[process]
        
        # Clean up stderr buffer
        if process in _process_stderr_buffers:
            del _process_stderr_buffers[process]

def _process_stream_reader(process, stream, buffer_dict, stream_name):
    """
    Thread function that continuously reads from a process stream and buffers output.
    
    Args:
        process: The subprocess.Popen object
        stream: The stream to read from (process.stdout or process.stderr)
        buffer_dict: The buffer dictionary to put data into (_process_stdout_buffers or _process_stderr_buffers)
        stream_name: Name of the stream for debugging ("stdout" or "stderr")
    """
    try:
        while process.poll() is None:  # While process is running
            try:
                # Use readline() for text streams - this blocks until a line is available
                # but is more reliable for text-based communication
                data = stream.readline()
                if data:
                    # Put the data chunk in the queue
                    with _process_reader_lock:
                        if not _cleanup_in_progress and data.strip():  # Only print if not empty/whitespace-only
                            process_name = get_process_name_from_process(process)
                            debug_print(f"[{process_name}]:[OUTPUT]: {data}", end="")
                        if process in buffer_dict:
                            buffer_dict[process].put(data)
                else:
                    # No data available, small sleep
                    time.sleep(0.1)
                        
            except (OSError, ValueError) as e:
                debug_print(f"Process {process.pid} {stream_name} reader error: {e}")
                break
                
        # Process has terminated, read any remaining data line by line
        try:
            while True:
                remaining_line = stream.readline()
                if not remaining_line:
                    break
                if not _cleanup_in_progress:
                    debug_print(f"Process {process.pid} {stream_name} remaining: '{remaining_line.rstrip()}'")
                
                with _process_reader_lock:
                    if process in buffer_dict:
                        buffer_dict[process].put(remaining_line)
        except:
            pass  # Ignore errors during cleanup
        
    except Exception as e:
        debug_print(f"Process {process.pid} {stream_name} reader thread crashed: {e}")

def _download_binary_from_url(url):
    """
    Downloads a binary from a URL to a temporary file and makes it executable.
    Caches downloads to avoid downloading the same URL multiple times.
    Tracks which processes are using each cached file for proper cleanup.
    
    Args:
        url (str): The URL to download the binary from.
        
    Returns:
        str: Path to the downloaded temporary file.
        
    Raises:
        Exception: If the download fails.
    """
    global _url_cache
    
    # Check if we've already downloaded this URL
    if url in _url_cache:
        cached_info = _url_cache[url]
        cached_path = cached_info["path"]
        # Verify the cached file still exists
        if os.path.exists(cached_path):
            debug_print(f"Using cached binary from URL: {url} -> {cached_path}")
            return cached_path
        else:
            # Cached file was deleted, remove from cache
            debug_print(f"Cached binary no longer exists, re-downloading: {url}")
            del _url_cache[url]
    
    try:
        debug_print(f"Downloading binary from URL: {url}")
        
        # Extract filename from URL for better temp file naming
        url_parts = url.split('/')
        original_filename = url_parts[-1] if url_parts else "binary"
        
        # Create a temporary file with a meaningful prefix
        with tempfile.NamedTemporaryFile(delete=False, prefix=f"renode_{original_filename}_", suffix="") as temp_file:
            temp_path = temp_file.name
            
        # Download the file
        urllib.request.urlretrieve(url, temp_path)
        
        # Make the file executable
        current_permissions = os.stat(temp_path).st_mode
        os.chmod(temp_path, current_permissions | stat.S_IEXEC)
        
        # Cache the download with process tracking
        _url_cache[url] = {
            "path": temp_path,
            "processes": set()  # Will be populated when processes use this binary
        }
        
        debug_print(f"Binary downloaded and cached: {url} -> {temp_path}")
        return temp_path
        
    except urllib.error.URLError as e:
        fail(f"Failed to download binary from URL '{url}': Network error - {e}")
    except OSError as e:
        fail(f"Failed to download binary from URL '{url}': File system error - {e}")
    except Exception as e:
        fail(f"Failed to download binary from URL '{url}': {e}")

def _find_url_for_process(process):
    """
    Find the URL associated with a downloaded binary process by searching the URL cache.
    
    Args:
        process: The subprocess.Popen object to find URL for.
        
    Returns:
        tuple: (url, file_path) if found, (None, None) if not found.
    """
    for url, cached_info in _url_cache.items():
        if process in cached_info["processes"]:
            return url, cached_info["path"]
    return None, None

def _create_external_control_server_for_process(process_name):
    """
    Creates a dedicated external control server for a host process.
    Each server can only handle one connection, so each process needs its own server.
    
    Args:
        process_name (str): Name of the process that will use this server.
        
    Returns:
        int: Port number of the created server.
    """
    global _next_external_control_port, _active_servers
    
    port = _next_external_control_port
    _next_external_control_port += 1
    
    server_name = f"ext_ctrl_server_{process_name}_{port}"
    
    try:
        _m.execute(f"emulation CreateExternalControlServer \"{server_name}\" {port}")
        _active_servers.add(server_name)
        debug_print(f"Created external control server '{server_name}' on port {port} for process '{process_name}'")
        return port
    except Exception as e:
        debug_print(f"Failed to create external control server for process '{process_name}': {e}")
        raise

def _cleanup_all_processes():
    """
    Cleanup function called at program exit to ensure proper teardown order.
    Terminates all tracked processes before the Python interpreter shuts down.
    This prevents host processes from trying to access Renode connections during teardown.
    """
    global _url_cache, _cleanup_in_progress
    
    # Set flag to suppress debug output from reader threads during cleanup
    _cleanup_in_progress = True
    
    process_names = list(_process_name_to_process_mapping.keys())  # Create a copy of the keys
    if process_names:
        debug_print(f"Cleaning up {len(process_names)} host processes at exit...")
        
        # First pass: Send SIGTERM and close stdin for graceful shutdown
        for process_name in process_names:
            try:
                process = _process_name_to_process_mapping[process_name]
                debug_print(f"Gracefully terminating host process: {process_name}")
                
                # Close stdin first to signal shutdown
                if process.stdin and not process.stdin.closed:
                    try:
                        process.stdin.close()
                    except (BrokenPipeError, OSError):
                        pass
                
                # Send SIGTERM for graceful shutdown
                process.terminate()
                
            except Exception as e:
                debug_print(f"Warning: Failed to gracefully terminate process '{process_name}': {e}")
        
        # Wait briefly for graceful shutdown
        time.sleep(0.2)
        
        # Second pass: Use SIGKILL for any remaining processes  
        remaining_processes = []
        for process_name in process_names:
            if process_name in _process_name_to_process_mapping:
                process = _process_name_to_process_mapping[process_name]
                if process.poll() is None:  # Still running
                    remaining_processes.append(process_name)
        
        if remaining_processes:
            debug_print(f"Force-killing {len(remaining_processes)} remaining processes...")
        
        for process_name in remaining_processes:
            try:
                debug_print(f"Force-killing host process: {process_name}")
                terminate_process(process_name)
            except Exception as e:
                debug_print(f"Warning: Failed to force-kill process '{process_name}': {e}")
    
    # Clean up cached downloaded files
    for url, cached_info in _url_cache.items():
        cached_path = cached_info["path"]
        try:
            if os.path.exists(cached_path):
                os.unlink(cached_path)
        except OSError as e:
            debug_print(f"Warning: Failed to remove cached binary {cached_path}: {e}")
    _url_cache.clear()

# Register cleanup function to run at program exit
atexit.register(_cleanup_all_processes)