#!/bin/bash

set -e
set -u

#change dir to script location
cd "${0%/*}"

TARGET="Release"
BASE=../..

REMOVE_WORKDIR=true

DATE=""
COMMIT=""

function help {
    echo "$0 {version-number} [-d] [-n] [-l]"
    echo
    echo -e "-d\tuse Debug configuration"
    echo -e "-n\tcreate a nightly build with date and commit SHA"
    echo -e "-l\tleave .app directory as is"
}

if [ $# -lt 1 ]
then
    help
    exit
fi

VERSION=$1

shift
while getopts "dnl" opt
do
    case $opt in
        d)
            TARGET="Debug"
            ;;
        n)
            DATE="+`date +%Y%m%d`"
            COMMIT="git`git rev-parse --short HEAD`"
            ;;
        l)
            REMOVE_WORKDIR=false
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            help
            exit
            ;;
    esac
done

VERSION="$VERSION$DATE$COMMIT"

# create MacOS app structure
MACOS_APP_DIR=Renode.app
mkdir -p $MACOS_APP_DIR/Contents/{MacOS,Resources}/

DIR=$MACOS_APP_DIR/Contents/MacOS

. common_copy_files.sh

cp macos/macos_run.* $MACOS_APP_DIR/Contents/MacOS
cp macos/Info.plist $MACOS_APP_DIR/Contents/
cp macos/renode.icns $MACOS_APP_DIR/Contents/Resources #Made with png2icns

hdiutil create -volname Renode_$VERSION -srcfolder $MACOS_APP_DIR -ov -format UDZO renode_$VERSION.dmg

#cleanup unless user requests otherwise
if $REMOVE_WORKDIR
then
  rm -rf $MACOS_APP_DIR
fi
