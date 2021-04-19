#!/bin/sh

#get the bundle's MacOS directory full path
DIR=`dirname $0`

EXE_PATH="$DIR/bin/Renode.exe"
PROCESS_NAME=appname
APPNAME="Renode"

#set up environment
MONO_FRAMEWORK_PATH=/Library/Frameworks/Mono.framework/Versions/Current
export DYLD_FALLBACK_LIBRARY_PATH="$DIR:$MONO_FRAMEWORK_PATH/lib:/lib:/usr/lib"
export PATH="$MONO_FRAMEWORK_PATH/bin:$PATH"

# REQUIRED_MAJOR and REQUIRED_MINOR should be
# set automatically at the moment of packaging
if [ -z "$REQUIRED_MAJOR" -o -z "$REQUIRED_MINOR" ]
then
	echo "No required mono version set. It most probably indicates a problem in packaging scripts"
	exit 1
fi

VERSION_TITLE="Cannot launch $APPNAME"
VERSION_MSG="$APPNAME requires the Mono Framework version $REQUIRED_MAJOR.$REQUIRED_MINOR or later."
DOWNLOAD_URL="http://www.mono-project.com/download/stable/"

MONO_VERSION="$(mono64 --version | grep 'Mono JIT compiler version ' |  cut -f5 -d\ )"
MONO_VERSION_MAJOR="$(echo $MONO_VERSION | cut -f1 -d.)"
MONO_VERSION_MINOR="$(echo $MONO_VERSION | cut -f2 -d.)"
if [ -z "$MONO_VERSION" ] \
	|| [ $MONO_VERSION_MAJOR -lt $REQUIRED_MAJOR ] \
	|| [ $MONO_VERSION_MAJOR -eq $REQUIRED_MAJOR -a $MONO_VERSION_MINOR -lt $REQUIRED_MINOR ]
then
	osascript \
	-e "set question to display dialog \"$VERSION_MSG\" with title \"$VERSION_TITLE\" buttons {\"Cancel\", \"Download...\"} default button 2" \
	-e "if button returned of question is equal to \"Download...\" then open location \"$DOWNLOAD_URL\""
	echo "$VERSION_TITLE"
	echo "$VERSION_MSG"
	exit 1
fi

#run app using mono
exec -a \"$PROCESS_NAME\" mono64 $MONO_OPTIONS "$EXE_PATH" "$@"
