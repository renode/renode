#!/usr/bin/python
# pylint: disable=C0301,C0103,C0111
from __future__ import print_function
from sys import platform
import os
import sys
import argparse
import subprocess

this_path = os.path.abspath(os.path.dirname(__file__))
registered_handlers = []

def prepare_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("tests", help="List of test files", nargs='*')
    parser.add_argument("-f", "--fixture",  dest="fixture", help="Fixture to test", metavar="FIXTURE")
    parser.add_argument("-n", "--repeat",   dest="repeat_count", nargs="?", type=int, const=0, default=1, help="Repeat tests a number of times (no-flag: 1, no-value: infinite)")
    parser.add_argument("-d", "--debug",    dest="debug_mode",  action="store_true",  default=False, help="Debug mode")
    parser.add_argument("-o", "--output",   dest="output_file", action="store",       default=None,  help="Output file, default STDOUT.")
    parser.add_argument("-b", "--buildbot", dest="buildbot",    action="store_true",  default=False, help="Buildbot mode. Before running tests prepare environment, i.e., create tap0 interface.")
    parser.add_argument("-t", "--tests",    dest="tests_file",  action="store",       default=None,  help="Path to a file with a list of assemblies with tests to run. This is ignored if any test file is passed as positional argument.")
    if platform != "win32":
        parser.add_argument("-p", "--port",     dest="port",        action="store",       default=None,  help="Debug port.")
        parser.add_argument("-s", "--suspend",  dest="suspend",     action="store_true",  default=False, help="Suspend test waiting for a debugger.")
    parser.add_argument("-T", "--type",     dest="test_type",   action="store",       default="all", help="Type of test to execute (all by default)")
    parser.add_argument("-r", "--results-dir",  dest="results_directory",  action="store", default=os.path.join(this_path, 'tests'),  help="Location where test results should be stored.")
    parser.add_argument("--run-gdb", dest="run_gdb", action="store_true", help="Run tests under GDB control.")
    parser.add_argument("--exclude", default=[], action="append", help="Do not run tests marked with a tag.")
    parser.add_argument("--stop-on-error", dest="stop_on_error", action="store_true", default=False, help="Terminate immediately on the first test failure")
    return parser

def call_or_die(to_call, error_message):
    ret_code = subprocess.call(to_call)
    if ret_code != 0:
        print(error_message)
        sys.exit(ret_code)

def setup_tap():
    call_or_die(['sudo', 'tunctl', '-d', 'tap0'], 'Error while removing old tap0 interface')
    call_or_die(['sudo', 'tunctl', '-t', 'tap0', '-u', str(os.getuid())], 'Error while creating tap0 interface')
    call_or_die(['sudo', '-n', 'ip', 'link', 'set', 'tap0', 'up'], 'Error while setting interface state')
    call_or_die(['sudo', '-n', 'ip', 'addr', 'add', '192.0.2.1/24', 'dev', 'tap0'], 'Error while setting ip address')

def handle_options(options):
    if options.buildbot:
        print("Preparing Environment")
        setup_tap()
    if options.debug_mode:
        print("Running in debug mode.")
    elif platform != "win32" and (options.port is not None or options.suspend):
        print('Port/suspend options can be used in debug mode only.')
        sys.exit(1)
    if 'FIXTURE' in os.environ:
        options.fixture = os.environ['FIXTURE']
    if options.fixture:
        print("Testing fixture: " + options.fixture)
    if options.tests_file is not None and not options.tests:
        options.tests = [line.rstrip() for line in open(options.tests_file)]
    options.configuration = 'Debug' if options.debug_mode else 'Release'

def register_handler(handler_type, extension, creator, before_parsing=None, after_parsing=None):
    registered_handlers.append({'type': handler_type, 'extension': extension, 'creator': creator, 'before_parsing': before_parsing, 'after_parsing': after_parsing})

def run():
    parser = prepare_parser()
    for handler in registered_handlers:
        if 'before_parsing' in handler and handler['before_parsing'] is not None:
            handler['before_parsing'](parser)

    options = parser.parse_args()
    handle_options(options)
    for handler in registered_handlers:
        if 'after_parsing' in handler and handler['after_parsing'] is not None:
            handler['after_parsing'](options)

    options.output = sys.stdout
    if not options.output_file is None:
        try:
            options.output = open(options.output_file)
        except Exception as e:
            print("Failed to open output file. Falling back to STDOUT.")

    print("Preparing suites")
    tests_suites = []
    for path in options.tests:
        if path.startswith('#'):
            continue
        if not os.path.exists(path):
            print("Path {} does not exist. Quitting ...".format(path)) 
            exit(1)
        for handler in registered_handlers:
            if (options.test_type == 'all' or handler['type'] == options.test_type) and path.endswith(handler['extension']):
                tests_suites.append(handler['creator'](path))
    
    for suite in tests_suites: 
        suite.check(options)

    for suite in tests_suites:
        suite.prepare(options)

    print("Starting suites")
    tests_failed = False
    counter = 0
    while options.repeat_count == 0 or counter < options.repeat_count:
        counter += 1
        for suite in tests_suites:
            if not suite.run(options):
                tests_failed = True

    print("Cleaning up suites")
    for suite in tests_suites:
        suite.cleanup(options)

    options.output.flush()
    if options.output is not sys.stdout:
        options.output.close()

    if tests_failed:
        print("Some tests failed :( See logs for details!")
        sys.exit(1)
    print("Tests finished successfully :)")
