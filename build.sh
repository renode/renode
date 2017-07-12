#!/bin/bash
set -e

ROOT_PATH="`dirname \"\`realpath "$0"\`\"`"
TARGET="$ROOT_PATH/output/Renode.sln"
if [ ! -f "$TARGET" ]
then
    ./configure
fi

. "${ROOT_PATH}/src/Emul8/Tools/common.sh"

VERSION=1.0
DEBUG=false

while getopts ":pd" opt
do
  case $opt in
    d)
      DEBUG=true
      ;;
  esac
done

cd src/Emul8
PARAMS=( \
    -t "`get_path "$TARGET"`" \
    -o "`get_path "$PWD/../../output/bin"`")
./build.sh "${PARAMS[@]}" "$@"
