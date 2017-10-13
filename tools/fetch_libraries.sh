#!/bin/bash

set -e
set -u

REMOTE=https://github.com/renode/renode-resources.git
CURRENT_PATH="`dirname \"\`realpath "$0"\`\"`"
DIR="$CURRENT_PATH/../resources"
GUARD=`realpath --relative-to="$ROOT_PATH" "$CURRENT_PATH/../.renode_libs_fetched"`

source "$CURRENT_PATH/../src/Emul8/Tools/common.sh"

clone_if_necessary "Renode" "$REMOTE" "$DIR" "$GUARD" "$PWD"

touch "$GUARD"
