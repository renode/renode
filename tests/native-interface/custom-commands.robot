# Like native-interface.robot, this suite does not use the Renode instance started by
# robot_tests_provider. Each test builds a native host process that hosts its own Renode instance,
# talks to it through the external control API and reports the result through its exit code.
#
# See native-interface.resource for the variables that select which librenode is used.

*** Settings ***
Resource                            ${CURDIR}/native-interface.resource

*** Test Cases ***
Should Send Custom Commands To A Native Host
    Run Guest Program With Native Host  wfi  custom_command_host

Should Return Each Client Thread The Output Of Its Own Monitor Commands
    Run Guest Program With Native Host  wfi  monitor_commands_host
