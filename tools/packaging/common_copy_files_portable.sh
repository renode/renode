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

# Strip native shared libraries to reduce package size.
if [ "$TARGET" != "Debug" ] && command -v strip >/dev/null 2>&1; then
    case "$(uname -s)" in
        Linux)
            find "$DIR/platform-lib" -name "*.so" -type f -exec strip --strip-unneeded {} + 2>/dev/null || true
            ;;
        Darwin)
            # On macOS some shared libraries are named .so (like llvm-disas or tlib), some are .dylib (librenode)
            find "$DIR/platform-lib" \( -name "*.so" -o -name "*.dylib" \) -type f -exec strip -x {} + 2>/dev/null || true
            ;;
    esac
fi

sed_inplace 's#ROOT_PATH/tests/run_tests.py#TEST_PATH/run_tests.py#' $DIR/renode-test
sed_inplace 's#ROOT_PATH}/tools/common.sh#TEST_PATH}/common.sh#' $DIR/renode-test

sed_inplace 's# -r "`get_path "$TESTS_RESULTS"`" -t "`get_path "$TESTS_FILE"`"##' $DIR/renode-test
sed_inplace '/run_tests.py/s#$# --robot-framework-remote-server-full-directory=$ROOT_PATH --robot-framework-remote-server-name=renode --css-file=$TEST_PATH/robot.css -r $(pwd)#' $DIR/renode-test

sed_inplace $'/^ROOT_PATH=.*/a\\\n TEST_PATH=$ROOT_PATH/tests' $DIR/renode-test
sed_inplace '/TESTS_FILE/d' $DIR/renode-test
sed_inplace '/TESTS_RESULTS/d' $DIR/renode-test

function copy_publish_output {
    cp -r $RENODE_PUBLISH/. $1
    if [ "$TARGET" == "Debug" ]; then
        return
    fi
    # Managed debug symbol files are only useful for development, drop them from Release packages.
    find $1 -name "*.pdb" -delete
    # Trim unused parts of the bundled Python standard library
    trim_python_stdlib $1/Lib
    # Drop diagnostics-only runtime components.
    rm -f $1/*mscordaccore.* $1/*mscordbi.* $1/*coreclrtraceptprovider.* $1/createdump*
}
