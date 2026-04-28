#!/usr/bin/env bash

set -e
set -u

#change dir to script location
THIS_DIR="$(cd $(dirname $0); echo $PWD)"
cd $THIS_DIR
. common_make_packages.sh

RENODE_PUBLISH=$BASE/output/publish/$TARGET/$RID
DIR=renode_${VERSION}-portable
OS_NAME=windows

. common_copy_files_portable.sh

# Remove bash scripts
rm $DIR/tests/common.sh
rm $DIR/renode-test

### prepare renode-test
copy_windows_tests_scripts ".." renode.exe

cp -r $RENODE_PUBLISH/. $DIR
mv $DIR/Renode.exe $DIR/renode.exe

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
