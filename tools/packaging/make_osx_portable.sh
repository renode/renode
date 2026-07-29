#!/usr/bin/env bash

set -e
set -u

cd "${0%/*}"
. common_make_packages.sh

RENODE_PUBLISH=$BASE/output/publish/$TARGET/$RID
HEADLESS_SUFFIX=""
if $HEADLESS; then
    HEADLESS_SUFFIX="-headless"
fi

# create MacOS app structure
MACOS_APP_DIR=Renode.app
PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES
mkdir -p $MACOS_APP_DIR/Contents/{MacOS,Resources}/
INSTALL_DIR=/Applications/Renode.app/Contents/MacOS

DIR=$MACOS_APP_DIR/Contents/MacOS

OS_NAME=macos

. common_copy_files_portable.sh

copy_publish_output $DIR
mv $DIR/Renode $DIR/renode

chmod +x $DIR/renode

sed_inplace '/run_tests.py/s/$/ --exclude "exclude_portable"/' "$DIR/renode-test"

cp macos/macos_run.sh $MACOS_APP_DIR/Contents/MacOS
cp macos/Info.plist $MACOS_APP_DIR/Contents/Info.plist
cp macos/renode.icns $MACOS_APP_DIR/Contents/Resources #Made with png2icns
cp macos/macos_run_portable.command $MACOS_APP_DIR/Contents/MacOS/macos_run.command
chmod +x $MACOS_APP_DIR/Contents/MacOS/macos_run.command

OUTPUT=$BASE/$PACKAGES

# Create dmg file
mkdir -p $OUTPUT
hdiutil create -volname Renode_$VERSION -srcfolder $MACOS_APP_DIR -ov -format UDZO $OUTPUT/renode-$VERSION.$RID-portable${HEADLESS_SUFFIX}.dmg

# Cleanup
rm -rf $MACOS_APP_DIR
