rm -rf $DIR
mkdir -p $DIR/{bin,licenses,tests}

#copy the main content
cp -r $BASE/output/bin/$TARGET/*.{dll,exe,dll.config} $DIR/bin
cp -r $BASE/{.renode-root,scripts,platforms} $DIR

#copy the test instrastructure and update the paths
cp -r $BASE/src/Renode/RobotFrameworkEngine/*.{py,robot} $DIR/tests
sed -i 's#^${DIRECTORY}.*#${DIRECTORY}              ${CURDIR}/../bin#' $DIR/tests/renode-keywords.robot

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

