#!/bin/bash

ROOT_PATH="`dirname \`realpath $0\``"
ROBOT_LOCATION=$ROOT_PATH/output/bin
TESTS_FILE=$ROOT_PATH/output/tests.txt
TESTS_RESULTS=$ROOT_PATH/output/tests

if [ ! -f "$TESTS_FILE" ]; then
    echo "Tests file not found. Please run ./bootstrap.sh script"
    exit 1
fi

$ROOT_PATH/tests/run_tests.py --properties-file "$ROOT_PATH/output/properties.csproj" -r "$TESTS_RESULTS" -t "$TESTS_FILE" $@
