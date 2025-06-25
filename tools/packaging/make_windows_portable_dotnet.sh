#!/usr/bin/env bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

RENODE_OUTPUT_DIR=$BASE/output/bin/$TARGET/$RID
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
cp \
    $RENODE_OUTPUT_DIR/../libllvm-disas.dll \
    $RENODE_OUTPUT_DIR/hostfxr.dll \
    $RENODE_OUTPUT_DIR/coreclr.dll \
    $RENODE_OUTPUT_DIR/hostpolicy.dll \
    $RENODE_OUTPUT_DIR/clrjit.dll \
    $RENODE_OUTPUT_DIR/System.IO.Compression.Native.dll \
    $RENODE_OUTPUT_DIR/mscordaccore.dll \
    $RENODE_OUTPUT_DIR/mscordbi.dll \
    $RENODE_OUTPUT_DIR/Renode.runtimeconfig.json \
    $RENODE_OUTPUT_DIR/Renode.deps.json \
    $DIR

### create zip
mkdir -p ../../output/packages
# Absolute path to use the Windows builtin BSD tar instead of minGW tar
/c/Windows/SysWOW64/tar.exe -a -c -f ../../output/packages/renode-$VERSION.windows-portable-dotnet.zip $DIR

# Build installer
export BASE
export VERSION
windows_package_src=$DIR iscc "windows/renode.iss"

echo "Created a dotnet portable package in output/packages/renode-$VERSION.windows-portable-dotnet.zip"

# Cleanup
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
