#!/usr/bin/env bash

rm -rf $DIR

. common_copy_files.sh

cp -r $BASE/renode-test $DIR
# UI is built optionally and thus may not be present
cp -r $UI_BIN $DIR 2>/dev/null || true
cp -r $BASE/tools/common.sh $DIR/tests

sed_inplace 's#ROOT_PATH/tests/run_tests.py#TEST_PATH/run_tests.py#' $DIR/renode-test
sed_inplace 's#ROOT_PATH}/tools/common.sh#TEST_PATH}/common.sh#' $DIR/renode-test
sed_inplace 's#--properties-file.*#--robot-framework-remote-server-full-directory=$ROOT_PATH --robot-framework-remote-server-name=renode --css-file=$TEST_PATH/robot.css -r $(pwd) "$@"#' $DIR/renode-test
sed_inplace $'/^ROOT_PATH=.*/a\\\n TEST_PATH=$ROOT_PATH/tests' $DIR/renode-test
sed_inplace '/TESTS_FILE/d' $DIR/renode-test
sed_inplace '/TESTS_RESULTS/d' $DIR/renode-test
