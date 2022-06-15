#!/usr/bin/env python

# This script provides convenience functions for debugging user-space seL4 applications.
# All of the commands are available under `sel4` prefix, e.g. `sel4 break`, `sel4 thread`, etc.
# To use this script in GDB you have to source it first, either using `source` command or running
# GDB with `-x <path/to/gdbscript.py>` argument.
#
# Example: break on main function in rootserver thread
#
# (gdb) sel4 wait-for-thread rootserver
# (gdb) sel4 switch-symbols rootserver
# (gdb) sel4 break rootserver main
# (gdb) continue

import os
import os.path
import sys
from enum import IntEnum
from glob import glob
import pickle


def get_envvar(name):
    if name not in os.environ:
        raise gdb.GdbError("{} environment variable is not set".format(name))
    else:
        return os.environ[name]


SYMBOL_AUTOSWITCHING = True
SOURCE_DIR = get_envvar('SOURCE_DIR')
sys.path.append(os.path.join(SOURCE_DIR, 'projects', 'capdl', 'python-capdl-tool'))

import capdl


class CapDLSource:
    def __init__(self, spec_pickle):
        with open(spec_pickle, 'rb') as f:
            cdl = pickle.load(f)

        self.threads = {obj.name for obj in cdl.obj_space if isinstance(obj, capdl.TCB)}
        # Add rootserver thread explicitly
        self.threads.add('rootserver')

    def get_threads(self):
        return self.threads


class ExitUserspaceMode(IntEnum):
    Never = 0
    Once = 1
    Always = 2


def source(callable):
    """Convenience decorator for sourcing gdb commands"""
    callable()
    return callable


@source
class seL4(gdb.Command):
    """Utility functions for debugging seL4 applications"""
    def __init__(self):
        super(self.__class__, self).__init__('sel4', gdb.COMMAND_USER, prefix=True)


@source
class seL4Threads(gdb.Command):
    """Lists all seL4 threads"""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 threads', gdb.COMMAND_STATUS)

    def invoke(self, arg, from_tty):
        print('\n'.join(get_threads()))


@source
class seL4Thread(gdb.Command):
    """Returns current seL4 thread"""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 thread', gdb.COMMAND_STATUS)

    def invoke(self, arg, from_tty):
        print(get_current_thread())


@source
class seL4WaitForThread(gdb.Command):
    """Continues until given thread is available to make operations on.

       This command waits until seL4_DebugNameThread syscall is handled by the kernel,
       which allows for the use of break and tbreak commands."""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 wait-for-thread', gdb.COMMAND_BREAKPOINTS)

    def complete(self, text, word):
        global THREADS
        return list(component for component in THREADS if component.startswith(text))

    def invoke(self, arg, from_tty):
        threads = get_threads()
        thread_exists = next((thread for thread in threads if arg in thread), None)
        if thread_exists is not None:
            raise gdb.GdbError("'{}' thread is already loaded".format(thread_exists))

        gdb.execute('mon seL4 BreakOnNamingThread "{}"'.format(arg))
        gdb.execute('continue')


@source
class seL4SwitchSymbols(gdb.Command):
    """Forcibly switches symbols to ones of the given component

    sel4 switch-symbols [component]

    Forcibly sets symbol-file to file corresponding to given component.
    If no component name is given or thread is "default" then default
    binary is loaded instead."""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 switch-symbols', gdb.COMMAND_FILES)

    def complete(self, text, word):
        global BINARIES

        # List all known components, add 'kernel' as an option for DEFAULT_BINARY
        components = list(BINARIES.keys())
        components.append('kernel')
        return list(component for component in components if component.startswith(text))

    def invoke(self, arg, from_tty):
        if not arg:
            thread = get_current_thread()
            switch_symbols(thread, verbose=True)
        elif arg == 'kernel':
            switch_symbols(verbose=True)
        else:
            switch_symbols(arg, fallback=False, verbose=True)


def _sel4_break_complete_helper(text, word):
    words = text.split(' ')
    if not text or len(words) <= 1:
        threads = get_threads()
        # Extend list of threads with additional special names
        threads.extend(['user', 'kernel'])
        return list(thread for thread in threads if thread.startswith(word))
    elif len(words) == 2:
        return gdb.COMPLETE_SYMBOL
    else:
        return gdb.COMPLETE_NONE


def _sel4_break_invoke_helper(command, arg):
    args = arg.split(' ')

    if command == 'break':
        exit_userspace_mode = ExitUserspaceMode.Always
        monitor_command = 'mon seL4 SetBreakpoint'
    elif command == 'tbreak':
        exit_userspace_mode = ExitUserspaceMode.Once
        monitor_command = 'mon seL4 SetTemporaryBreakpoint'
    else:
        raise ValueError("'{}' is invalid value for command".format(command))

    if len(args) < 1 or not args[0]:
        raise gdb.GdbError("sel4 {}: thread argument is required".format(command))

    thread = args[0]
    symbol_name = args[1] if len(args) >= 2 else None

    if thread == 'kernel':
        gdb.execute('mon seL4 BreakOnExittingUserspace {}'.format(exit_userspace_mode))
        return

    if thread == 'user':
        thread = '<any>'

    if symbol_name:
        _, hits = gdb.decode_line(symbol_name)
        for hit in hits:
            gdb.execute('{} "{}" {}'.format(monitor_command, thread, hex(hit.pc)))
    else:
        gdb.execute('{} "{}"'.format(monitor_command, thread))


@source
class seL4Break(gdb.Command):
    """Creates a breakpoint

    sel4 break thread [address]

    Creates a breakpoint in <thread> on optional <address>
    If no address is given, the breakpoint will be set on
    first address after context-switch"""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 break', gdb.COMMAND_BREAKPOINTS)

    def complete(self, text, word):
        return _sel4_break_complete_helper(text, word)

    def invoke(self, arg, from_tty):
        _sel4_break_invoke_helper('break', arg)


@source
class seL4TBreak(gdb.Command):
    """Creates temporary breakpoint

    sel4 tbreak thread [address]

    Creates temporary breakpoint in <thread> on optional <address>
    If no address is given, the breakpoint will be set on
    first address after context-switch"""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 tbreak', gdb.COMMAND_BREAKPOINTS)

    def complete(self, text, word):
        return _sel4_break_complete_helper(text, word)

    def invoke(self, arg, from_tty):
        _sel4_break_invoke_helper('tbreak', arg)


@source
class seL4Delete(gdb.Command):
    """Removes a breakpoint

    sel4 delete thread [address]

    Removes given breakpoint. If no address is given, the context-switch
    breakpoint is removed"""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 delete', gdb.COMMAND_BREAKPOINTS)

    def complete(self, text, word):
        words = text.split(' ')
        if not text or len(words) <= 1:
            threads = get_threads()
            # Extend list of threads with additional special names
            threads.extend(['user', 'kernel'])
            return list(thread for thread in threads if thread.startswith(word))
        elif len(words) == 2:
            # Renode returns breakpoints as a table, so we have to parse it
            # in order to gather completion list
            chosen_thread = words[0]
            if chosen_thread == 'user':
                chosen_thread = '<any>'
            completions = []
            for thread, address in get_breakpoints(chosen_thread):
                if chosen_thread not in thread:
                    continue
                if address == '<any>' or not address.startswith(word):
                    continue
                completions.append(address)
            return completions
        else:
            return gdb.COMPLETE_NONE

    def invoke(self, arg, from_tty):
        args = arg.split(' ')

        if len(args) < 1 or not args[0]:
            raise gdb.GdbError("sel4 delete: thread argument is required")

        thread = args[0] if len(args) >= 1 else None
        address = args[1] if len(args) >= 2 else None

        if thread == 'kernel':
            gdb.execute('mon seL4 BreakOnExittingUserspace {}'.format(ExitUserspaceMode.Never))
            return

        if thread == 'user':
            thread = '<any>'

        if address:
            gdb.execute('mon seL4 RemoveBreakpoint "{}" {}'.format(thread, address))
            gdb.execute('mon seL4 RemoveTemporaryBreakpoint "{}" {}'.format(thread, address))
        else:
            gdb.execute('mon seL4 RemoveBreakpoint "{}"'.format(thread))
            gdb.execute('mon seL4 RemoveTemporaryBreakpoint "{}"'.format(thread))


@source
class seL4DeleteAll(gdb.Command):
    """Removes all breakpoints assigned to the thread

    sel4 delete-all thread"""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 delete-all', gdb.COMMAND_BREAKPOINTS)

    def complete(self, text, word):
        return list(thread for thread in get_threads() if thread.startswith(text))

    def invoke(self, arg, from_tty):
        gdb.execute('mon seL4 BreakOnExittingUserspace {}'.format(ExitUserspaceMode.Never))
        if arg:
            gdb.execute('mon seL4 RemoveAllBreakpoints "{}"'.format(arg))
        else:
            gdb.execute('mon seL4 RemoveAllBreakpoints')


@source
class seL4ListBreakpoints(gdb.Command):
    """Lists all breakpoints

    sel4 list-breakpoints [thread]
    """

    def __init__(self):
        super(self.__class__, self).__init__('sel4 list-breakpoints', gdb.COMMAND_BREAKPOINTS)

    def complete(self, text, word):
        return list(thread for thread in get_threads() if thread.startswith(text))

    def invoke(self, arg, from_tty):
        if not arg:
            gdb.execute('mon seL4 GetBreakpoints')
        else:
            gdb.execute('mon seL4 GetBreakpoints "{}"'.format(arg))


@source
class seL4Ready(gdb.Command):
    """Returns ready state of seL4 extensions"""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 ready', gdb.COMMAND_STATUS)

    def invoke(self, arg, from_tty):
        gdb.execute('mon seL4 Ready')


@source
class seL4SymbolAutoswitching(gdb.Command):
    """Enables or disables symbol file autoswitching"""

    def __init__(self):
        super(self.__class__, self).__init__('sel4 symbol-autoswitching', gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        global SYMBOL_AUTOSWITCHING

        if not arg:
            print('Symbol autoswitching is {}'.format('enabled' if SYMBOL_AUTOSWITCHING else 'disabled'))
            return

        if arg.isdigit():
            arg = bool(int(arg))
        elif arg in ['True', 'true']:
            arg = True
        elif arg in ['False', 'false']:
            arg = False
        else:
            raise gdb.GdbError('{} is invalid argument for sel4 symbol-autoswitching'.format(arg))

        SYMBOL_AUTOSWITCHING = arg
        print('Symbol autoswitching is now {}'.format('enabled' if SYMBOL_AUTOSWITCHING else 'disabled'))


@source
def find_binaries():
    global BINARIES, DEFAULT_BINARY
    BINARIES = {}

    build_dir = get_envvar('BUILD_DIR')
    # Default binary is kernel, because every other component has its own thread,
    # including rootserver.
    DEFAULT_BINARY = os.path.join(build_dir, 'kernel', 'kernel.elf')

    # Find all CAmkES components
    images_path = os.path.join(build_dir, '*.instance.bin')
    for image_path in glob(images_path):
        image_name = os.path.basename(image_path).split('.instance.bin')[0]
        BINARIES[image_name] = image_path

    # rootserver thread is just capdl-loader
    BINARIES['rootserver'] = os.path.join(build_dir, 'capdl-loader')


@source
def find_threads():
    global THREADS

    build_dir = get_envvar('BUILD_DIR')
    cdl_pickle = os.path.join(build_dir, 'object.pickle')
    provider = CapDLSource(cdl_pickle)
    THREADS = provider.get_threads()


def get_breakpoints(thread=None):
    if not thread:
        breakpoints = gdb.execute('mon seL4 GetBreakpointsPlain', to_string=True).strip()
    else:
        breakpoints = gdb.execute('mon seL4 GetBreakpointsPlain "{}"'.format(thread), to_string=True).strip()
    return [tuple(line.strip().split(':')) for line in breakpoints.splitlines()]


def get_current_thread():
    return gdb.execute('mon seL4 CurrentThread', to_string=True).strip()


def get_threads():
    command_output = gdb.execute('mon seL4 Threads', to_string=True)
    threads = []
    for line in command_output.strip().split('\n')[1:-1]:
        splitted_line = (thread.strip() for thread in line.split(','))
        threads.extend(thread for thread in splitted_line if thread)
    return threads


def resolve_symbol_file(thread, fallback=True):
    if thread is None:
        image_path = DEFAULT_BINARY
    else:
        image_name = next((key for key in BINARIES.keys() if key in thread), None)
        if image_name is not None:
            image_path = BINARIES[image_name]
        elif image_name is None and fallback:
            image_path = DEFAULT_BINARY
        else:
            return None
    return image_path


def switch_symbols(thread=None, fallback=True, verbose=False):
    """Switch symbol-file to the file corresponding to the given thread

    If fallback is set to true and the given thread is not found, it will set
    symbol-file to DEFAULT_BINARY (def. kernel.elf).
    If verbose is set to true, symbol-file command will be run in interactive
    mode and information of switching symbol file will be shown"""
    global BINARIES, DEFAULT_BINARY

    image_path = resolve_symbol_file(thread, fallback)

    if image_path is None:
        raise gdb.GdbError("no symbol-file found for thread/component {}".format(thread))

    gdb.execute('symbol-file {}'.format(image_path), from_tty=verbose)


def stop_handler(event):
    if not isinstance(event, gdb.StopEvent):
        return

    global SYMBOL_AUTOSWITCHING

    if SYMBOL_AUTOSWITCHING:
        thread = get_current_thread()
        switch_symbols(thread)

gdb.events.stop.connect(stop_handler)
