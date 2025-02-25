#!/bin/sh

#get the bundle's MacOS directory full path
DIR=`dirname $0`

DLL_PATH="$DIR/bin/Renode.dll"
PROCESS_NAME=appname
APPNAME="Renode"

exec -a \"$PROCESS_NAME\" dotnet "$DLL_PATH" "$@"
