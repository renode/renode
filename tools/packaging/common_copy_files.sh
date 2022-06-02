rm -rf $DIR
mkdir -p $DIR/{bin,licenses,tests,tools}

#copy the main content
cp -r $BASE/output/bin/$TARGET/*.{dll,exe} $DIR/bin
cp -r $BASE/output/bin/$TARGET/libllvm-disas.* $DIR/bin
cp -r $BASE/output/bin/$TARGET/*.dll.config $DIR/bin 2>/dev/null || true
cp -r $BASE/{.renode-root,scripts,platforms} $DIR
cp -r $BASE/tools/gdb_compare $DIR/tools
cp -r $BASE/tools/metrics_analyzer $DIR/tools
cp -r $BASE/tools/sel4_extensions $DIR/tools

#copy the test instrastructure and update the paths
cp -r $BASE/tests/metrics-analyzer $DIR/tests/metrics-analyzer
cp -r $BASE/tests/network-server $DIR/tests/network-server
cp -r $BASE/tests/peripherals $DIR/tests/peripherals
cp -r $BASE/tests/platforms $DIR/tests/platforms
cp -r $BASE/tests/{robot_tests_provider,run_tests,tests_engine,robot_output_formatter}.py $DIR/tests
cp -r $BASE/tests/tools $DIR/tests/tools
cp -r $BASE/tests/unit-tests $DIR/tests/unit-tests
$SED_COMMAND '/nunit/d' $DIR/tests/run_tests.py
$SED_COMMAND 's#os\.path\.join(this_path, "\.\./src/Renode/RobotFrameworkEngine/renode-keywords\.robot")#os.path.join(this_path,"renode-keywords.robot")#g' $DIR/tests/robot_tests_provider.py

# `tests.yaml` should only list robot files included in the original tests.yaml
sed '/csproj$/d' $BASE/tests/tests.yaml > $DIR/tests/tests.yaml

cp -r $BASE/src/Renode/RobotFrameworkEngine/*.{py,robot} $DIR/tests
#sed has different parameters on osx/linux so the command must be defined by scripts including this one
$SED_COMMAND 's#^${DIRECTORY}.*#${DIRECTORY}              ${CURDIR}/../bin#' $DIR/tests/renode-keywords.robot
cp $BASE/lib/resources/styles/robot.css $DIR/tests/robot.css
cp $BASE/tests/requirements.txt $DIR/tests/requirements.txt

#copy the licenses
#some files already include the library name
find $BASE/src/Infrastructure/src/Emulator $BASE/lib  $BASE/tools/packaging/macos -iname "*-license" -exec cp {} $DIR/licenses \;

#others will need a parent directory name.
find $BASE/{src/Infrastructure,lib} -iname "license" -print0 |\
    while IFS= read -r -d $'\0' file
do
    full_dirname=${file%/*}
    dirname=${full_dirname##*/}
    cp $file $DIR/licenses/$dirname-license
done

function copy_bash_tests_scripts() {
    TEST_SCRIPT=$1
    COMMON_SCRIPT=$2

    cp -r $BASE/renode-test $TEST_SCRIPT
    $SED_COMMAND 's#tools/##' $TEST_SCRIPT
    $SED_COMMAND 's#tests/run_tests.py#run_tests.py#' $TEST_SCRIPT
    $SED_COMMAND 's#--properties-file.*#--robot-framework-remote-server-full-directory='$INSTALL_DIR'/bin --css-file='$INSTALL_DIR'/tests/robot.css -r $(pwd) "$@"#' $TEST_SCRIPT
    $SED_COMMAND 's#^ROOT_PATH=".*#ROOT_PATH="'$INSTALL_DIR'/tests"#g' $TEST_SCRIPT
    $SED_COMMAND '/TESTS_FILE/d' $TEST_SCRIPT
    $SED_COMMAND '/TESTS_RESULTS/d' $TEST_SCRIPT

    cp -r $BASE/tools/common.sh $COMMON_SCRIPT
}

