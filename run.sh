#!/bin/bash
set -e
set -u

BINARY_LOCATION="$PWD/output/bin" BINARY_NAME=Renode.exe ./src/Emul8/run.sh "$@"

