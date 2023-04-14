#!/usr/bin/env bash

set -e
set -u

THIS_DIR="$(cd $(dirname $0); echo $PWD)"
cd $THIS_DIR

. common_make_packages.sh

RENODE_ROOT_DIR=$THIS_DIR/../..
RENODE_OUTPUT_DIR=$RENODE_ROOT_DIR/output/bin/$TARGET/$TFM/$RID
RENODE_OUTPUT_BINARY=$RENODE_OUTPUT_DIR/publish/Renode
DESTINATION=renode_${VERSION}-dotnet_portable

. common_make_linux_portable.sh

cp $RENODE_OUTPUT_BINARY $DESTINATION/renode
cp $RENODE_OUTPUT_DIR/../libllvm-disas.so $DESTINATION

# Create tar
mkdir -p ../../output/packages
tar -czf ../../output/packages/renode-$VERSION-dotnet.linux-portable.tar.gz $DESTINATION

echo "Created a dotnet portable package in output/packages/renode-$VERSION-dotnet.linux-portable.tar.gz"

# Cleanup

if $REMOVE_WORKDIR
then
    rm -rf $DESTINATION
fi
