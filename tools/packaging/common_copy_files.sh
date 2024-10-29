#!/usr/bin/env bash

# Copy files that are non-os specific

mkdir -p $DIR/{licenses,tests,tools,plugins}

cp -r $BASE/tests/metrics-analyzer $DIR/tests/metrics-analyzer
cp -r $BASE/tests/network-server $DIR/tests/network-server
cp -r $BASE/tests/network-logging $DIR/tests/network-logging
cp -r $BASE/tests/peripherals $DIR/tests/peripherals
cp -r $BASE/tests/platforms $DIR/tests/platforms
cp -r $BASE/tests/{robot_tests_provider,run_tests,tests_engine,robot_output_formatter,robot_output_formatter_verbose,helper,retry_and_timeout_listener}.py $DIR/tests
cp -r $BASE/tests/{renode-keywords,example}.robot $DIR/tests
cp -r $BASE/tests/tools $DIR/tests/tools
cp -r $BASE/tests/tests.yaml $DIR/tests/tests.yaml

cp -r $BASE/{.renode-root,scripts,platforms} $DIR
cp -r $BASE/tools/execution_tracer $DIR/tools
cp -r $BASE/tools/gdb_compare $DIR/tools
cp -r $BASE/tools/metrics_analyzer $DIR/tools
cp -r $BASE/tools/sel4_extensions $DIR/tools
cp -r $BASE/tools/csv2resd $DIR/tools
cp -r $BASE/tools/external_control_client $DIR/tools
cp -r $BASE/src/Plugins/CoSimulationPlugin/IntegrationLibrary $DIR/plugins
cp -r $BASE/src/Plugins/SystemCPlugin/SystemCModule $DIR/plugins
# For now, SystemCPlugin uses socket-cpp library from CoSimulationPlugin IntegrationLibrary.
# ln -f argument is quietly ignored in windows-package environment, so instead of updating remove the link
# and create it again.
rm -rf $DIR/plugins/SystemCModule/lib/socket-cpp
ln -s ../../IntegrationLibrary/libs/socket-cpp $DIR/plugins/SystemCModule/lib/socket-cpp

cp $BASE/tests/requirements.txt $DIR/tests
cp $BASE/lib/resources/styles/robot.css $DIR/tests

# Don't copy RenodeTests directory which contains nunit tests
mkdir $DIR/tests/unit-tests
find $BASE/tests/unit-tests \
    -not -path "$BASE/tests/unit-tests" \
    -not -path "$BASE/tests/unit-tests/RenodeTests" \
    -not -path "$BASE/tests/unit-tests/RenodeTests/*" \
    -exec cp -r "{}" "$DIR/tests/unit-tests/" \;

$BASE/tools/packaging/common_copy_licenses.sh $DIR/licenses $OS_NAME
$BASE/tools/packaging/common_copy_dts2repl_version_script.sh $BASE $DIR

# `tests.yaml` without nunit tests
$SED_COMMAND '/csproj$/d' $DIR/tests/tests.yaml
$SED_COMMAND '/nunit/d' $DIR/tests/run_tests.py
