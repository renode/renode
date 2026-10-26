# pylint: disable=C0301,C0103,C0111
from __future__ import print_function
from collections import defaultdict, namedtuple
import contextlib
from itertools import dropwhile
from sys import platform
import os
import sys
import argparse
import subprocess
import yaml
import multiprocessing
from multiprocessing.pool import ApplyResult, Pool
from multiprocessing.sharedctypes import Synchronized
import psutil
from typing import Any, Collection, MutableMapping, MutableSequence, NamedTuple, Optional
from pathlib import Path
from enum import Enum
import segmenting
import monitoring
import unstable_tests

this_path = os.path.abspath(os.path.dirname(__file__))
registered_handlers = []
TestResult = namedtuple('TestResult', ('ok', 'log_file'))
GroupIndex = int
ProcessId = int
SuiteLogFiles = set[tuple[type, str]]


class GroupArgs(NamedTuple):
    group_index: GroupIndex
    suites: list[Any]
    total_number_of_suites: int
    options: argparse.Namespace


class GroupProgress(NamedTuple):
    pid: ProcessId
    finished_suites: int
    log_files: SuiteLogFiles


class GroupResult(NamedTuple):
    failed: bool
    log_files: SuiteLogFiles


class PoolResult(NamedTuple):
    group_results: list[GroupResult]
    dead_worker_suites: list[str]
    not_run_suites: list[str]


shared_suite_counter = None
shared_active_suites: Optional[MutableSequence[str]] = None
shared_group_progress: Optional[MutableMapping[GroupIndex, GroupProgress]] = None
shared_worker_pids: Optional[MutableSequence[ProcessId]] = None

DEAD_WORKER_CHECK_INTERVAL_SECONDS = 5
DEFAULT_RENODE_BINARY_NAME = 'Renode.dll' if platform != 'win32' else 'RenodeWPF.dll'
# Not a TestTag because it's not a real tag, it's the default.
CRITICAL_TEST = 'mandatory'

class TestTag(str, Enum):
    SKIPPED = "skipped"
    NON_CRITICAL = "non_critical"
    UNSTABLE = "unstable"
    RETRIED_ATTEMPT = "retried_attempt"

    def __str__(self):
        return self.value

    def __format__(self, format_spec):
        return format(self.value, format_spec)


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
                    v = next(iter(val.values()))
                    _append_prefix(v, prefix)
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

    parser.add_argument("--dry-run",
                        dest="dry_run",
                        action="store_true",
                        default=False,
                        help="Loads the given tests and splits them into subsets (if --subsets is specified). Does not run any tests.")

    parser.add_argument("-t", "--tests",
                        dest="tests_file",
                        action="store",
                        default=None,
                        help="Path to a file with a list of assemblies with tests to run. This is ignored if any test file is passed as positional argument.")

    parser.add_argument("-T", "--type",
                        dest="test_type",
                        action="store",
                        choices=("all", "robot", "nunit"),
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
                        default=['excluded'],
                        action="append",
                        help="Do not run tests marked with a tag.")

    parser.add_argument("--skip",
                        default=['skipped'],
                        action="append",
                        help="Skip tests marked with a tag.")

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

    unstable_tests.add_args(parser)
    segmenting.add_args(parser)

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

    monitoring.add_args(parser)

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
    test_groups = split_tests_into_groups(tests_collection, options.test_type)
    if not test_groups:
        print("No input suites")
        sys.exit(1)

    verify_suite_files_unique(test_groups)
    options.tests = select_test_groups(test_groups, options)

    options.configuration = 'Debug' if options.debug_mode else 'Release'

    if options.stats_file:
        options.stats = segmenting.parse_stats_file(options.stats_file)
    else:
        options.stats = {}

    if options.known_unstable_file:
        options.known_unstable = unstable_tests.parse_file(options.known_unstable_file)
        if options.tests:
            unstable_tests.annotate_tests(options.tests, options.known_unstable)
    else:
        options.known_unstable = []

    if options.remote_server_full_directory is not None:
        if not os.path.isabs(options.remote_server_full_directory):
            options.remote_server_full_directory = os.path.join(this_path, options.remote_server_full_directory)
    else:
        options.remote_server_full_directory = os.path.join(options.remote_server_directory_prefix, options.configuration)

    # Apply the dotnet telemetry optout in this script instead of the shell wrappers as it's
    # portable between OSes
    os.putenv("DOTNET_CLI_TELEMETRY_OPTOUT", "1")


def register_handler(handler_type, extensions, creator, before_parsing=None, after_parsing=None):
    """
    Register a test suite handler.

    Parameters:
        handler_type (str): Type of test
        extensions (str|tuple): File extensions used to filter tests files.
        creator: Class of the test suite object, instantiated with the test suite file path.
        before_parsing: Function called before arguments parsing. None by default.
        after_parsing: Function called after arguments parsing. None by default.
    """
    registered_handlers.append({'type': handler_type, 'extensions': extensions, 'creator': creator, 'before_parsing': before_parsing, 'after_parsing': after_parsing})


def split_tests_into_groups(tests, test_type):

    def _handle_entry(test_type, path, result):
        if not os.path.exists(path):
            print("Path {} does not exist. Quitting ...".format(path))
            return False
        for handler in registered_handlers:
            if (test_type == 'all' or handler['type'] == test_type) and path.endswith(handler['extensions']):
                # Ensure consistent path separators, even on Windows
                path = Path(path).as_posix()
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


def print_suite_progress(finished_suites: int, total_number_of_suites: int) -> None:
    print(f"+++++ Finished suite \033[95m{finished_suites}/{total_number_of_suites}\033[0m", flush=True)


def run_test_group(args: GroupArgs) -> GroupResult:

    global shared_suite_counter
    global shared_active_suites
    group_index, group, total_number_of_suites, options = args

    iteration_counter = 0
    group_failed = False
    finished_suites = 0
    log_files: SuiteLogFiles = set()

    def report_progress() -> None:
        # The manager holds a copy, so send it the latest `finished_suites` and `log_files`.
        if shared_group_progress is not None:
            shared_group_progress[group_index] = GroupProgress(os.getpid(), finished_suites, log_files)

    report_progress()

    # this function will be called in a separate
    # context (a worker process of the pool) and
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
            suite_failed = False

            if shared_active_suites is None:
                print("warning: `shared_active_suites` must be set for suite tracking to work")
                shared_active_suites = []
            shared_active_suites.append(suite.path)

            try:
                while should_retry_suite and retry_suites_counter < options.retry_count:
                    retry_suites_counter += 1

                    if retry_suites_counter > 1:
                        print("Retrying suite, attempt {} of {}...".format(retry_suites_counter, options.retry_count))

                    # we need to collect log files here instead of appending to a global list
                    # in each suite runner because this function will be called in a multiprocessing
                    # context when using the --jobs argument, as mentioned above
                    ok, suite_log_files = suite.run(options,
                                                    iteration_index=iteration_counter,
                                                    suite_retry_index=retry_suites_counter - 1)
                    log_files.update((type(suite), log_file) for log_file in suite_log_files)
                    report_progress()
                    if ok:
                        suite_failed = False
                        should_retry_suite = False
                    else:
                        suite_failed = True
                        should_retry_suite = suite.should_retry_suite(options, iteration_counter, retry_suites_counter - 1)
                        if options.retry_count > 1 and not should_retry_suite:
                            print("No Robot<->Renode connection issues were detected to warrant a suite retry - giving up.")
            except Exception as e:
                print(f"Exception occurred when running {suite.path}:")
                import traceback
                traceback.print_exception(e)
                raise
            finally:
                shared_active_suites.remove(suite.path)

            if shared_suite_counter is None:
                print("warning: `shared_suite_counter` must be set for suite counting to work")
                current_counter_value = -1 
            elif isinstance(shared_suite_counter, int):
                shared_suite_counter += 1
                current_counter_value = shared_suite_counter 
            else:
                with shared_suite_counter.get_lock():
                    shared_suite_counter.value += 1
                    current_counter_value = shared_suite_counter.value

            print_suite_progress(current_counter_value, total_number_of_suites)
            finished_suites += 1
            report_progress()

            if suite_failed:
                group_failed = True
        if options.stop_on_error and group_failed:
            break

    options.output.flush()
    return GroupResult(group_failed, log_files)

def print_failed_tests(options):
    for handler in registered_handlers:
        handler_obj = handler['creator']
        failed = handler_obj.find_failed_tests(options.results_directory)

        if failed is not None:
            print_numbered_list("Failed {} critical tests:".format(handler["type"]), failed.get(CRITICAL_TEST, ()))
            print_numbered_list("Failed {} unstable tests:".format(handler["type"]), failed.get(TestTag.UNSTABLE, ()))
            print_numbered_list(
                "Failed {} non-critical tests:".format(handler["type"]), failed.get(TestTag.NON_CRITICAL, ())
            )
            print("------")


def print_numbered_list(title: str, items: Collection[str]) -> None:
    if items:
        print(title)
        for i, item in enumerate(items):
            print("\t{0}. {1}".format(i + 1, item))


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

# analyzes logs before they are cleaned up to determine
# if any test failures were caused by a Renode crash.
#
# returns:
# - TRUE only when a test failed on its final run AND
#   that last failure was caused by a crash
# - FALSE if the test passed or when one of the runs crashed
#   but the final retry failed for other reasons such as wrong result
#
# when running multiple test suites returns TRUE if ANY failed due to a crash.
def failed_due_to_crash(options, groups_segment) -> bool:
    for (_, group_suites) in groups_segment:
        for suite in group_suites:
            if suite.tests_failed_due_to_renode_crash():
                return True

    return False


def verify_suite_files_unique(groups: dict[str, Any]):
    suite_file_paths = [
        Path(suite.path) for suites in groups.values() for suite in suites
    ]

    paths_by_filename = defaultdict(list)
    for path in suite_file_paths:
        paths_by_filename[path.name].append(path)

    duplicates = {
        filename: paths
        for filename, paths in paths_by_filename.items()
        if len(paths) > 1
    }

    if duplicates:
        print("ERROR: Duplicate suite file names are not allowed. Found duplicates:")
        for filename, paths in duplicates.items():
            print(f"  {filename}:")
            for path in paths:
                print(f"    - {path}")
        sys.exit(1)


def print_suite_files(segment: segmenting.GroupsSegment):
    segment_num = segment.subset.segment
    max_segments = segment.subset.max_segments 
    segment_test_file_paths = segment.test_file_paths
    groups_segment  = segment.groups

    test_file_path_count = len(segment_test_file_paths)
    suites_list_header = (
        (
            f"Will run segment {segment_num}/{max_segments}, "
            f"consisting of the following {test_file_path_count} test files:"
        )
        if max_segments > 1
        else f"Will run the following {test_file_path_count} test files:"
    )
    print(suites_list_header)

    for group, suites in groups_segment:
        is_group = not group.startswith("__NONE_")
        padding = ""
        if is_group:
            print(f"  - {group}:")
            padding = "  "
        for suite in suites:
            print(f"  {padding}- {suite.path}")

    print("")


def on_overload_detected():
    if not shared_active_suites:
        return

    active_suite_count = len(shared_active_suites)
    verb = "are" if active_suite_count > 1 else "is"
    plural_s = "s" if active_suite_count > 1 else ""
    print(
        f"There {verb} {active_suite_count} currently running test suite{plural_s}:",
        flush=True,
    )
    for suite in shared_active_suites:
        print(f"  - {suite}", flush=True)
    print("", flush=True)


def init_worker_process(
    counter: Synchronized,
    active_suites: MutableSequence[str],
    group_progress: MutableMapping[GroupIndex, GroupProgress],
    worker_pids: MutableSequence[ProcessId],
) -> None:
    global shared_suite_counter
    shared_suite_counter = counter 
    global shared_active_suites
    shared_active_suites = active_suites
    global shared_group_progress
    shared_group_progress = group_progress
    worker_pids.append(os.getpid())


def count_rest_of_group(group_args: GroupArgs, finished_suites: int) -> None:
    assert shared_suite_counter is not None, "The suite counter must have been created at this point"
    rest = len(group_args.suites) * group_args.options.iteration_count - finished_suites
    # Nothing is left when the worker died after its last suite. With `-n 0` the group runs without
    # end, so there is no total to reach.
    if rest <= 0:
        return
    with shared_suite_counter.get_lock():
        shared_suite_counter.value += rest
        current_counter_value = shared_suite_counter.value
    print_suite_progress(current_counter_value, group_args.total_number_of_suites)


def record_worker_children(pid: ProcessId, worker_children: dict[ProcessId, list[psutil.Process]]) -> None:
    with contextlib.suppress(psutil.Error):
        # A worker that has just died lists no children any more, so keep the last ones seen.
        if children := psutil.Process(pid).children(recursive=True):
            worker_children[pid] = children


def fail_dead_worker_group(
    group_args: GroupArgs,
    progress: GroupProgress,
    worker_children: list[psutil.Process],
    dead_worker_suites: list[str],
    not_run_suites: list[str],
) -> None:
    assert shared_active_suites is not None, "The active suite list must have been created at this point"
    suite_paths = ", ".join(suite.path for suite in group_args.suites)
    print(
        f"!!!!! Worker process {progress.pid} died while running the group with {suite_paths}, counting the group as failed",
        flush=True,
    )

    # Renode and the other processes that the worker started would keep running and holding memory.
    for child in worker_children:
        with contextlib.suppress(psutil.Error):
            child.kill()
            print(f"!!!!! Killed process {child.pid} that worker process {progress.pid} started", flush=True)

    # The suite that the worker was running and the suites after it.
    unfinished_suites = list(dropwhile(lambda suite: suite.path not in shared_active_suites, group_args.suites))
    if unfinished_suites:
        dead_suite, *not_run = unfinished_suites
        shared_active_suites.remove(dead_suite.path)
        dead_worker_suites.append(dead_suite.path)
        not_run_suites.extend(suite.path for suite in not_run)

    # No worker will run the rest of the group now, so count its suites as finished.
    count_rest_of_group(group_args, progress.finished_suites)


def find_unstarted_groups(
    pending: list[GroupIndex], results: list[ApplyResult[GroupResult]], running_workers: set[ProcessId]
) -> set[GroupIndex]:
    assert shared_group_progress is not None and shared_worker_pids is not None, (
        "The shared state must have been created at this point"
    )
    # If a worker dies right after it picks up a group, the group never gets a progress entry and nobody
    # runs it. A group still waiting in the queue has no entry either. But if some worker is idle, the queue
    # must be empty, since that worker would have picked the group up. So then a group with no entry is lost.
    if not any(pid not in running_workers and psutil.pid_exists(pid) for pid in shared_worker_pids):
        return set()
    return {
        group_index
        for group_index in pending
        if group_index not in shared_group_progress and not results[group_index].ready()
    }


def fail_unstarted_group(group_args: GroupArgs, not_run_suites: list[str]) -> None:
    suite_paths = ", ".join(suite.path for suite in group_args.suites)
    print(
        f"!!!!! A worker process died before it started the group with {suite_paths}, counting the group as failed",
        flush=True,
    )
    not_run_suites.extend(suite.path for suite in group_args.suites)
    count_rest_of_group(group_args, finished_suites=0)


def run_test_groups_in_pool(pool: Pool, args: list[GroupArgs]) -> PoolResult:
    # `multiprocessing.Pool` replaces a worker process that dies, for example when the OOM killer
    # stops it, but never returns a result for the group that this worker was running. Waiting
    # for all results would then block forever, so find such groups by the pid of their worker.
    assert shared_group_progress is not None, "The group progress must have been created at this point"
    results: list[ApplyResult[GroupResult]] = [pool.apply_async(run_test_group, (group_args,)) for group_args in args]
    dead_worker_log_files: dict[GroupIndex, SuiteLogFiles] = {}
    dead_worker_suites: list[str] = []
    not_run_suites: list[str] = []
    # The processes that each worker had started at the last check, such as Renode.
    worker_children: dict[ProcessId, list[psutil.Process]] = {}
    # The groups that had not started at the last check while a worker was idle.
    unstarted_groups: set[GroupIndex] = set()
    while True:
        pending = [
            group_index
            for group_index, result in enumerate(results)
            if group_index not in dead_worker_log_files and not result.ready()
        ]
        if not pending:
            break

        # Pause before the next check of all groups. Waiting on a group instead of sleeping
        # lets the run end as soon as the last group finishes.
        results[pending[0]].wait(DEAD_WORKER_CHECK_INTERVAL_SECONDS)

        running_workers: set[ProcessId] = set()
        for group_index in pending:
            progress: Optional[GroupProgress] = shared_group_progress.get(group_index)
            if progress is None:
                continue
            # A worker can die right after it sends the result of this group. Checking the pid first gives
            # the pool time to receive that result before we check it.
            if psutil.pid_exists(progress.pid):
                running_workers.add(progress.pid)
                record_worker_children(progress.pid, worker_children)
            elif not results[group_index].ready():
                # Keep the results of the suites that finished before the worker died.
                dead_worker_log_files[group_index] = progress.log_files
                fail_dead_worker_group(
                    args[group_index],
                    progress,
                    worker_children.pop(progress.pid, []),
                    dead_worker_suites,
                    not_run_suites,
                )

        previous_unstarted_groups = unstarted_groups
        unstarted_groups = find_unstarted_groups(pending, results, running_workers)
        # A group must stay unstarted for two checks, so that a worker that has just taken it can record it.
        for group_index in sorted(unstarted_groups & previous_unstarted_groups):
            dead_worker_log_files[group_index] = set()
            fail_unstarted_group(args[group_index], not_run_suites)

    if dead_worker_log_files:
        # The pool still waits for the task of the dead worker, so closing and joining it would never return.
        pool.terminate()

    group_results: list[GroupResult] = [
        GroupResult(failed=True, log_files=dead_worker_log_files[group_index])
        if group_index in dead_worker_log_files
        else result.get()
        for group_index, result in enumerate(results)
    ]
    return PoolResult(group_results, dead_worker_suites, not_run_suites)


def select_test_groups(groups: dict[str, list[Any]], options: argparse.Namespace) -> dict[str, list[Any]]:
    selected_groups: dict[str, list[Any]] = {}
    for group, suites in groups.items():
        selected: list[Any] = [suite for suite in suites if suite.select_tests(options)]
        if selected:
            selected_groups[group] = selected

    return selected_groups


def run():
    global shared_suite_counter
    global shared_active_suites
    global shared_group_progress
    global shared_worker_pids
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

    segment = segmenting.segment_groups(options)
    segment_num = segment.subset.segment
    max_segments = segment.subset.max_segments 
    segment_test_file_paths = segment.test_file_paths
    groups_segment  = segment.groups
    total_number_of_suites = len(segment_test_file_paths) * options.iteration_count

    print_suite_files(segment)

    if options.dry_run:
        print("Exiting early due to --dry-run")
        exit(0)

    if not groups_segment:
        print("No tests selected for this segment.")
        return

    args = []
    for index, (_, group_suites) in enumerate(groups_segment):
        args.append(GroupArgs(index, group_suites, total_number_of_suites, options))

    for (_, group_suites) in groups_segment:
        for suite in group_suites:
            res = suite.prepare(options)
            if res is not None and res != 0:
                print("Build failure, not running tests.")
                sys.exit(res)

    print("Starting suites")

    # python3 cannot handle passing
    # 'output' field to the worker processes;
    # the value is restored later
    options.output = None

    # Prepare job inputs
    if options.jobs == 1:
        shared_suite_counter = 0
        shared_active_suites = []
        pool = None
    else:
        multiprocessing.set_start_method("spawn")
        # To share a counter between all the worker processes, we must create a 
        # multiprocessing.Value that gets passed to each worker process through
        # its initializer function (by assigning a global variable).
        shared_suite_counter = multiprocessing.Value("i", 0)
        # Like the counter, we need to use a multiprocessing.Manager to create
        # a shared list that keeps track of the currently running suites,
        # a shared dictionary with the worker process of each group and the
        # number and log files of its finished suites, and a shared list of
        # all worker processes.
        manager = multiprocessing.Manager()
        shared_active_suites = manager.list()
        shared_group_progress = manager.dict()
        shared_worker_pids = manager.list()
        pool = multiprocessing.Pool(
            initializer=init_worker_process, 
            initargs=(shared_suite_counter, shared_active_suites, shared_group_progress, shared_worker_pids),
            processes=options.jobs,
        )

    # Start monitoring
    if options.enable_system_load_monitoring:
        system_monitor = monitoring.SystemLoadMonitor(
            options.system_load_sample_interval_seconds,
            options.system_load_spike_factor,
            options.system_load_window_size,
            options.ram_warn_threshold_percentage,
            options.cpu_warn_threshold_percentage,
            on_overload_detected,
        )
        system_monitor.start()
    else:
        system_monitor = None

    # Run test job(s)
    dead_worker_suites: list[str] = []
    not_run_suites: list[str] = []
    if options.jobs == 1:
        tests_failed, logs = zip(*map(run_test_group, args))
    else:
        assert pool, "Pool must have been instantiated at this point"
        group_results, dead_worker_suites, not_run_suites = run_test_groups_in_pool(pool, args)
        tests_failed, logs = zip(*group_results)
        pool.close()
        print("Waiting for all processes to exit")
        pool.join()

    if system_monitor:
        system_monitor.stop()

    tests_failed = any(tests_failed)
    logs = set().union(*logs)
    logs_per_type = defaultdict(lambda: [])
    for suite_type, log in logs:
        logs_per_type[suite_type].append(log)

    configure_output(options)

    print("Cleaning up suites")

    # check if renode crash caused a failed test based on logs for tested suites
    # before the log files are cleaned up
    test_failed_due_to_crash: bool = tests_failed and failed_due_to_crash(options, groups_segment)

    for (_, group_suites) in groups_segment:
        for suite in group_suites:
            type(suite).log_files = logs_per_type[type(suite)]
            suite.cleanup(options)

    options.output.flush()
    if options.output is not sys.stdout:
        options.output.close()

    if max_segments > 1:
        print( f"Ran segment {segment_num}/{max_segments}, consisting of {total_number_of_suites} test files.")
    if tests_failed:
        print("Some tests failed :( See the list of failed tests below and logs for details!")

    print_failed_tests(options)
    print_numbered_list("Worker process died while running:", dead_worker_suites)
    print_numbered_list("Did not run because the worker process died:", not_run_suites)

    if tests_failed:
        print_rerun_trace(options)
        if test_failed_due_to_crash:
            print('Renode crashed during testing and caused a failure', file=sys.stderr)
            sys.exit(2)
        sys.exit(1)
    print("Tests finished successfully :)")
    print_rerun_trace(options)
