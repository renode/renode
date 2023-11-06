# pylint: disable=C0301,C0103,C0111
from __future__ import print_function
from sys import platform
import os
import time
import sys
import socket
import fnmatch
import subprocess
import psutil
import shutil
import tempfile
import uuid
from time import monotonic, sleep

import robot
import xml.etree.ElementTree as ET

from tests_engine import TestResult

this_path = os.path.abspath(os.path.dirname(__file__))


def install_cli_arguments(parser):
    group = parser.add_mutually_exclusive_group()

    group.add_argument("--robot-framework-remote-server-full-directory",
                       dest="remote_server_full_directory",
                       action="store",
                       help="Full location of robot framework remote server binary.")

    group.add_argument("--robot-framework-remote-server-directory-prefix",
                       dest="remote_server_directory_prefix",
                       action="store",
                       default=os.path.join(this_path, '../output/bin'),
                       help="Directory of robot framework remote server binary. This is concatenated with current configuration to create full path.")

    parser.add_argument("--robot-framework-remote-server-name",
                        dest="remote_server_name",
                        action="store",
                        default="Renode.exe",
                        help="Name of robot framework remote server binary.")

    parser.add_argument("--robot-framework-remote-server-port", "-P",
                        dest="remote_server_port",
                        action="store",
                        default=0,
                        type=int,
                        help="Port of robot framework remote server binary. Use '0' to automatically select any unused private port")

    parser.add_argument("--enable-xwt",
                        dest="enable_xwt",
                        action="store_true",
                        default=False,
                        help="Enables support for XWT.")

    parser.add_argument("--show-log",
                        dest="show_log",
                        action="store_true",
                        default=False,
                        help="Display log messages in console (might corrupt robot summary output).")

    parser.add_argument("--verbose",
                        dest="verbose",
                        action="store_true",
                        default=False,
                        help="Print verbose info from Robot Framework.")

    parser.add_argument("--hot-spot",
                        dest="hotspot",
                        action="store",
                        default=None,
                        help="Test given hot spot action.")

    parser.add_argument("--variable",
                        dest="variables",
                        action="append",
                        default=None,
                        help="Variable to pass to Robot.")

    parser.add_argument("--css-file",
                        dest="css_file",
                        action="store",
                        default=os.path.join(this_path, '../lib/resources/styles/robot.css'),
                        help="Custom CSS style for the result files.")

    parser.add_argument("--runner",
                        dest="runner",
                        action="store",
                        default="mono" if platform.startswith("linux") or platform == "darwin" else "none",
                        help=".NET runner")

    parser.add_argument("--debug-on-error",
                        dest="debug_on_error",
                        action="store_true",
                        default=False,
                        help="Enables the Renode User Interface when test fails")

    parser.add_argument("--cleanup-timeout",
                        dest="cleanup_timeout",
                        action="store",
                        default=3,
                        type=int,
                        help="Robot frontend process cleanup timeout")

    parser.add_argument("--listener",
                        action="append",
                        help="Path to additional progress listener (can be provided many times)")

    parser.add_argument("--renode-config",
                        dest="renode_config",
                        action="store",
                        default=None,
                        help="Path to the Renode config file")
    
    parser.add_argument("--kill-stale-renode-instances",
                        dest="autokill_renode",
                        action="store_true",
                        default=False,
                        help="Automatically kill stale Renode instances without asking")

    parser.add_argument("--gather-execution-metrics",
                        dest="execution_metrics",
                        action="store_true",
                        default=False,
                        help="Gather execution metrics for each suite")


def verify_cli_arguments(options):
    # port is not available on Windows
    if platform != "win32":
        if options.port == str(options.remote_server_port):
            print('Port {} is reserved for Robot Framework remote server and cannot be used for remote debugging.'.format(options.remote_server_port))
            sys.exit(1)
        if options.port is not None and options.jobs != 1:
            print("Debug port cannot be used in parallel runs")
            sys.exit(1)

    if options.css_file:
        if not os.path.isabs(options.css_file):
            options.css_file = os.path.join(this_path, options.css_file)

        if not os.path.isfile(options.css_file):
            print("Unable to find provided CSS file: {0}.".format(options.css_file))
            sys.exit(1)

    if options.remote_server_port != 0 and options.jobs != 1:
        print("Parallel execution and fixed Robot port number options cannot be used together")
        sys.exit(1)


def is_process_running(pid):
    if not psutil.pid_exists(pid):
        return False
    proc = psutil.Process(pid)
    # docs note: is_running() will return True also if the process is a zombie (p.status() == psutil.STATUS_ZOMBIE)
    return proc.is_running() and proc.status() != psutil.STATUS_ZOMBIE


def is_port_available(port, autokill):
    port_handle = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    available = False
    try:
        port_handle.bind(("localhost", port))
        port_handle.close()
        available = True
    except:
        available = can_be_freed_by_killing_other_job(port, autokill)
    return available


def can_be_freed_by_killing_other_job(port, autokill):
    if not sys.stdin.isatty():
        return
    try:
        for proc in [psutil.Process(pid) for pid in psutil.pids()]:
            if '--robot-server-port' in proc.cmdline() and str(port) in proc.cmdline():
                if not is_process_running(proc.pid):
                    # process is zombie
                    continue

                if autokill:
                    result = 'y'
                else:
                    print('It seems that Renode process (pid {}, name {}) is currently running on port {}'.format(proc.pid, proc.name(), port))
                    result = input('Do you want me to kill it? [y/N] ')

                if result in ['Y', 'y']:
                    proc.kill()
                    return True
                break
    except Exception:
        # do nothing here
        pass
    return False


class KeywordsFinder(robot.model.SuiteVisitor):
    def __init__(self, keyword):
        self.keyword = keyword
        self.occurences = 0
        self.arguments = []


    def visit_keyword(self, keyword):
        if keyword.name == self.keyword:
            self.occurences += 1
            arguments = keyword.args
            self.arguments.append(arguments)


    def got_results(self):
        return self.occurences > 0


class TestsFinder(robot.model.SuiteVisitor):
    def __init__(self, keyword):
        self.keyword = keyword
        self.tests_matching = []
        self.tests_not_matching = []


    def isMatching(self, test):
        finder = KeywordsFinder(self.keyword)
        test.visit(finder)
        return finder.got_results()


    def visit_test(self, test):
        if self.isMatching(test):
            self.tests_matching.append(test)
        else:
            self.tests_not_matching.append(test)


class RobotTestSuite(object):
    instances_count = 0
    robot_frontend_process = None
    hotspot_action = ['None', 'Pause', 'Serialize']
    log_files = []
    # Used to share the port between all suites when running sequentially
    remote_server_port = -1


    def __init__(self, path):
        self.path = path
        self._dependencies_met = set()
        self.remote_server_directory = None
        self.renode_pid = -1
        self.remote_server_port = -1

        self.tests_with_hotspots = []
        self.tests_without_hotspots = []


    def check(self, options, number_of_runs):
        # Checking if there are no other jobs is moved to `prepare` as it is now possible to skip used ports
        pass


    def prepare(self, options):
        RobotTestSuite.instances_count += 1

        hotSpotTestFinder = TestsFinder(keyword="Handle Hot Spot")
        suiteBuilder = robot.running.builder.TestSuiteBuilder()
        suite = suiteBuilder.build(self.path)
        suite.visit(hotSpotTestFinder)

        self.tests_with_hotspots = [test.name for test in hotSpotTestFinder.tests_matching]
        self.tests_without_hotspots = [test.name for test in hotSpotTestFinder.tests_not_matching]

        # in parallel runs each parallel group starts it's own Renode process
        # see: run
        if options.jobs == 1:
            if not RobotTestSuite._is_frontend_running():
                RobotTestSuite.robot_frontend_process = self._run_remote_server(options)
                # Save port to reuse when running sequentially
                RobotTestSuite.remote_server_port = self.remote_server_port
            else:
                # Restore port allocated by a previous suite
                self.remote_server_port = RobotTestSuite.remote_server_port


    @classmethod
    def _is_frontend_running(cls):
        return cls.robot_frontend_process is not None and is_process_running(cls.robot_frontend_process.pid)


    def _run_remote_server(self, options):
        if options.remote_server_full_directory is not None:
            if not os.path.isabs(options.remote_server_full_directory):
                options.remote_server_full_directory = os.path.join(this_path, options.remote_server_full_directory)

            self.remote_server_directory = options.remote_server_full_directory
        else:
            self.remote_server_directory = os.path.join(options.remote_server_directory_prefix, options.configuration)

        remote_server_binary = os.path.join(self.remote_server_directory, options.remote_server_name)

        if options.runner == 'dotnet':
            if platform == "win32":
                tfm = 'net6.0-windows10.0.17763.0'
            else:
                tfm = 'net6.0'
            self.remote_server_directory = os.path.join(options.remote_server_directory_prefix, options.configuration, tfm)
            remote_server_binary = os.path.join(self.remote_server_directory, 'Renode.dll')

        if not os.path.isfile(remote_server_binary):
            print("Robot framework remote server binary not found: '{}'! Did you forget to build?".format(remote_server_binary))
            sys.exit(1)

        if options.remote_server_port != 0 and not is_port_available(options.remote_server_port, options.autokill_renode):
            print("The selected port {} is not available".format(options.remote_server_port))
            sys.exit(1)

        command = [remote_server_binary, '--robot-server-port', str(options.remote_server_port)]
        if not options.show_log:
            command.append('--hide-log')
        if not options.enable_xwt:
            command.append('--disable-xwt')
        if options.debug_on_error:
            command.append('--robot-debug-on-error')
        if options.keep_temps:
            command.append('--keep-temporary-files')
        if options.renode_config:
            command.append('--config')
            command.append(options.renode_config)

        if options.runner == 'mono':
            command.insert(0, 'mono')
            if options.port is not None:
                if options.suspend:
                    print('Waiting for a debugger at port: {}'.format(options.port))
                command.insert(1, '--debug')
                command.insert(2, '--debugger-agent=transport=dt_socket,server=y,suspend={0},address=127.0.0.1:{1}'.format('y' if options.suspend else 'n', options.port))
            elif options.debug_mode:
                command.insert(1, '--debug')
            options.exclude.append('skip_mono')
        elif options.runner == 'dotnet':
            command.insert(0, 'dotnet')
            options.exclude.append('skip_dotnet')

        renode_command = command

        # if we started GDB, wait for the user to start Renode as a child process
        if options.run_gdb:
            command = ['gdb', '-nx', '-ex', 'handle SIGXCPU SIG33 SIG35 SIG36 SIGPWR nostop noprint', '--args'] + command
            p = psutil.Popen(command, cwd=self.remote_server_directory, bufsize=1)

            print("Waiting for Renode process to start")
            while True:
                # We strip argv[0] because if we pass just `mono` to GDB it will resolve
                # it to a full path to mono on the PATH, for example /bin/mono
                renode_child = next((c for c in p.children() if c.cmdline()[1:] == renode_command[1:]), None)
                if renode_child:
                    break
                sleep(0.5)
            self.renode_pid = renode_child.pid
        elif options.perf_output_path:
            pid_file_uuid = uuid.uuid4()
            pid_filename = f'pid_file_{pid_file_uuid}'

            command = ['perf', 'record', '-q', '-g', '-F', 'max'] + command + ['--pid-file', pid_filename]

            perf_stdout_stderr_file_name = "perf_stdout_stderr"

            print(f"WARNING: perf stdout and stderr is being redirected to {perf_stdout_stderr_file_name}")

            perf_stdout_stderr_file = open(perf_stdout_stderr_file_name, "w")
            p = subprocess.Popen(command, cwd=self.remote_server_directory, bufsize=1, stdout=perf_stdout_stderr_file, stderr=perf_stdout_stderr_file)

            pid_file_path = os.path.join(self.remote_server_directory, pid_filename)
            perf_renode_timeout = 10

            while not os.path.exists(pid_file_path) and perf_renode_timeout > 0:
                sleep(0.5)
                perf_renode_timeout -= 1

            if perf_renode_timeout <= 0:
                raise RuntimeError("Renode pid file could not be found, can't attach perf")

            with open(pid_file_path, 'r') as pid_file:
                self.renode_pid = pid_file.read()
        else:
            p = psutil.Popen(command, cwd=self.remote_server_directory, bufsize=1)
            self.renode_pid = p.pid

        countdown = 120
        temp_dir = tempfile.gettempdir()
        renode_port_file = os.path.join(temp_dir, f'renode-{self.renode_pid}', 'robot_port')
        while countdown > 0:
            try:
                with open(renode_port_file) as f:
                    port_num = f.readline()
                    if port_num == '':
                        continue
                    self.remote_server_port = int(port_num)
                break
            except:
                sleep(0.5)
                countdown -= 1

        if countdown == 0:
            print("Couldn't access port file for Renode instance pid {}".format(self.renode_pid))
            self._close_remote_server(p, options)
            return None

        print('Started Renode instance on port {}; pid {}'.format(self.remote_server_port, self.renode_pid))
        return p

    def __move_perf_data(self, options):
        perf_data_path = os.path.join(self.remote_server_directory, "perf.data")

        if not perf_data_path:
            raise RuntimeError("perf.data file was not generated succesfully")

        if not os.path.isdir(options.perf_output_path):
            raise RuntimeError(f"{options.perf_output_path} is not a valid directory path")

        shutil.move(perf_data_path, options.perf_output_path)

    def _close_remote_server(self, proc, options):
        if proc:
            print('Closing Renode pid {}'.format(proc.pid))
            try:
                process = psutil.Process(proc.pid)
                os.kill(proc.pid, 2)
                process.wait(timeout=options.cleanup_timeout)

                if options.perf_output_path:
                    self.__move_perf_data(options)
            except psutil.TimeoutExpired:
                process.kill()
                process.wait()
            except psutil.NoSuchProcess:
                #evidently closed by other means
                pass

            if options.perf_output_path and proc.stdout:
                proc.stdout.close()


    def run(self, options, run_id=0):
        if self.path.endswith('renode-keywords.robot'):
            print('Ignoring helper file: {}'.format(self.path))
            return True

        print('Running ' + self.path)
        result = None

        # in non-parallel runs there is only one Renode process for all runs
        # see: prepare
        if options.jobs != 1:
            proc = self._run_remote_server(options)
        else:
            proc = None

        def get_result():
            return result if result is not None else TestResult(True, None)

        start_timestamp = monotonic()

        if any(self.tests_without_hotspots):
            result = get_result().ok and self._run_inner(options.fixture, None, self.tests_without_hotspots, options)
        if any(self.tests_with_hotspots):
            for hotspot in RobotTestSuite.hotspot_action:
                if options.hotspot and options.hotspot != hotspot:
                    continue
                result = get_result().ok and self._run_inner(options.fixture, hotspot, self.tests_with_hotspots, options)

        end_timestamp = monotonic()

        if result is None:
            print(f'No tests executed for suite {self.path}', flush=True)
        else:
            status = 'finished successfully' if result.ok else 'failed'
            exec_time = round(end_timestamp - start_timestamp, 2)
            print(f'Suite {self.path} {status} in {exec_time} seconds.', flush=True)

        self._close_remote_server(proc, options)
        return get_result()


    def _get_dependencies(self, test_case):

        suiteBuilder = robot.running.builder.TestSuiteBuilder()
        suite = suiteBuilder.build(self.path)
        test = next(t for t in suite.tests if hasattr(t, 'name') and t.name == test_case)
        requirements = [s.args[0] for s in test.body if hasattr(s, 'name') and s.name == 'Requires']
        if len(requirements) == 0:
            return set()
        if len(requirements) > 1:
            raise Exception('Too many requirements for a single test. At most one is allowed.')
        providers = [t for t in suite.tests if any(hasattr(s, 'name') and s.name == 'Provides' and s.args[0] == requirements[0] for s in t.body)]
        if len(providers) > 1:
            raise Exception('Too many providers for state {0} found: {1}'.format(requirements[0], ', '.join(providers.name)))
        if len(providers) == 0:
            raise Exception('No provider for state {0} found'.format(requirements[0]))
        res = self._get_dependencies(providers[0].name)
        res.add(providers[0].name)
        return res


    def cleanup(self, options):
        RobotTestSuite.instances_count -= 1
        if RobotTestSuite.instances_count == 0:
            self._close_remote_server(RobotTestSuite.robot_frontend_process, options)
            if len(RobotTestSuite.log_files) > 0:
                print("Aggregating all robot results")
                robot.rebot(*RobotTestSuite.log_files, processemptysuite=True, name='Test Suite', loglevel="TRACE:INFO", outputdir=options.results_directory, output='robot_output.xml')
            if options.css_file:
                with open(options.css_file) as style:
                    style_content = style.read()
                    for report_name in ("report.html", "log.html"):
                        with open(os.path.join(options.results_directory, report_name), "a") as report:
                            report.write("<style media=\"all\" type=\"text/css\">")
                            report.write(style_content)
                            report.write("</style>")


    @staticmethod
    def _create_suite_name(test_name, hotspot):
        return test_name + (' [HotSpot action: {0}]'.format(hotspot) if hotspot else '')


    def _run_dependencies(self, test_cases_names, options):
        test_cases_names.difference_update(self._dependencies_met)
        if not any(test_cases_names):
            return True
        self._dependencies_met.update(test_cases_names)
        return self._run_inner(None, None, test_cases_names, options)


    def _run_inner(self, fixture, hotspot, test_cases_names, options):
        file_name = os.path.splitext(os.path.basename(self.path))[0]
        suite_name = RobotTestSuite._create_suite_name(file_name, hotspot)

        variables = ['SKIP_RUNNING_SERVER:True', 'DIRECTORY:{}'.format(self.remote_server_directory), 'PORT_NUMBER:{}'.format(self.remote_server_port), 'RESULTS_DIRECTORY:{}'.format(options.results_directory)]
        if hotspot:
            variables.append('HOTSPOT_ACTION:' + hotspot)
        if options.debug_mode:
            variables.append('CONFIGURATION:Debug')
        if options.debug_on_error:
            variables.append('HOLD_ON_ERROR:True')
        if options.execution_metrics:
            variables.append('CREATE_EXECUTION_METRICS:True')
        if options.save_logs == "always":
            variables.append('SAVE_LOGS_WHEN:Always')
        if options.runner == 'dotnet':
            variables.append('BINARY_NAME:Renode.dll')
            variables.append('RENODE_PID:{}'.format(self.renode_pid))
            variables.append('NET_PLATFORM:True')
        else:
            options.exclude.append('profiling')

        if options.variables:
            variables += options.variables

        test_cases = [(test_name, '{0}.{1}'.format(suite_name, test_name)) for test_name in test_cases_names]
        if fixture:
            test_cases = [x for x in test_cases if fnmatch.fnmatch(x[1], '*' + fixture + '*')]
            if len(test_cases) == 0:
                return None
            deps = set()
            for test_name in (t[0] for t in test_cases):
                deps.update(self._get_dependencies(test_name))
            if not self._run_dependencies(deps, options):
                return False

        output_formatter = 'robot_output_formatter_verbose.py' if options.verbose else 'robot_output_formatter.py'
        listeners = [os.path.join(this_path, output_formatter)]
        if options.listener:
            listeners += options.listener

        metadata = {"HotSpot_Action": hotspot if hotspot else '-'}
        log_file = os.path.join(options.results_directory, 'results-{0}{1}.robot.xml'.format(file_name, '_' + hotspot if hotspot else ''))

        keywords_path = os.path.abspath(os.path.join(this_path, "renode-keywords.robot"))
        keywords_path = keywords_path.replace(os.path.sep, "/")  # Robot wants forward slashes even on Windows
        # This variable is provided for compatibility with Robot files that use Resource ${RENODEKEYWORDS}
        variables.append('RENODEKEYWORDS:{}'.format(keywords_path))
        tools_path = os.path.join(os.path.dirname(this_path), "tools")
        tools_path = tools_path.replace(os.path.sep, "/")
        variables.append('RENODETOOLS:{}'.format(tools_path))
        suite_builder = robot.running.builder.TestSuiteBuilder()
        suite = suite_builder.build(self.path)
        suite.resource.imports.create(type="Resource", name=keywords_path)

        suite.configure(include_tags=options.include, exclude_tags=options.exclude,
                        include_tests=[t[1] for t in test_cases], metadata=metadata,
                        name=suite_name, empty_suite_ok=True)

        # Provide default values for {Suite,Test}{Setup,Teardown}
        if not suite.setup:
            suite.setup.config(name="Setup")
        if not suite.teardown:
            suite.teardown.config(name="Teardown")

        for test in suite.tests:
            if not test.setup:
                test.setup.config(name="Reset Emulation")
            if not test.teardown:
                test.teardown.config(name="Test Teardown")

        result = suite.run(console='none', listener=listeners, exitonfailure=options.stop_on_error, output=log_file, log=None, loglevel='TRACE', report=None, variable=variables, skiponfailure=['non_critical', 'skipped'])

        log_files = []
        file_name = os.path.splitext(os.path.basename(self.path))[0]
        if any(self.tests_without_hotspots):
            log_files.append(os.path.join(options.results_directory, 'results-{0}.robot.xml'.format(file_name)))
        if any(self.tests_with_hotspots):
            for hotspot in RobotTestSuite.hotspot_action:
                if options.hotspot and options.hotspot != hotspot:
                    continue
                log_files.append(os.path.join(options.results_directory, 'results-{0}{1}.robot.xml'.format(file_name, '_' + hotspot if hotspot else '')))

        return TestResult(result.return_code == 0, log_files)


    @staticmethod
    def find_failed_tests(path, file="robot_output.xml"):
        tree = None
        try:
            tree = ET.parse(os.path.join(path, file))
        except FileNotFoundError:
            return None

        root = tree.getroot()
        ret = {'mandatory': [], 'non_critical': []}
        for suite in root.iter('suite'):
            if not suite.get('source', False):
                continue # it is a tag used to group other suites without meaning on its own
            for test in suite.iter('test'):
                status = test.find('status') # only finds immediate children - important requirement
                if status.attrib['status'] == 'FAIL':
                    name = test.attrib['name']
                    testname = suite.attrib['name']
                    if test.find("./tags/[tag='skipped']"):
                        continue # skipped test should not be classified as fail
                    if test.find("./tags/[tag='non_critical']"):
                        ret['non_critical'].append(testname + "." + name)
                    else:
                        ret['mandatory'].append(testname + "." + name)

        if not ret['mandatory'] and not ret['non_critical']:
            return None
        return ret
