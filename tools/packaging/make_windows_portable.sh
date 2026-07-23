#!/usr/bin/env bash

set -e
set -u

#change dir to script location
THIS_DIR="$(cd $(dirname $0); echo $PWD)"
cd $THIS_DIR
. common_make_packages.sh

RENODE_PUBLISH=$BASE/output/publish/$TARGET/$RID
HEADLESS_SUFFIX=""
if $HEADLESS
then
    HEADLESS_SUFFIX="-headless"
fi
DIR=renode_${VERSION}-portable${HEADLESS_SUFFIX}
ZIP_NAME="renode-$VERSION.windows-portable${HEADLESS_SUFFIX}.zip"
OS_NAME=windows

. common_copy_files_portable.sh

# Remove bash scripts
rm $DIR/tests/common.sh
rm $DIR/renode-test

### prepare renode-test
copy_windows_tests_scripts ".." renode.exe

copy_publish_output $DIR
mv $DIR/Renode.exe $DIR/renode.exe

### create zip
mkdir -p ../../output/packages
# Absolute path to use the Windows builtin BSD tar instead of minGW tar
/c/Windows/SysWOW64/tar.exe -a -c -f "../../output/packages/$ZIP_NAME" $DIR

# Build installer
if ! $HEADLESS
then
    export BASE
    export VERSION
    windows_package_src=$DIR iscc "windows/renode.iss"
fi

echo "Created a dotnet portable package in output/packages/$ZIP_NAME"

# Cleanup
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
