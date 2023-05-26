#!/usr/bin/env python3
# pylint: disable=C0301,C0103,C0111

from __future__ import print_function

import os
import sys

# Look for requirements.txt
name = "requirements.txt"
requirements = name
path = os.path.dirname(os.path.realpath(__file__))
requirements = os.path.join(path, requirements)

try:
    import nunit_tests_provider
    import robot_tests_provider
    import tests_engine
    from robot import __version__ as robot_version

    # Check if current robot version matches the one from requirements file
    def check_robot_version():
        required_version = ""
        with open(requirements, 'r') as req_file:
            for line in req_file.readlines():
                if line.find("robotframework==") != -1:
                    split_line = line.split("==")
                    if len(split_line) > 1:
                        required_version = split_line[1].strip()
                    break

        if robot_version != required_version:
            print(f"Required `robotframework` version is `{required_version}`, while the one available in your system is `{robot_version}`. " + \
                "Tests may still work, but this version of Robot is not officially supported. " + \
                f"Please install the required version using `pip install robotframework=={required_version}` before running the tests")

    if __name__ == '__main__':
        check_robot_version()

        tests_engine.register_handler('nunit', 'csproj', nunit_tests_provider.NUnitTestSuite, nunit_tests_provider.install_cli_arguments)
        tests_engine.register_handler('robot', 'robot', robot_tests_provider.RobotTestSuite, robot_tests_provider.install_cli_arguments, robot_tests_provider.verify_cli_arguments)
        tests_engine.run()

except ImportError as e:
    print("{}\nPlease install required dependencies with `pip install -r {}`".format(str(e), os.path.abspath(requirements)), file=sys.stderr)
    sys.exit(1)
