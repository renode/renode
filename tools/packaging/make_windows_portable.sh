#!/usr/bin/env bash

set -e
set -u

#change dir to script location
THIS_DIR="$(cd $(dirname $0); echo $PWD)"
cd $THIS_DIR
. common_make_packages.sh

RENODE_OUTPUT_DIR=$BASE/output/publish/$TARGET/$RID
RENODE_OUTPUT_BINARY=$RENODE_OUTPUT_DIR/Renode
DIR=renode_${VERSION}-portable
OS_NAME=windows

. common_copy_files_portable.sh

# Remove bash scripts
rm $DIR/tests/common.sh
rm $DIR/renode-test

### prepare renode-test
copy_windows_tests_scripts ".." Renode.exe

cp $RENODE_OUTPUT_BINARY $DIR/renode
cp \
    $RENODE_OUTPUT_DIR/hostfxr.dll \
    $RENODE_OUTPUT_DIR/coreclr.dll \
    $RENODE_OUTPUT_DIR/hostpolicy.dll \
    $RENODE_OUTPUT_DIR/clrjit.dll \
    $RENODE_OUTPUT_DIR/System.IO.Compression.Native.dll \
    $RENODE_OUTPUT_DIR/mscordaccore.dll \
    $RENODE_OUTPUT_DIR/mscordbi.dll \
    $RENODE_OUTPUT_DIR/Renode.runtimeconfig.json \
    $DIR

### create zip
mkdir -p ../../output/packages
# Absolute path to use the Windows builtin BSD tar instead of minGW tar
/c/Windows/SysWOW64/tar.exe -a -c -f ../../output/packages/renode-$VERSION.windows-portable.zip $DIR

# Build installer
export BASE
export VERSION
windows_package_src=$DIR iscc "windows/renode.iss"

echo "Created a dotnet portable package in output/packages/renode-$VERSION.windows-portable.zip"

# Cleanup
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
