#!/usr/bin/env bash

set -e
set -u

THIS_DIR="$(cd $(dirname $0); echo $PWD)"
cd $THIS_DIR

. common_make_packages.sh

RENODE_ROOT_DIR=$THIS_DIR/../..
RENODE_PUBLISH=$RENODE_ROOT_DIR/output/publish/$TARGET/$RID
DIR=renode_${VERSION}-portable
OS_NAME=linux
ARCHIVE_NAME="renode-$VERSION.linux-portable.tar.gz"
if [[ $RID == "linux-arm64" ]]; then
    ARCHIVE_NAME="renode-$VERSION.$RID-portable.tar.gz"
fi

. common_copy_files_portable.sh

cp -r $RENODE_PUBLISH/. $DIR
mv $DIR/Renode $DIR/renode

# Handle a very rare case where the binary doesn't have the execute permission after building.
chmod +x $DIR/renode

sed_inplace '/run_tests.py/s/$/ --exclude "skip_portable"/' "$DIR/renode-test"

# Create tar
mkdir -p ../../output/packages
tar -czf ../../output/packages/$ARCHIVE_NAME $DIR

echo "Created a dotnet portable package in output/packages/$ARCHIVE_NAME"

# Cleanup

if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
