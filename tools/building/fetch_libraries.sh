#!/usr/bin/env bash

set -e
set -u

REMOTE=https://github.com/renode/renode-resources.git
BRANCH=master

CURRENT_PATH=`dirname $0`

GUARD=".renode_libs_fetched"

LIB_DIR="$CURRENT_PATH/../../lib"
DIR="$LIB_DIR/resources"

mkdir -p "$LIB_DIR"

source "$CURRENT_PATH/../common.sh"

clone_if_necessary "renode-resources" "$REMOTE" "$BRANCH" "$DIR" "$GUARD"

touch "$GUARD"
