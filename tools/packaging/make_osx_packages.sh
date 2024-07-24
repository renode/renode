#!/usr/bin/env bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

# create MacOS app structure
MACOS_APP_DIR=Renode.app
PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES
mkdir -p $MACOS_APP_DIR/Contents/{MacOS,Resources}/
INSTALL_DIR=/Applications/Renode.app/Contents/MacOS

DIR=$MACOS_APP_DIR/Contents/MacOS

OS_NAME=macos
# OSX version of sed requires backup appendix when in-place editing, backups are removed later on
SED_COMMAND="sed -i.sed_backup"
. common_copy_files_package.sh

COMMON_SCRIPT=$DIR/tests/common.sh
TEST_SCRIPT=$DIR/tests/renode-test
RUNNER=mono
copy_bash_tests_scripts $TEST_SCRIPT $COMMON_SCRIPT $RUNNER

cp macos/macos_run.sh $MACOS_APP_DIR/Contents/MacOS
cp macos/Info.plist $MACOS_APP_DIR/Contents/
cp macos/renode.icns $MACOS_APP_DIR/Contents/Resources #Made with png2icns

COMMAND_SCRIPT=$MACOS_APP_DIR/Contents/MacOS/macos_run.command
echo "#!/bin/sh" >> $COMMAND_SCRIPT
echo "REQUIRED_MAJOR=$MONO_MAJOR" >> $COMMAND_SCRIPT
echo "REQUIRED_MINOR=$MONO_MINOR" >> $COMMAND_SCRIPT
# skip the first line (with the hashbang)
tail -n +2 macos/macos_run.command >> $COMMAND_SCRIPT
chmod +x $COMMAND_SCRIPT

# remove sed backups
find $MACOS_APP_DIR -name *.sed_backup -exec rm {} \;

mkdir -p $OUTPUT
hdiutil create -volname Renode_$VERSION -srcfolder $MACOS_APP_DIR -ov -format UDZO $OUTPUT/renode_$VERSION.dmg

#cleanup unless user requests otherwise
if $REMOVE_WORKDIR
then
  rm -rf $MACOS_APP_DIR
fi
