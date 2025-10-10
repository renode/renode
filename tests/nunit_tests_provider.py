# pylint: disable=C0301,C0103,C0111
from sys import platform
from platform import machine
import os
import signal
import psutil
import subprocess
from time import monotonic
from typing import Dict, List

import xml.etree.ElementTree as ET
import glob

from tests_engine import TestResult


THIS_PATH = os.path.abspath(os.path.dirname(__file__))


def install_cli_arguments(parser):
    parser.add_argument("--properties-file", action="store", help="Location of properties file.")
    parser.add_argument("--skip-building", action="store_true", help="Do not build tests before run.")
    parser.add_argument("--force-net-framework-version", action="store", dest="framework_ver_override", help="Override target .NET Framework version when building tests.")


class NUnitTestSuite(object):
    nunit_path = os.path.join(THIS_PATH, './../lib/resources/tools/nunit3/nunit3-console.exe')

    def __init__(self, path):
        self.path = path

    def check(self, options, number_of_runs): # API requires this method
        pass

    def get_output_dir(self, options, iteration_index, suite_retry_index):
        # Unused mechanism, this exists to keep a uniform interface with
        # robot_tests_provider.py.
        return options.results_directory

    # NOTE: if we switch to using msbuild on all platforms, we can get rid of this function and only use the '-' prefix
    def build_params(self, *params):
        def __decorate_build_param(p):
            if self.builder == 'xbuild':
                return '/' + p
            else:
                return '-' + p

        ret = []
        for i in params:
            ret += [__decorate_build_param(i)]
        return ret

    def prepare(self, options):
        if not options.skip_building:
            self._adjust_path(options)
            print("Building {0}".format(self.path))
            arch = 'arm' if machine() in ['aarch64', 'arm64'] else 'i386'
            if options.runner == 'dotnet':
                self.builder = 'dotnet'
                params = ['build', '--verbosity', 'quiet', '--configuration', options.configuration, '/p:NET=true', f'/p:Architecture={arch}']
            else:
                if platform == "win32":
                    self.builder = 'MSBuild.exe'
                else:
                    self.builder = 'xbuild'
                params = self.build_params(
                    f'p:PropertiesLocation={options.properties_file}',
                    f'p:OutputPath={options.results_directory}',
                    'nologo',
                    'verbosity:quiet',
                    'p:OutputDir=tests_output',
                    f'p:Configuration={options.configuration}',
                    f'p:Architecture={arch}')
                if options.framework_ver_override:
                    params += self.build_params(f'p:TargetFrameworkVersion=v{options.framework_ver_override}')
            result = subprocess.call([self.builder, *params, self.path])
            if result != 0:
                print("Building project `{}` failed with error code: {}".format(self.path, result))
                return result
        else:
            print('Skipping the build')

        return 0

    def _adjust_path(self, options):
        path, proj = os.path.split(self.path)
        _match = (options.runner == 'dotnet', proj.endswith("_NET.csproj"))
        if _match == (True, False):
                proj_alt = proj[:-7] + "_NET.csproj"
        elif _match == (False, True):
                proj_alt = proj[:-11] + ".csproj"
        else:
                proj_alt = proj
        if proj != proj_alt and os.path.exists(path_alt := os.path.join(path, proj_alt)):
            print(f"{options.runner} runner detected, switching: {proj} -> {proj_alt}")
            self.path = path_alt
            return True
        return False

    def _cleanup_dangling(self, process, proc_name, test_agent_name):
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            if proc_name in (proc.info['name'] or ''):
                flat_cmdline = ' '.join(proc.info['cmdline'] or [])
                if test_agent_name in flat_cmdline and '--pid={}'.format(process.pid) in flat_cmdline:
                    # let's kill it
                    print('KILLING A DANGLING {} test process {}'.format(test_agent_name, proc.info['pid']))
                    os.kill(proc.info['pid'], signal.SIGTERM)

    def run(self, options, iteration_index=1, suite_retry_index=0):
        # The iteration_index and suite_retry_index arguments are not implemented.
        # They exist for the sake of a uniform interface with robot_tests_provider.
        print('Running ' + self.path)

        project_file = os.path.split(self.path)[1]
        output_file = os.path.join(options.results_directory, 'results-{}.xml'.format(project_file))

        if options.runner == 'dotnet':
            print('Using native dotnet test runner -' + self.path, flush=True)
            # we don't build here - we had problems with concurrently occurring builds when copying files to one output directory
            # so we run test with --no-build and build tests in previous stage
            args = ['dotnet', 'test', "--no-build", "--logger", "console;verbosity=detailed", "--logger", "trx;LogFileName={}".format(output_file), '--configuration', options.configuration, self.path]
        else:
            args = [NUnitTestSuite.nunit_path, '--domain=None', '--noheader', '--labels=Before', '--result={}'.format(output_file), project_file.replace("csproj", "dll")]

        # Unfortunately, debugging like this won't work on .NET, see: https://github.com/dotnet/sdk/issues/4994
        # The easiest workaround is to set VSTEST_HOST_DEBUG=1 in your environment
        if options.stop_on_error:
            args.append('--stoponerror')
        if (platform.startswith("linux") or platform == "darwin") and options.runner != 'dotnet':
            args.insert(0, 'mono')
            if options.port is not None:
                if options.suspend:
                    print('Waiting for a debugger at port: {}'.format(options.port))
                args.insert(1, '--debug')
                args.insert(2, '--debugger-agent=transport=dt_socket,server=y,suspend={0},address=127.0.0.1:{1}'.format('y' if options.suspend else 'n', options.port))
            elif options.debug_mode:
                args.insert(1, '--debug')

        where_conditions = []
        if options.fixture:
            if options.runner == 'dotnet':
                where_conditions.append(options.fixture)
            else:
                where_conditions.append('test =~ .*{}.*'.format(options.fixture))

        cat = 'TestCategory' if options.runner == 'dotnet' else 'cat'
        equals = '=' if options.runner == 'dotnet' else '=='
        if options.exclude:
            for category in options.exclude:
                where_conditions.append('{} != {}'.format(cat, category))
        if options.include:
            for category in options.include:
                where_conditions.append('{} {} {}'.format(cat, equals, category))

        if where_conditions:
            if options.runner == 'dotnet':
                args.append('--filter')
                args.append(' & '.join('({})'.format(x) for x in where_conditions))
            else:
                args.append('--where= ' + ' and '.join(['({})'.format(x) for x in where_conditions]))

        if options.run_gdb:
            if options.runner == 'dotnet':
                signals_to_handle = 'SIG34'
            else:
                signals_to_handle = 'SIGXCPU SIG33 SIG35 SIG36 SIGPWR'
            command = ['gdb', '-nx', '-ex', 'handle ' + signals_to_handle + ' nostop noprint', '--args'] + args

        startTimestamp = monotonic()
        if options.runner == 'dotnet':
            args += ['--', 'NUnit.DisplayName=FullName']
            process = subprocess.Popen(args)
            print('dotnet test runner PID is {}'.format(process.pid), flush=True)
        else:
            if platform != "win32":
                # This is alias for '--process=Single' - means no TCP connection at all so that we can see what happens underneath
                # This causes failure on some Windows setups
                args.append("--inprocess")
            process = subprocess.Popen(args, cwd=options.results_directory)
            print('NUnit3 runner PID is {}'.format(process.pid), flush=True)

        process.wait()
        if options.runner == 'dotnet':
            self._cleanup_dangling(process, 'dotnet', 'dotnet test')
        else:
            self._cleanup_dangling(process, 'mono', 'nunit-agent.exe')

        result = process.returncode == 0
        endTimestamp = monotonic()
        print('Suite ' + self.path + (' finished successfully!' if result else ' failed!') + ' in ' + str(round(endTimestamp - startTimestamp, 2)) + ' seconds.', flush=True)
        return TestResult(result, [output_file])

    def cleanup(self, options):
        pass

    def should_retry_suite(self, options, iteration_index, suite_retry_index):
        # Unused mechanism, this exists to keep a uniform interface with
        # robot_tests_provider.py.
        return False

    def tests_failed_due_to_renode_crash(self) -> bool:
        # Unused mechanism, this exists to keep a uniform interface with
        # robot_tests_provider.py.
        return False

    @staticmethod
    def find_failed_tests(path, files_pattern='*.csproj.xml'):
        test_files = glob.glob(os.path.join(path, files_pattern))
        ret = {'mandatory': []}
        for test_file in test_files:
            tree = ET.parse(test_file)
            root = tree.getroot()

            # we analyze both types of output files (nunit and dotnet test) to avoid passing options as parameter
            # the cost should be negligible in the context of compiling and running test suites

            # nunit runner
            for test in root.iter('test-case'):
                if test.attrib['result'] == 'Failed':
                    ret['mandatory'].append(test.attrib['fullname'])

            # dotnet runner
            xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010"
            for test in root.iter(f"{{{xmlns}}}UnitTestResult"):
                if test.attrib['outcome'] == 'Failed':
                    ret['mandatory'].append(test.attrib['testName'])

        if not ret['mandatory']:
            return None
        return ret

    @staticmethod
    def find_rerun_tests(path):
        # Unused mechanism, this exists to keep a uniform interface with
        # robot_tests_provider.py.
        return None
