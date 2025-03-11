#!/usr/bin/env bash

set -e
set -u

THIS_DIR="$(cd $(dirname $0); echo $PWD)"
cd $THIS_DIR

. common_make_packages.sh

RENODE_ROOT_DIR=$THIS_DIR/../..
RENODE_OUTPUT_DIR=$RENODE_ROOT_DIR/output/bin/$TARGET/$RID
RENODE_OUTPUT_BINARY=$RENODE_OUTPUT_DIR/publish/Renode
DESTINATION=renode_${VERSION}-dotnet_portable
OS_NAME=linux
SED_COMMAND="sed -i"
DIR=$DESTINATION

. common_copy_files_portable.sh

cp $RENODE_OUTPUT_BINARY $DESTINATION/renode
cp \
   $RENODE_OUTPUT_DIR/../libllvm-disas.so \
   $RENODE_OUTPUT_DIR/libhostfxr.so \
   $RENODE_OUTPUT_DIR/libcoreclr.so \
   $RENODE_OUTPUT_DIR/libhostpolicy.so \
   $RENODE_OUTPUT_DIR/libclrjit.so \
   $RENODE_OUTPUT_DIR/libSystem.Native.so \
   $RENODE_OUTPUT_DIR/libSystem.Security.Cryptography.Native.OpenSsl.so \
   $RENODE_OUTPUT_DIR/libMono.Unix.so \
   $RENODE_OUTPUT_DIR/libSystem.Globalization.Native.so \
   $RENODE_OUTPUT_DIR/libSystem.IO.Compression.Native.so \
   $RENODE_OUTPUT_DIR/libSystem.Net.Security.Native.so \
   $RENODE_OUTPUT_DIR/libcoreclrtraceptprovider.so \
   $RENODE_OUTPUT_DIR/libmscordaccore.so \
   $RENODE_OUTPUT_DIR/libmscordbi.so \
   $DESTINATION

# Handle a very rare case where the binary doesn't have the execute permission after building.
chmod +x $DESTINATION/renode

# Create tar
mkdir -p ../../output/packages
tar -czf ../../output/packages/renode-$VERSION.linux-portable-dotnet.tar.gz $DESTINATION

echo "Created a dotnet portable package in output/packages/renode-$VERSION.linux-portable-dotnet.tar.gz"

# Cleanup

if $REMOVE_WORKDIR
then
    rm -rf $DESTINATION
fi
