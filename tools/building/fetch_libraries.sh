#!/usr/bin/env bash

set -e
set -u

RESOURCES_REMOTE="${RESOURCES_REMOTE:-https://github.com/renode/renode-resources.git}"
RESOURCES_BRANCH="${RESOURCES_BRANCH:-master}"

CURRENT_PATH=`dirname $0`

GUARD=".renode_libs_fetched"

LIB_DIR="$CURRENT_PATH/../../lib"
DIR="$LIB_DIR/resources"

mkdir -p "$LIB_DIR"

source "$CURRENT_PATH/../common.sh"

clone_if_necessary "renode-resources" "$RESOURCES_REMOTE" "$RESOURCES_BRANCH" "$DIR" "$GUARD"

touch "$GUARD"
