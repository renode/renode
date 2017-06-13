#!/usr/bin/python
# pylint: disable=C0301,C0103,C0111
from __future__ import print_function
import os
import sys
import fnmatch
import subprocess

import robot

this_path = os.path.abspath(os.path.dirname(__file__))

def install_cli_arguments(parser):
    parser.add_argument("--robot-framework-remote-server-directory-prefix", dest="remote_server_directory_prefix", action="store", default=os.path.join(this_path, '../output/bin'), help="Location of robot framework remote server binary. This is concatenated with current configuration to create full path.")
    parser.add_argument("--robot-framework-remote-server-name", dest="remote_server_name", action="store", default="Renode.exe", help="Name of robot framework remote server binary.")
    parser.add_argument("--robot-framework-remote-server-port", dest="remote_server_port", action="store", default=9999, help="Port of robot framework remote server binary.")
    parser.add_argument("--disable-xwt", dest="disable_xwt", action="store_true", default=False, help="Disables support for XWT.")

def verify_cli_arguments(options):
    if options.port == str(options.remote_server_port):
        print('Port {} is reserved for Robot Framework remote server and cannot be used for remote debugging.'.format(options.remote_server_port))
        sys.exit(1)

class RobotTestSuite(object):
    instances_count = 0
    robot_frontend_process = None
    hotspot_action = ['None', 'Pause']
    log_files = []

    def __init__(self, path):
        self.path = path
        self._dependencies_met = set()
        self.remote_server_directory = None

    def prepare(self, options):
        RobotTestSuite.instances_count += 1
        if RobotTestSuite.instances_count > 1:
            return

    def _run_remote_server(self, options):
        self.remote_server_directory = os.path.join(options.remote_server_directory_prefix, options.configuration)
        remote_server_binary = os.path.join(self.remote_server_directory, options.remote_server_name)

        if not os.path.isfile(remote_server_binary):
            print("Robot framework remote server binary not found: '{}'! Did you forget to bootstrap and build?".format(remote_server_binary))
            sys.exit(1)

        args = ['mono', remote_server_binary, '--hide-monitor', '--hide-log', '--robot-framework-remote-server-port', str(options.remote_server_port)]
        if options.port is not None:
            if options.suspend:
                print('Waiting for a debugger at port: {}'.format(options.port))
            args.insert(1, '--debug')
            args.insert(2, '--debugger-agent=transport=dt_socket,server=y,suspend={0},address=127.0.0.1:{1}'.format('y' if options.suspend else 'n', options.port))
        elif options.debug_mode:
            args.insert(1, '--debug')
        if options.disable_xwt:
            args.insert(-1, '--disable-xwt')

        RobotTestSuite.robot_frontend_process = subprocess.Popen(args, cwd=self.remote_server_directory, bufsize=1)

    def run(self, options):
        if self.path.endswith('renode-keywords.robot'):
            print('Ignoring helper file: {}'.format(self.path))
            return True
        print('Running ' + self.path)
        result = True

        tests_with_hotspots = []
        tests_without_hotspots = []
        _suite = robot.parsing.model.TestData(source=self.path)
        for test in _suite.testcase_table.tests:
            if any(hasattr(step, 'name') and step.name == 'Hot Spot' for step in test.steps):
                tests_with_hotspots.append(test.name)
            else:
                tests_without_hotspots.append(test.name)

        if RobotTestSuite.robot_frontend_process is None:
            self._run_remote_server(options)

        if any(tests_without_hotspots):
            result = result and self._run_inner(options.fixture, None, tests_without_hotspots, options)
        if any(tests_with_hotspots):
            for hotspot in RobotTestSuite.hotspot_action:
                result = result and self._run_inner(options.fixture, hotspot, tests_with_hotspots, options)

        return result

    def _get_dependencies(self, test_case):
        _suite = robot.parsing.model.TestData(source=self.path)
        test = next(t for t in _suite.testcase_table.tests if hasattr(t, 'name') and t.name == test_case)
        requirements = [s.args[0] for s in test.steps if hasattr(s, 'name') and s.name == 'Requires']
        if len(requirements) == 0:
            return set()
        if len(requirements) > 1:
            raise Exception('Too many requirements for a single test. At most one is allowed.')
        providers = [t for t in _suite.testcase_table.tests if any(hasattr(s, 'name') and s.name == 'Provides' and s.args[0] == requirements[0] for s in t.steps)]
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
            if RobotTestSuite.robot_frontend_process:
                os.kill(RobotTestSuite.robot_frontend_process.pid, 15)
                RobotTestSuite.robot_frontend_process.wait()
            if len(RobotTestSuite.log_files) > 0:
                print("Aggregating all robot results")
                robot.rebot(*RobotTestSuite.log_files, processemptysuite=True, name='Test Suite', outputdir=options.results_directory, output='robot_output.xml')

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

        variables = ['SKIP_RUNNING_SERVER:True', 'DIRECTORY:{}'.format(self.remote_server_directory)]
        if hotspot:
            variables.append('HOTSPOT_ACTION:' + hotspot)
        if options.debug_mode:
            variables.append('CONFIGURATION:Debug')

        test_cases = [(test_name, '{0}.{1}'.format(suite_name, test_name)) for test_name in test_cases_names]
        if fixture:
            test_cases = [x for x in test_cases if fnmatch.fnmatch(x[1], fixture)]
            if len(test_cases) == 0:
                return True
            deps = set()
            for test_name in (t[0] for t in test_cases):
                deps.update(self._get_dependencies(test_name))
            if not self._run_dependencies(deps, options):
                return False

        metadata = 'HotSpot_Action:{0}'.format(hotspot if hotspot else '-')
        log_file = os.path.join(options.results_directory, '{0}{1}.xml'.format(file_name, '_' + hotspot if hotspot else ''))
        RobotTestSuite.log_files.append(log_file)
        return robot.run(self.path, runemptysuite=True, output=log_file, log=None, report=None, metadata=metadata, name=suite_name, variable=variables, noncritical='non-critical', test=[t[1] for t in test_cases]) == 0
