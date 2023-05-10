# pylint: disable=C0301,C0103,C0111
from __future__ import print_function
from sys import platform
import os
import signal
import psutil
import subprocess
from time import monotonic

import xml.etree.ElementTree as ET
import glob

this_path = os.path.abspath(os.path.dirname(__file__))

def install_cli_arguments(parser):
    parser.add_argument("--properties-file", action="store", help="Location of properties file.")
    parser.add_argument("--skip-building", action="store_true", help="Do not build tests before run.")
    parser.add_argument("--force-net-framework-version", action="store", dest="framework_ver_override", help="Override target .NET Framework version when building tests.")

class NUnitTestSuite(object):
    nunit_path = os.path.join(this_path, './../lib/resources/tools/nunit3/nunit3-console.exe')

    def __init__(self, path):
        #super(NUnitTestSuite, self).__init__(path)
        self.path = path
    
    def check(self, options, number_of_runs): #API requires this method 
        pass 

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
            print("Building {0}".format(self.path))
            if options.runner == 'dotnet':
                self.builder = 'dotnet'
                params = ['build', '--verbosity', 'quiet', '--configuration', options.configuration, '/p:NET=true']
            else:
                if platform == "win32":
                    self.builder = 'MSBuild.exe'
                else:
                    self.builder = 'xbuild'
                params = self.build_params('p:PropertiesLocation={0}'.format(options.properties_file), 'p:OutputPath={0}'.format(options.results_directory), 'nologo', 'verbosity:quiet', 'p:OutputDir=tests_output', 'p:Configuration={0}'.format(options.configuration))
                if options.framework_ver_override:
                    params += self.build_params(f'p:TargetFrameworkVersion=v{options.framework_ver_override}')
            result = subprocess.call([self.builder, *params, self.path])
            if result != 0:
                print("Building project `{}` failed with error code: {}".format(self.path, result))
                return result
        else:
            print('Skipping the build')

        return 0

    def run(self, options, run_id):
        print('Running ' + self.path)

        project_file = os.path.split(self.path)[1]
        output_file = os.path.join(options.results_directory, 'results-{}.xml'.format(project_file))

        if options.runner == 'dotnet':
            print('Using native dotnet test runner -' + self.path, flush=True)
            # we don't build here - we had problems with concurrently occurring builds when copying files to one output directory
            # so we run test with --no-build and build tests in previous stage
            args = ['dotnet', 'test', "--no-build", "--logger", "console;verbosity=detailed", '--configuration', options.configuration, self.path]
            process = subprocess.Popen(args)
            print('dotnet test runner PID is {}'.format(process.pid), flush=True)
            process.wait()
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                if 'dotnet' in (proc.info['name'] or ''):
                    flat_cmdline = ' '.join(proc.info['cmdline'] or [])
                    if 'dotnet test' in flat_cmdline and '--pid={}'.format(process.pid) in flat_cmdline:
                        # let's kill it
                        print('KILLING A DANGLING dotnet test process {}'.format(proc.info['pid']))
                        os.kill(proc.info['pid'], signal.SIGTERM)
            return process.returncode == 0

        args = [NUnitTestSuite.nunit_path, '--domain=None', '--noheader', '--labels=Before', '--result={}'.format(output_file), project_file.replace("csproj", "dll")]
        if options.stop_on_error:
            args.append('--stoponerror')
        if platform.startswith("linux") or platform == "darwin":
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
            where_conditions.append('test =~ .*{}.*'.format(options.fixture))

        if options.exclude:
            for category in options.exclude:
                where_conditions.append('cat != {}'.format(category))
        if options.include:
            for category in options.include:
                where_conditions.append('cat == {}'.format(category))

        if where_conditions:
            args.append('--where= ' + ' and '.join(['({})'.format(x) for x in where_conditions]))

        if options.run_gdb:
            args = ['gdb', '-ex', 'handle SIGXCPU SIG33 SIG35 SIG36 SIGPWR nostop noprint', '--args'] + args

        startTimestamp = monotonic()
        process = subprocess.Popen(args, cwd=options.results_directory)
        print('NUnit3 runner PID is {}'.format(process.pid))
        process.wait()

        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            if 'mono' in (proc.info['name'] or ''):
                flat_cmdline = ' '.join(proc.info['cmdline'] or [])
                if 'nunit-agent.exe' in flat_cmdline and '--pid={}'.format(process.pid) in flat_cmdline:
                    # let's kill it
                    print('KILLING A DANGLING nunit-agent.exe process {}'.format(proc.info['pid']))
                    os.kill(proc.info['pid'], signal.SIGTERM)

        result = process.returncode == 0
        endTimestamp = monotonic()
        print('Suite ' + self.path + (' finished successfully!' if result else ' failed!') + ' in ' + str(round(endTimestamp - startTimestamp, 2)) + ' seconds.', flush=True)
        return result

    def cleanup(self, options):
        pass

    @staticmethod
    def find_failed_tests(path, files_pattern='*.csproj.xml'):
        test_files = glob.glob(os.path.join(path, files_pattern))
        ret = {'mandatory': []}
        for test_file in test_files:
            tree = ET.parse(test_file)
            root = tree.getroot()
            for test in root.iter('test-case'):
                if test.attrib['result'] == 'Failed':
                    ret['mandatory'].append(test.attrib['fullname'])
        
        if not ret['mandatory']:
            return None
        return ret
