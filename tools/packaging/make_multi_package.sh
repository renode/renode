#!/usr/bin/env bash

set -e
set -u

THIS_DIR="$(cd $(dirname $0); echo $PWD)"
cd $THIS_DIR

. common_make_packages.sh

OS_NAME=any
DIR=renode_${VERSION}-multi

. common_copy_files_package.sh

# Unix command scripts
cp linux/renode-dotnet-template $DIR/renode
INSTALL_DIR='$(cd $(dirname $(readlink -f $0 2>/dev/null || echo $0)); echo $PWD)'
COMMON_SCRIPT=$DIR/tests/common.sh
TEST_SCRIPT=$DIR/renode-test
copy_bash_tests_scripts $TEST_SCRIPT $COMMON_SCRIPT

# Windows command scripts
cp $THIS_DIR/windows/renode.bat $DIR
copy_windows_tests_scripts "..\\\\bin" RenodeWPF.dll

# Create tar
ARCHIVE_NAME="renode-$VERSION.multiplatform.zip"
mkdir -p ../../output/packages
rm -f ../../output/packages/$ARCHIVE_NAME
zip -rq ../../output/packages/$ARCHIVE_NAME $DIR

echo "Created a multiplatform package in output/packages/$ARCHIVE_NAME"

# Cleanup

if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
