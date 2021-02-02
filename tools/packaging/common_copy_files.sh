rm -rf $DIR
mkdir -p $DIR/{bin,licenses,tests,tools}

#copy the main content
cp -r $BASE/output/bin/$TARGET/*.{dll,exe} $DIR/bin
cp -r $BASE/output/bin/$TARGET/*.dll.config $DIR/bin 2>/dev/null || true
cp -r $BASE/{.renode-root,scripts,platforms} $DIR
cp -r $BASE/tools/metrics_analyzer $DIR/tools

#copy the test instrastructure and update the paths
cp -r $BASE/src/Renode/RobotFrameworkEngine/*.{py,robot} $DIR/tests
#sed has different parameters on osx/linux so the command must be defined by scripts including this one
$SED_COMMAND 's#^${DIRECTORY}.*#${DIRECTORY}              ${CURDIR}/../bin#' $DIR/tests/renode-keywords.robot
cp $BASE/lib/resources/styles/robot.css $DIR/tests/robot.css
cp $BASE/tests/requirements.txt $DIR/tests/requirements.txt

#copy the licenses
#some files already include the library name
find $BASE/src/Infrastructure/src/Emulator $BASE/lib  $BASE/tools/packaging/macos -iname "*-license" -exec cp {} $DIR/licenses \;

#others will need a parent directory name.
find $BASE/{src/Infrastructure,lib/resources} -iname "license" -print0 |\
    while IFS= read -r -d $'\0' file
do
    full_dirname=${file%/*}
    dirname=${full_dirname##*/}
    cp $file $DIR/licenses/$dirname-license
done

