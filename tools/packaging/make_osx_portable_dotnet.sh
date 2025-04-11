#!/usr/bin/env bash

set -e
set -u

cd "${0%/*}"
. common_make_packages.sh

RENODE_OUTPUT_DIR=$BASE/output/bin/$TARGET/$RID
RENODE_OUTPUT_BINARY=$RENODE_OUTPUT_DIR/publish/Renode
DESTINATION=renode_${VERSION}-dotnet_portable

# create MacOS app structure
MACOS_APP_DIR=Renode.app
PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES
mkdir -p $MACOS_APP_DIR/Contents/{MacOS,Resources}/
INSTALL_DIR=/Applications/Renode.app/Contents/MacOS

DIR=$MACOS_APP_DIR/Contents/MacOS

OS_NAME=macos
SED_COMMAND="sed -i ''"

. common_copy_files_portable.sh

cp $RENODE_OUTPUT_BINARY $DIR/renode
cp $RENODE_OUTPUT_DIR/*.dylib $DIR
cp $RENODE_OUTPUT_DIR/../libllvm-disas.dylib $DIR

chmod +x $DIR/renode

cp macos/macos_run.sh $MACOS_APP_DIR/Contents/MacOS
cp macos/Info.plist $MACOS_APP_DIR/Contents/Info.plist
cp macos/renode.icns $MACOS_APP_DIR/Contents/Resources #Made with png2icns
cp macos/macos_run_dotnet_portable.command $MACOS_APP_DIR/Contents/MacOS/macos_run.command
chmod +x $MACOS_APP_DIR/Contents/MacOS/macos_run.command

OUTPUT=$BASE/$PACKAGES

# Create dmg file
mkdir -p $OUTPUT
hdiutil create -volname Renode_$VERSION -srcfolder $MACOS_APP_DIR -ov -format UDZO $OUTPUT/renode-$VERSION-dotnet.$RID-portable.dmg

# Cleanup
rm -rf $MACOS_APP_DIR
