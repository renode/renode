#!/bin/bash

# Create AssemblyInfo.cs but only when the file does not exists or has different git commit
FILE_NAME="AssemblyInfo"
CURRENT_VERSION="`git rev-parse --short=8 HEAD`"
if ! grep "$CURRENT_VERSION" $FILE_NAME.cs > /dev/null 2>/dev/null
then
    sed -e "s;%VERSION%;$CURRENT_VERSION-`date +%Y%m%d%H%M`;" $FILE_NAME.template > $FILE_NAME.cs
fi

