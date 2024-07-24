#!/usr/bin/env bash

rm -rf $DIR

. common_copy_files.sh

cp -r $BASE/renode-test $DIR
cp -r $BASE/tools/common.sh $DIR/tests

$SED_COMMAND 's#ROOT_PATH/tests/run_tests.py#TEST_PATH/run_tests.py#' $DIR/renode-test
$SED_COMMAND 's#ROOT_PATH}/tools/common.sh#TEST_PATH}/common.sh#' $DIR/renode-test
$SED_COMMAND 's#--properties-file.*#--robot-framework-remote-server-full-directory=$ROOT_PATH --robot-framework-remote-server-name=renode --css-file=$TEST_PATH/robot.css --runner=none -r $(pwd) "$@"#' $DIR/renode-test
$SED_COMMAND '/^ROOT_PATH=.*/a TEST_PATH=$ROOT_PATH/tests' $DIR/renode-test
$SED_COMMAND '/TESTS_FILE/d' $DIR/renode-test
$SED_COMMAND '/TESTS_RESULTS/d' $DIR/renode-test