#!/usr/bin/env bash

rm -rf $DIR
mkdir -p $DIR/bin

#copy the main content
cp -Pr $BASE/output/bin/$TARGET/*.dll $DIR/bin
# exclude any potential test DLLs
rm -r $DIR/bin/*Tests.dll 2>/dev/null || true
cp -Pr $BASE/output/bin/$TARGET/*.dll.config $DIR/bin 2>/dev/null || true
cp -Pr $BASE/output/bin/$TARGET/platform-lib $DIR/bin
cp -Pr $BASE/output/bin/$TARGET/runtimes $DIR/bin

# Copy Lib directory which contains dependecies for IronPython
cp -Pr $BASE/output/bin/$TARGET/Lib $DIR/bin

cp $BASE/output/bin/$TARGET/Renode.runtimeconfig.json $DIR/bin
cp $BASE/output/bin/$TARGET/RenodeWPF.runtimeconfig.json $DIR/bin 2>/dev/null || true
cp $BASE/output/bin/$TARGET/Renode.deps.json $DIR/bin

# Remove RenodeTests because they are unused in the package
rm -rf $DIR/tests/unit-tests/RenodeTests

. $BASE/tools/building/native_interface_runtime_config.sh
copy_native_interface_runtime_configs "$BASE/output/bin/$TARGET" "$DIR/bin/platform-lib"

if ls $BASE/output/bin/$TARGET/*.exe
then
    cp -Pr $BASE/output/bin/$TARGET/*.exe $DIR/bin
fi

. common_copy_files.sh

function copy_bash_tests_scripts() {
    TEST_SCRIPT=$1
    COMMON_SCRIPT=$2

    cp -r $BASE/renode-test $TEST_SCRIPT

    sed_inplace 's#tools/##' $TEST_SCRIPT
    sed_inplace 's#tests/run_tests.py#run_tests.py#' $TEST_SCRIPT

    sed_inplace 's# -r "`get_path "$TESTS_RESULTS"`" -t "`get_path "$TESTS_FILE"`"##' $TEST_SCRIPT
    sed_inplace '/run_tests.py/s#$# --robot-framework-remote-server-full-directory='"$INSTALL_DIR"'/bin --css-file='"$INSTALL_DIR"'/tests/robot.css -r $(pwd)#' $TEST_SCRIPT

    sed_inplace 's#^ROOT_PATH=".*#ROOT_PATH="'"$INSTALL_DIR"'/tests"#g' $TEST_SCRIPT
    sed_inplace '/TESTS_FILE/d' $TEST_SCRIPT
    sed_inplace '/TESTS_RESULTS/d' $TEST_SCRIPT

    cp -r $BASE/tools/common.sh $COMMON_SCRIPT
}
