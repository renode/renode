#!/usr/bin/env bash

rm -rf $DESTINATION
mkdir -p $DESTINATION/{licenses,tests,tools,plugins}

cp $RENODE_ROOT_DIR/renode-test $DESTINATION
cp $RENODE_ROOT_DIR/tests/{robot_tests_provider,run_tests,tests_engine,robot_output_formatter,robot_output_formatter_verbose,helper}.py $DESTINATION/tests
cp $RENODE_ROOT_DIR/tests/{renode-keywords,example}.robot $DESTINATION/tests
cp $RENODE_ROOT_DIR/tests/requirements.txt $DESTINATION/tests
cp $RENODE_ROOT_DIR/lib/resources/styles/robot.css $DESTINATION/tests/robot.css
cp $RENODE_ROOT_DIR/tools/common.sh $DESTINATION/tests
cp -r $RENODE_ROOT_DIR/tools/metrics_analyzer $DESTINATION/tools
cp -r $RENODE_ROOT_DIR/tools/execution_tracer $DESTINATION/tools
cp -r $RENODE_ROOT_DIR/tools/gdb_compare $DESTINATION/tools
cp -r $RENODE_ROOT_DIR/tools/sel4_extensions $DESTINATION/tools
cp -r $RENODE_ROOT_DIR/tools/csv2resd $DESTINATION/tools
cp -r $RENODE_ROOT_DIR/src/Plugins/VerilatorPlugin/VerilatorIntegrationLibrary $DESTINATION/plugins
cp -r $RENODE_ROOT_DIR/src/Plugins/SystemCPlugin/SystemCModule $DESTINATION/plugins
# For now, SystemCPlugin uses socket-cpp library from VerilatorIntegrationLibrary.
ln -fs ../../VerilatorIntegrationLibrary/libs/socket-cpp $DESTINATION/plugins/SystemCModule/lib/socket-cpp

sed -i '/nunit/d' $DESTINATION/tests/run_tests.py
sed -i 's#ROOT_PATH/tests/run_tests.py#TEST_PATH/run_tests.py#' $DESTINATION/renode-test
sed -i 's#ROOT_PATH}/tools/common.sh#TEST_PATH}/common.sh#' $DESTINATION/renode-test
sed -i 's#--properties-file.*#--robot-framework-remote-server-full-directory=$ROOT_PATH --robot-framework-remote-server-name=renode --css-file=$TEST_PATH/robot.css --runner=none -r $(pwd) "$@"#' $DESTINATION/renode-test
sed -i '/^ROOT_PATH=.*/a TEST_PATH=$ROOT_PATH/tests' $DESTINATION/renode-test
sed -i '/TESTS_FILE/d' $DESTINATION/renode-test
sed -i '/TESTS_RESULTS/d' $DESTINATION/renode-test

cp -r $RENODE_ROOT_DIR/tests/platforms $DESTINATION/tests/platforms
cp -r $RENODE_ROOT_DIR/tests/peripherals $DESTINATION/tests/peripherals
cp -r $RENODE_ROOT_DIR/tests/metrics-analyzer $DESTINATION/tests/metrics-analyzer
cp -r $RENODE_ROOT_DIR/tests/network-server $DESTINATION/tests/network-server
cp -r $RENODE_ROOT_DIR/tests/tools $DESTINATION/tests/tools

# Don't copy RenodeTests directory
mkdir $DESTINATION/tests/unit-tests
find $RENODE_ROOT_DIR/tests/unit-tests \
    -not -path "$RENODE_ROOT_DIR/tests/unit-tests" \
    -not -path "$RENODE_ROOT_DIR/tests/unit-tests/RenodeTests" \
    -not -path "$RENODE_ROOT_DIR/tests/unit-tests/RenodeTests/*" \
    -exec cp -r "{}" "$DESTINATION/tests/unit-tests/" \;

# `tests.yaml` should only list robot files included in the original tests.yaml
sed '/csproj$/d' $BASE/tests/tests.yaml > $DESTINATION/tests/tests.yaml

$BASE/tools/packaging/common_copy_dts2repl_version_script.sh $BASE $DESTINATION

$BASE/tools/packaging/common_copy_licenses.sh $DESTINATION/licenses linux

cp $RENODE_ROOT_DIR/.renode-root $DESTINATION
cp -r $RENODE_ROOT_DIR/scripts $DESTINATION
cp -r $RENODE_ROOT_DIR/platforms $DESTINATION
