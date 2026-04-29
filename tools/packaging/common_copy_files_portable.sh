#!/usr/bin/env bash

rm -rf $DIR

. common_copy_files.sh

cp -r $BASE/renode-test $DIR
cp -r $BASE/output/bin/$TARGET/platform-lib $DIR
. $BASE/tools/building/native_interface_runtime_config.sh
copy_native_interface_runtime_configs "$BASE/output/bin/$TARGET" "$DIR/platform-lib"
# Copy hostfxr for librenode use
if [[ -d "$BASE/output/bin/$TARGET/host" ]]; then
    cp -r $BASE/output/bin/$TARGET/host $DIR
fi
cp -r $BASE/tools/common.sh $DIR/tests

sed_inplace 's#ROOT_PATH/tests/run_tests.py#TEST_PATH/run_tests.py#' $DIR/renode-test
sed_inplace 's#ROOT_PATH}/tools/common.sh#TEST_PATH}/common.sh#' $DIR/renode-test

sed_inplace 's# -r "`get_path "$TESTS_RESULTS"`" -t "`get_path "$TESTS_FILE"`"##' $DIR/renode-test
sed_inplace '/run_tests.py/s#$# --robot-framework-remote-server-full-directory=$ROOT_PATH --robot-framework-remote-server-name=renode --css-file=$TEST_PATH/robot.css -r $(pwd)#' $DIR/renode-test

sed_inplace $'/^ROOT_PATH=.*/a\\\n TEST_PATH=$ROOT_PATH/tests' $DIR/renode-test
sed_inplace '/TESTS_FILE/d' $DIR/renode-test
sed_inplace '/TESTS_RESULTS/d' $DIR/renode-test
