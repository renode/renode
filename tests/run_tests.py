#!/usr/bin/python
# pylint: disable=C0301,C0103,C0111

import os
import sys
import nunit_tests_provider
import robot_tests_provider
import tests_engine

tests_engine.register_handler('nunit', 'csproj', nunit_tests_provider.NUnitTestSuite, nunit_tests_provider.install_cli_arguments)
tests_engine.register_handler('robot', 'robot', robot_tests_provider.RobotTestSuite, robot_tests_provider.install_cli_arguments, robot_tests_provider.verify_cli_arguments)
tests_engine.run()
