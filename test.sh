#!/bin/bash

ROOT_PATH="`dirname \"\`realpath "$0"\`\"`"
ROBOT_LOCATION="$ROOT_PATH/output/bin"
TESTS_FILE="$ROOT_PATH/tests/tests.txt"
TESTS_RESULTS="$ROOT_PATH/output/tests"

. "${ROOT_PATH}/tools/common.sh"

python "`get_path "$ROOT_PATH/tests/run_tests.py"`" --properties-file "`get_path "$ROOT_PATH/output/properties.csproj"`" -r "`get_path "$TESTS_RESULTS"`" -t "`get_path "$TESTS_FILE"`" "$@"
