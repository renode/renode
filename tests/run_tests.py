#!/usr/bin/env python3
# pylint: disable=C0301,C0103,C0111

from __future__ import print_function
try:
    import os
    import sys
    import nunit_tests_provider
    import robot_tests_provider
    import tests_engine

    if __name__ == '__main__':
        tests_engine.register_handler('nunit', 'csproj', nunit_tests_provider.NUnitTestSuite, nunit_tests_provider.install_cli_arguments)
        tests_engine.register_handler('robot', 'robot', robot_tests_provider.RobotTestSuite, robot_tests_provider.install_cli_arguments, robot_tests_provider.verify_cli_arguments)
        tests_engine.run()
except ImportError as e:
    # Look for requirements.txt
    name = "requirements.txt"
    requirements = name
    path = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..')
    for root, dirs, files in os.walk(path):
        if name in files:
            requirements = os.path.join(root, name)
            break

    print("{}\nPlease install required dependencies with `pip install -r {}`".format(e.message, os.path.abspath(requirements)), file=sys.stderr)
