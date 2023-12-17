#!/usr/bin/env bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

if ! is_dep_available zip
then
    exit 1
fi

RENODE_OUTPUT_DIR=$BASE/output/bin/$TARGET/$TFM/$RID
RENODE_OUTPUT_BINARY=$RENODE_OUTPUT_DIR/publish/Renode
DIR=renode_${VERSION}-dotnet_portable
OS_NAME=windows
SED_COMMAND="sed -i"

. common_copy_files_portable.sh

# Remove bash scripts
rm $DIR/tests/common.sh
rm $DIR/renode-test

### prepare renode-test
cat >> $DIR/tests/test.bat << EOL
@echo off
set SCRIPTDIR=%~dp0
py -3 "%SCRIPTDIR%\run_tests.py" --css-file "%SCRIPTDIR%\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory "%SCRIPTDIR%\.." -r %cd% %*
EOL

cat >> $DIR/renode-test.bat << EOL
@echo off
set test_script=%~dp0%\tests\test.bat
call "%test_script%" %*
EOL

cp $RENODE_OUTPUT_BINARY $DIR/renode
cp $RENODE_OUTPUT_DIR/../libllvm-disas.dll $DIR

### create zip
mkdir -p ../../output/packages
zip -qr ../../output/packages/renode-$VERSION.windows-portable-dotnet.zip $DIR

echo "Created a dotnet portable package in output/packages/renode-$VERSION.windows-portable-dotnet.zip"

# Cleanup
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
