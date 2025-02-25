#!/bin/sh

#get the bundle's MacOS directory full path
DIR=`dirname $0`

PROCESS_NAME=appname
APPNAME="Renode"

exec -a \"$PROCESS_NAME\" "$DIR/renode" "$@"
