#!/usr/bin/env bash

rm -rf $DIR
mkdir -p $DIR/bin

#copy the main content
cp -r $BASE/output/bin/$TARGET/*.dll $DIR/bin
cp -r $BASE/output/bin/$TARGET/libllvm-disas.* $DIR/bin
cp -r $BASE/output/bin/$TARGET/*.dll.config $DIR/bin 2>/dev/null || true

if ls $BASE/output/bin/$TARGET/*.exe
then
    cp -r $BASE/output/bin/$TARGET/*.exe $DIR/bin
fi

. common_copy_files.sh

function copy_bash_tests_scripts() {
    TEST_SCRIPT=$1
    COMMON_SCRIPT=$2
    RUNNER=$3

    cp -r $BASE/renode-test $TEST_SCRIPT

    $SED_COMMAND 's#tools/##' $TEST_SCRIPT
    $SED_COMMAND 's#tests/run_tests.py#run_tests.py#' $TEST_SCRIPT
    $SED_COMMAND 's#--properties-file.*#--robot-framework-remote-server-full-directory='"$INSTALL_DIR"'/bin --css-file='"$INSTALL_DIR"'/tests/robot.css -r $(pwd) --runner='$RUNNER' "$@"#' $TEST_SCRIPT
    $SED_COMMAND 's#^ROOT_PATH=".*#ROOT_PATH="'"$INSTALL_DIR"'/tests"#g' $TEST_SCRIPT
    $SED_COMMAND '/TESTS_FILE/d' $TEST_SCRIPT
    $SED_COMMAND '/TESTS_RESULTS/d' $TEST_SCRIPT

    cp -r $BASE/tools/common.sh $COMMON_SCRIPT
}