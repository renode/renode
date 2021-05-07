#!/bin/bash

set -e
set -u

REMOTE=https://github.com/renode/renode-resources.git
BRANCH=master
CURRENT_PATH="`dirname \"\`realpath "$0"\`\"`"
LIB_DIR="$CURRENT_PATH/../../lib"
DIR="$LIB_DIR/resources"
case `uname` in
  Linux) GUARD=`realpath --relative-to="$ROOT_PATH" "$CURRENT_PATH/../../.renode_libs_fetched"` ;;
  *)     GUARD="$CURRENT_PATH/../../.renode_libs_fetched" ;;
esac

mkdir -p "$LIB_DIR"

source "$CURRENT_PATH/../common.sh"

clone_if_necessary "renode-resources" "$REMOTE" "$BRANCH" "$DIR" "$GUARD" "$PWD"

touch "$GUARD"
