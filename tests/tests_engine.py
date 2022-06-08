# pylint: disable=C0301,C0103,C0111
from __future__ import print_function
from sys import platform
import os
import sys
import argparse
import subprocess
import yaml
import multiprocessing

this_path = os.path.abspath(os.path.dirname(__file__))
registered_handlers = []


class IncludeLoader(yaml.SafeLoader):

    def __init__(self, stream):

        self._root = os.path.split(stream.name)[0]

        super(IncludeLoader, self).__init__(stream)

    def include(self, node):
        config = self.construct_mapping(node)
        filename = os.path.join(self._root, config['path'])

        def _append_prefix(lst, prefix):
            for idx, val in enumerate(lst):
                if isinstance(val, str):
                    lst[idx] = os.path.join(prefix, lst[idx])
                elif isinstance(val, dict):
                    _append_prefix(val.values()[0], prefix)
                else:
                    raise Exception('Unsupported list element: ' + val)

        with open(filename, 'r') as f:
            data = yaml.load(f, IncludeLoader)
            if data is not None and 'prefix' in config:
                _append_prefix(data, config['prefix'])
            return data


IncludeLoader.add_constructor('!include', IncludeLoader.include)


def prepare_parser():
    parser = argparse.ArgumentParser()

    parser.add_argument("tests",
                        help="List of test files",
                        nargs='*')

    parser.add_argument("-f", "--fixture",
                        dest="fixture",
                        help="Fixture to test",
                        metavar="FIXTURE")

    parser.add_argument("-n", "--repeat",
                        dest="repeat_count",
                        nargs="?",
                        type=int,
                        const=0,
                        default=1,
                        help="Repeat tests a number of times (no-flag: 1, no-value: infinite)")

    parser.add_argument("-d", "--debug",
                        dest="debug_mode",
                        action="store_true",
                        default=False,
                        help="Debug mode")

    parser.add_argument("-o", "--output",
                        dest="output_file",
                        action="store",
                        default=None,
                        help="Output file, default STDOUT.")

    parser.add_argument("-b", "--buildbot",
                        dest="buildbot",
                        action="store_true",
                        default=False,
                        help="Buildbot mode. Before running tests prepare environment, i.e., create tap0 interface.")

    parser.add_argument("-t", "--tests",
                        dest="tests_file",
                        action="store",
                        default=None,
                        help="Path to a file with a list of assemblies with tests to run. This is ignored if any test file is passed as positional argument.")

    parser.add_argument("-T", "--type",
                        dest="test_type",
                        action="store",
                        default="all",
                        help="Type of test to execute (all by default)")

    parser.add_argument("-r", "--results-dir",
                        dest="results_directory",
                        action="store",
                        default=os.path.join(this_path, 'tests'),
                        type=os.path.abspath,
                        help="Location where test results should be stored.")

    parser.add_argument("--run-gdb",
                        dest="run_gdb",
                        action="store_true",
                        help="Run tests under GDB control.")

    parser.add_argument("--exclude",
                        default=['skipped'],
                        action="append",
                        help="Do not run tests marked with a tag.")

    parser.add_argument("--stop-on-error",
                        dest="stop_on_error",
                        action="store_true",
                        default=False,
                        help="Terminate immediately on the first test failure")

    parser.add_argument("-j", "--jobs",
                        dest="jobs",
                        action="store",
                        default=1,
                        type=int,
                        help="Maximum number of parallel tests")
    parser.add_argument("--keep-temporary-files",
                        dest="keep_temps",
                        action="store_true",
                        default=False,
                        help="Don't clean temporary files on exit")

    if platform != "win32":
        parser.add_argument("-p", "--port",
                            dest="port",
                            action="store",
                            default=None,
                            help="Debug port.")

        parser.add_argument("-s", "--suspend",
                            dest="suspend",
                            action="store_true",
                            default=False,
                            help="Suspend test waiting for a debugger.")

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


def parse_tests_file(path):

    def _process(data, result):
        if data is None:
            return
        for entry in data:
            if entry is None:
                continue
            if isinstance(entry, list):
                _process(entry, result)
            else:
                result.append(entry)

    result = []
    with open(path) as f:
        data = yaml.load(f, Loader=IncludeLoader)
        _process(data, result)
    return result


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

    if options.tests:
        tests_collection = options.tests
    elif options.tests_file is not None:
        tests_collection = parse_tests_file(options.tests_file)
    else:
        tests_collection = []
    options.tests = split_tests_into_groups(tests_collection, options.test_type)

    options.configuration = 'Debug' if options.debug_mode else 'Release'


def register_handler(handler_type, extension, creator, before_parsing=None, after_parsing=None):
    registered_handlers.append({'type': handler_type, 'extension': extension, 'creator': creator, 'before_parsing': before_parsing, 'after_parsing': after_parsing})


def split_tests_into_groups(tests, test_type):

    def _handle_entry(test_type, path, result):
        if not os.path.exists(path):
            print("Path {} does not exist. Quitting ...".format(path))
            return False
        for handler in registered_handlers:
            if (test_type == 'all' or handler['type'] == test_type) and path.endswith(handler['extension']):
                result.append(handler['creator'](path))
        return True

    parallel_group_counter = 0
    test_groups = {}

    for entry in tests:
        if isinstance(entry, dict):
            group_name = list(entry.keys())[0]
            if group_name not in test_groups:
                test_groups[group_name] = []
            for inner_entry in entry[group_name]:
                if not _handle_entry(test_type, inner_entry, test_groups[group_name]):
                    return None
        elif isinstance(entry, str):
            group_name = '__NONE_' + str(parallel_group_counter) + '__'
            parallel_group_counter += 1
            if group_name not in test_groups:
                test_groups[group_name] = []
            if not _handle_entry(test_type, entry, test_groups[group_name]):
                return None
        else:
            print("Unexpected test type: " + entry)
            return None

    return test_groups


def configure_output(options):
    options.output = sys.stdout
    if options.output_file is not None:
        try:
            options.output = open(options.output_file)
        except Exception:
            print("Failed to open output file. Falling back to STDOUT.")


def run_test_group(args):

    group, options, test_id = args

    repeat_counter = 0
    tests_failed = False

    # this function will be called in a separate
    # context (due to the pool.map_async) and
    # needs the stdout to be reconfigured
    configure_output(options)

    while options.repeat_count == 0 or repeat_counter < options.repeat_count:
        repeat_counter += 1

        if options.repeat_count > 1:
            print("Running tests iteration {} of {}...".format(repeat_counter, options.repeat_count))
        elif options.repeat_count == 0:
            print("Running tests iteration {}...".format(repeat_counter))

        for suite in group:
            if not suite.run(options, run_id=test_id if options.jobs != 1 else 0):
                tests_failed = True

        if options.stop_on_error and tests_failed:
            break

    options.output.flush()
    return tests_failed

def print_failed_tests(options):
    for handler in registered_handlers:
        handler_obj = handler['creator']
        failed = handler_obj.find_failed_tests(options.results_directory)

        if failed != None:
            def _print_helper(what):
                for i, fail in enumerate(failed[what]):
                    print("\t{0}. {1}".format(i + 1, fail))

            print("Failed {} critical tests:".format(handler['type']))
            _print_helper('mandatory')
            if 'non_critical' in failed and failed['non_critical']:
                print("Failed {} non-critical tests:".format(handler['type']))
                _print_helper('non_critical')
            print("------")

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

    configure_output(options)

    print("Preparing suites")

    test_id = 0
    args = []
    for group in options.tests.values():
        args.append((group, options, test_id))
        test_id += 1

    for group in options.tests:
        for suite in options.tests[group]:
            suite.check(options, number_of_runs=test_id if options.jobs != 1 else 1)

    for group in options.tests:
        for suite in options.tests[group]:
            res = suite.prepare(options)
            if res is not None and res != 0:
                print("Build failure, not running tests.")
                sys.exit(res)

    print("Starting suites")

    # python3 cannot handle passing
    # 'output' field via 'pool.map_async';
    # the value is restored later
    options.output = None

    if options.jobs == 1:
        tests_failed = False
        for a in args:
            tests_failed |= run_test_group(a)
    else:
        multiprocessing.set_start_method("spawn")
        pool = multiprocessing.Pool(processes=options.jobs)
        # this get is a hack - see: https://stackoverflow.com/a/1408476/980025
        # we use `async` + `get` in order to allow "Ctrl+C" to be handled correctly;
        # otherwise it would not be possible to abort tests in progress
        tests_failed = any(pool.map_async(run_test_group, args).get(999999))
        pool.close()
        print("Waiting for all processes to exit")
        pool.join()

    configure_output(options)

    print("Cleaning up suites")

    for group in options.tests:
        for suite in options.tests[group]:
            suite.cleanup(options)

    options.output.flush()
    if options.output is not sys.stdout:
        options.output.close()

    if tests_failed:
        print("Some tests failed :( See the list of failed tests below and logs for details!")
        print_failed_tests(options)
        sys.exit(1)
    print("Tests finished successfully :)")
