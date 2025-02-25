#!/usr/bin/env bash

set -e
set -u

cd "${0%/*}"
. common_make_packages.sh

RENODE_ROOT_DIR=$BASE
OS_NAME=macos
SED_COMMAND="sed -i.sed_backup"

# create MacOS app structure
MACOS_APP_DIR=Renode.app
PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES
mkdir -p $MACOS_APP_DIR/Contents/{MacOS,Resources}/
INSTALL_DIR=/Applications/Renode.app/Contents/MacOS
DIR=$MACOS_APP_DIR/Contents/MacOS

. common_copy_files_package.sh

cp -r $RENODE_ROOT_DIR/output/bin/$TARGET/runtimes $DIR/bin
cp $RENODE_ROOT_DIR/output/bin/$TARGET/Renode.runtimeconfig.json $DIR/bin
cp $RENODE_ROOT_DIR/output/bin/$TARGET/Renode.deps.json $DIR/bin
cp $RENODE_ROOT_DIR/output/bin/$TARGET/*.dylib $DIR/bin

# Copy Lib directory which contains dependecies for IronPython
cp -r $RENODE_ROOT_DIR/output/bin/$TARGET/Lib $DIR/bin

COMMON_SCRIPT=$DIR/tests/common.sh
TEST_SCRIPT=$DIR/renode-test
RUNNER=dotnet
copy_bash_tests_scripts $TEST_SCRIPT $COMMON_SCRIPT $RUNNER

cp macos/macos_run.sh $MACOS_APP_DIR/Contents/MacOS
cp macos/Info.plist $MACOS_APP_DIR/Contents/
cp macos/renode.icns $MACOS_APP_DIR/Contents/Resources #Made with png2icns
cp macos/macos_run_dotnet.command $MACOS_APP_DIR/Contents/MacOS/macos_run.command
chmod +x $MACOS_APP_DIR/Contents/MacOS/macos_run.command

# remove sed backups
find $MACOS_APP_DIR -name *.sed_backup -exec rm {} \;

# Create dmg file
mkdir -p $OUTPUT
hdiutil create -volname Renode_$VERSION -srcfolder $MACOS_APP_DIR -ov -format UDZO $OUTPUT/renode_$VERSION\_dotnet.dmg

# Cleanup
rm -rf $MACOS_APP_DIR
