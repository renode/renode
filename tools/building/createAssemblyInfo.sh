#!/usr/bin/env bash

# Create AssemblyInfo.cs but only when the file does not exists or has different version information
FILE_NAME="AssemblyInfo"

CURRENT_VERSION=`cat ../../../tools/version`
CURRENT_INFORMATIONAL_VERSION="`git rev-parse --short=8 HEAD`"

PARAMS=()
if ! grep "$CURRENT_VERSION" $FILE_NAME.cs > /dev/null 2>/dev/null \
    || ! grep "$CURRENT_INFORMATIONAL_VERSION" $FILE_NAME.cs > /dev/null 2>/dev/null
then
    content=$(sed -e "s;%VERSION%;$CURRENT_VERSION;" -e "s;%INFORMATIONAL_VERSION%;$CURRENT_INFORMATIONAL_VERSION-`date +%Y%m%d%H%M`;" $FILE_NAME.template)
    echo -n "$content" > $FILE_NAME.cs
fi

