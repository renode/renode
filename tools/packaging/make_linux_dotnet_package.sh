#!/usr/bin/env bash

set -e
set -u

cd "${0%/*}"
. common_make_packages.sh

RENODE_ROOT_DIR=$BASE

DIR=renode_${VERSION}-dotnet
# Contents of this variable should be pasted verbatim into renode-test script.
INSTALL_DIR='$(cd $(dirname $(readlink -f $0 2>/dev/null || echo $0)); echo $PWD)'
OS_NAME=linux
SED_COMMAND="sed -i"

cp $RENODE_ROOT_DIR/output/bin/$TARGET/libllvm-disas.so $RENODE_ROOT_DIR/output/bin/$TARGET/publish

# Override the TARGET variable.
# It is used to copy files into final package directory and all required files were moved there.
TARGET="$TARGET/publish"

. common_copy_files_package.sh

# Remove RenodeTests because they are unused in the package
rm -rf $DIR/tests/unit-tests/RenodeTests

cp -r $RENODE_ROOT_DIR/output/bin/$TARGET/runtimes $DIR/bin
cp $RENODE_ROOT_DIR/output/bin/$TARGET/Renode.runtimeconfig.json $DIR/bin
cp $RENODE_ROOT_DIR/output/bin/$TARGET/Renode.deps.json $DIR/bin
cp $RENODE_ROOT_DIR/output/bin/$TARGET/*.so $DIR/bin

# Copy Lib directory which contains dependecies for IronPython
cp -r $RENODE_ROOT_DIR/output/bin/$TARGET/Lib $DIR/bin

COMMON_SCRIPT=$DIR/tests/common.sh
TEST_SCRIPT=$DIR/renode-test
RUNNER=dotnet
copy_bash_tests_scripts $TEST_SCRIPT $COMMON_SCRIPT $RUNNER

COMMAND_SCRIPT=$DIR/renode
cp linux/renode-dotnet-template $COMMAND_SCRIPT
chmod +x $COMMAND_SCRIPT

PKG=renode-$VERSION.linux-dotnet.tar.gz

# Create tar
mkdir -p $RENODE_ROOT_DIR/output/packages
tar -czf $RENODE_ROOT_DIR/output/packages/$PKG $DIR

echo "Created a dotnet package in output/packages/$PKG"

# Cleanup
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
