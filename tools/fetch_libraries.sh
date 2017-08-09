#!/bin/bash

set -e
set -u

REMOTE=https://github.com/renode/renode-resources.git
CURRENT_PATH="`dirname \"\`realpath "$0"\`\"`"
DIR="$CURRENT_PATH/../resources"
GUARD=`realpath --relative-to="$ROOT_PATH" "$CURRENT_PATH/../.renode_libs_fetched"`

if [ -e "$GUARD" ]
then
    top_ref=`git ls-remote -h $REMOTE master | cut -f1`
    pushd "$DIR" >/dev/null
    cur_ref=`git rev-parse HEAD`
    master_ref=`git rev-parse master`
    if [ $master_ref != $cur_ref ]
    then
        echo "The Renode libraries repository is not on the local master branch. This situation should be handled manually."
        exit
    fi
    popd >/dev/null
    if [ $top_ref == $cur_ref ]
    then
        echo "Required Renode libraries already downloaded. To repeat the process remove $GUARD file."
        exit
    fi
    echo "Required Renode libraries are available in a new version. The libraries will be redownloaded..."
fi

rm -rf "$DIR"
git clone $REMOTE "$DIR"

touch "$GUARD"
