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
    parser.add_argument("--properties-file", action="store", help="This flag is a no-op and will be removed in the future.")
    parser.add_argument("--skip-building", action="store_true", help="Do not build tests before run.")


class NUnitTestSuite(object):

    def __init__(self, path):
        self.path = path

    def check(self, options, number_of_runs): # API requires this method
        pass

    def get_output_dir(self, options, iteration_index, suite_retry_index):
        # Unused mechanism, this exists to keep a uniform interface with
        # robot_tests_provider.py.
        return options.results_directory

    def prepare(self, options):
        if not options.skip_building:
            print("Building {0}".format(self.path))
            arch = 'arm' if machine() in ['aarch64', 'arm64'] else 'i386'
            params = ['build', '--verbosity', 'quiet', '--configuration', options.configuration, '/p:NET=true', f'/p:Architecture={arch}']
            result = subprocess.call(['dotnet', *params, self.path])
            if result != 0:
                print("Building project `{}` failed with error code: {}".format(self.path, result))
                return result
        else:
            print('Skipping the build')

        return 0

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

        args = ['dotnet', 'test', "--no-build", "--logger", "console;verbosity=detailed", "--logger", "trx;LogFileName={}".format(output_file), '--configuration', options.configuration, self.path]

        if options.stop_on_error:
            args.append('--stoponerror')

        where_conditions = []
        if options.fixture:
            where_conditions.append(options.fixture)

        cat = 'TestCategory'
        if options.exclude:
            for category in options.exclude:
                where_conditions.append('{} != {}'.format(cat, category))
        if options.include:
            for category in options.include:
                where_conditions.append('{} = {}'.format(cat, category))

        if where_conditions:
            args.append('--filter')
            args.append(' & '.join('({})'.format(x) for x in where_conditions))

        startTimestamp = monotonic()
        args += ['--', 'NUnit.DisplayName=FullName']
        process = subprocess.Popen(args)
        print('dotnet test runner PID is {}'.format(process.pid), flush=True)

        process.wait()
        self._cleanup_dangling(process, 'dotnet', 'dotnet test')

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
