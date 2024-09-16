# pylint: disable=C0301,C0103,C0111
from __future__ import print_function
from collections import defaultdict, namedtuple
from sys import platform
import os
import sys
import argparse
import subprocess
import yaml
import multiprocessing

this_path = os.path.abspath(os.path.dirname(__file__))
registered_handlers = []
TestResult = namedtuple('TestResult', ('ok', 'log_file'))


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
    parser = argparse.ArgumentParser(
        epilog="""The -n/--repeat and -N/--retry options are not mutually exclusive.
        For example, "-n2 -N5" would repeat twice running the test(s) with a "tolerance"
        of up to 4 failures each. This means each test case would run from 2 to 10 times."""
    )

    parser.add_argument("tests",
                        help="List of test files.",
                        nargs='*')

    parser.add_argument("-f", "--fixture",
                        dest="fixture",
                        help="Fixture to test.",
                        metavar="FIXTURE")

    parser.add_argument("-n", "--repeat",
                        dest="iteration_count",
                        nargs="?",
                        type=int,
                        const=0,
                        default=1,
                        help="Repeat tests a number of times (no-flag: 1, no-value: infinite).")

    parser.add_argument("-N", "--retry",
                        dest="retry_count",
                        type=int,
                        default=1,
                        help="Run tests up to a number of times (like -n, but stops on success; must be >0)")

    parser.add_argument("-d", "--debug",
                        dest="debug_mode",
                        action="store_true",
                        default=False,
                        help="Debug mode.")

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
                        help="Type of test to execute (all by default).")

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

    parser.add_argument("--include",
                        default=None,
                        action="append",
                        help="Run only tests marked with a tag.")

    parser.add_argument("--exclude",
                        default=['skipped'],
                        action="append",
                        help="Do not run tests marked with a tag.")

    parser.add_argument("--stop-on-error",
                        dest="stop_on_error",
                        action="store_true",
                        default=False,
                        help="Terminate immediately on the first test failure.")

    parser.add_argument("-j", "--jobs",
                        dest="jobs",
                        action="store",
                        default=1,
                        type=int,
                        help="Maximum number of parallel tests.")
    parser.add_argument("--keep-temporary-files",
                        dest="keep_temps",
                        action="store_true",
                        default=False,
                        help="Don't clean temporary files on exit.")

    parser.add_argument("--save-logs",
                        choices=("onfail", "always"),
                        default="onfail",
                        help="When to save Renode logs. Defaults to 'onfail'. This also affects --keep-renode-output, if enabled.")

    parser.add_argument("--perf-output-path",
                        dest="perf_output_path",
                        default=None,
                        help="Generate perf.data from test in specified directory")

    parser.add_argument("--runner",
                        dest="runner",
                        action="store",
                        default=None,
                        help=".NET runner.")

    parser.add_argument("--net",
                        dest="discarded",
                        action="store_const",
                        const="dotnet",
                        help="Flag is deprecated and has no effect.")

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

    if options.remote_server_full_directory is not None:
        if not os.path.isabs(options.remote_server_full_directory):
            options.remote_server_full_directory = os.path.join(this_path, options.remote_server_full_directory)
    else:
        options.remote_server_full_directory = os.path.join(options.remote_server_directory_prefix, options.configuration)

    try:
        # Try to infer the runner based on the build type
        with open(os.path.join(options.remote_server_full_directory, "build_type"), "r") as f:
            options.runner = f.read().strip()
        if platform == "win32" and options.runner != "dotnet":
            options.runner = "none" # .NET Framework applications run natively on Windows
    except:
        # Fallback to the explicitly provided runner or platform's default if nothing was passed
        if options.runner is None:
            options.runner = "mono" if platform.startswith("linux") or platform == "darwin" else "none"

    # Apply the dotnet telemetry optout in this script instead of the shell wrappers as it's
    # portable between OSes
    if options.runner == 'dotnet':
        os.putenv("DOTNET_CLI_TELEMETRY_OPTOUT", "1")


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


# Raised exceptions typically cause `map_async` to fail after all the tests have been processed.
# Let's print them with traceback right away to know the exact moment and raise the exception to
# fail `map_async` too.
def task(args):
    # Exception handling needs to be adjusted if there's more than one suite in a parallel group.
    group = args[0]
    assert len(group) == 1, "Parallel task started with more than one suite!"

    try:
        return run_test_group(args)
    except Exception as e:
        print(f"Exception occurred when running {group[0].path}:")
        import traceback
        traceback.print_exception(e)
        raise


def run_test_group(args):

    group, options, test_id = args

    iteration_counter = 0
    tests_failed = False
    log_files = set()

    # this function will be called in a separate
    # context (due to the pool.map_async) and
    # needs the stdout to be reconfigured
    configure_output(options)

    while options.iteration_count == 0 or iteration_counter < options.iteration_count:
        iteration_counter += 1

        if options.iteration_count > 1:
            print("Running tests iteration {} of {}...".format(iteration_counter, options.iteration_count))
        elif options.iteration_count == 0:
            print("Running tests iteration {}...".format(iteration_counter))

        for suite in group:
            retry_suites_counter = 0
            should_retry_suite = True
            while should_retry_suite and retry_suites_counter < options.retry_count:
                retry_suites_counter += 1

                if retry_suites_counter > 1:
                    print("Retrying suite, attempt {} of {}...".format(retry_suites_counter, options.retry_count))

                # we need to collect log files here instead of appending to a global list
                # in each suite runner because this function will be called in a multiprocessing
                # context when using the --jobs argument, as mentioned above
                ok, suite_log_files = suite.run(options,
                                                run_id=test_id if options.jobs != 1 else 0,
                                                iteration_index=iteration_counter,
                                                suite_retry_index=retry_suites_counter - 1)
                log_files.update((type(suite), log_file) for log_file in suite_log_files)
                if ok:
                    tests_failed = False
                    should_retry_suite = False
                else:
                    tests_failed = True
                    should_retry_suite = suite.should_retry_suite(options, iteration_counter, retry_suites_counter - 1)
                    if options.retry_count > 1 and not should_retry_suite:
                        print("No Robot<->Renode connection issues were detected to warrant a suite retry - giving up.")

        if options.stop_on_error and tests_failed:
            break

    options.output.flush()
    return (tests_failed, log_files)

def print_failed_tests(options):
    for handler in registered_handlers:
        handler_obj = handler['creator']
        failed = handler_obj.find_failed_tests(options.results_directory)

        if failed is not None:
            def _print_helper(what):
                for i, fail in enumerate(failed[what]):
                    print("\t{0}. {1}".format(i + 1, fail))

            print("Failed {} critical tests:".format(handler['type']))
            _print_helper('mandatory')
            if 'non_critical' in failed and failed['non_critical']:
                print("Failed {} non-critical tests:".format(handler['type']))
                _print_helper('non_critical')
            print("------")

def print_rerun_trace(options):
    for handler in registered_handlers:
        handler_obj = handler["creator"]
        reruns = handler_obj.find_rerun_tests(options.results_directory)
        if not reruns:
            continue

        did_retry = False
        if options.retry_count != 1:
            for trace in reruns.values():
                test_case_retry_occurred = any([x["nth"] > 1 for x in trace])
                suite_retry_occurred = any([x["label"].endswith("retry1") for x in trace])
                if test_case_retry_occurred or suite_retry_occurred:
                    did_retry = True
                    break
        if options.iteration_count == 1 and not did_retry:
            return
        elif options.iteration_count == 1 and did_retry:
            print("Some tests were retried:")
        elif options.iteration_count != 1 and not did_retry:
            print(f"Ran {options.iteration_count} iterations:")
        elif options.iteration_count != 1 and did_retry:
            print(f"Ran {options.iteration_count} iterations, some tests were retried:")

        trace_index = 0
        for test, trace in reruns.items():
            n_runs = sum([x["nth"] for x in trace])
            has_failed = not all(x["nth"] == 1 and x["status"] == "PASS" for x in trace)
            if n_runs == 1 or not has_failed:
                # Don't mention tests that were run only once or that never
                # failed. It CAN happen that n_runs > 1 and has_failed == False;
                # when another test in the same suite triggers a suite retry.
                continue
            trace_index += 1
            print(f"\t{trace_index}. {test} was started {n_runs} times:")
            iteration_index = 1
            suite_retry_index = 0
            for i, trace_entry in enumerate(trace, 1):
                label, status, nth, tags, crash = trace_entry.values()
                print("\t     {}:  {} {:<9} {}{}{}".format(
                    label, nth,
                    "attempt," if nth == 1 else "attempts,",
                    status,
                    f" [{', '.join(tags)}]" if tags else "",
                    " (crash detected)" if crash else "",
                ))
                if label == "iteration":
                    iteration_index += 1
                else:
                    suite_retry_index += 1
        print("------")


def run():
    parser = prepare_parser()
    for handler in registered_handlers:
        if 'before_parsing' in handler and handler['before_parsing'] is not None:
            handler['before_parsing'](parser)

    options = parser.parse_args()
    handle_options(options)

    if not options.tests:
        sys.exit(1)

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
        tests_failed, logs = zip(*map(run_test_group, args))
    else:
        multiprocessing.set_start_method("spawn")
        pool = multiprocessing.Pool(processes=options.jobs)
        # this get is a hack - see: https://stackoverflow.com/a/1408476/980025
        # we use `async` + `get` in order to allow "Ctrl+C" to be handled correctly;
        # otherwise it would not be possible to abort tests in progress
        tests_failed, logs = zip(*pool.map_async(task, args).get(999999))
        pool.close()
        print("Waiting for all processes to exit")
        pool.join()

    tests_failed = any(tests_failed)
    logs = set().union(*logs)
    logs_per_type = defaultdict(lambda: [])
    for suite_type, log in logs:
        logs_per_type[suite_type].append(log)

    configure_output(options)

    print("Cleaning up suites")

    for group in options.tests:
        for suite in options.tests[group]:
            type(suite).log_files = logs_per_type[type(suite)]
            suite.cleanup(options)

    options.output.flush()
    if options.output is not sys.stdout:
        options.output.close()

    if tests_failed:
        print("Some tests failed :( See the list of failed tests below and logs for details!")
        print_failed_tests(options)
        print_rerun_trace(options)
        sys.exit(1)
    print("Tests finished successfully :)")
    print_rerun_trace(options)
