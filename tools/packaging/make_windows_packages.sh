#!/bin/bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

if ! is_dep_available zip
then
    exit
fi

if [ -z "${MINGW_PATH:-}" ]
then
    MINGW_PATH="C:/MinGW64/mingw64/bin"
    echo "MINGW_PATH is not set, using default path ($MINGW_PATH)"
fi

DIR=renode_$VERSION

. common_copy_files.sh

PACKAGES=output/renode_packages/$TARGET
OUTPUT=$BASE/$PACKAGES

### copy windows dependencies
cp "$MINGW_PATH"/libgcc_s_seh-1.dll $DIR/bin
cp windows/mingw-license $DIR/licenses

### create windows package
if $REMOVE_WORKDIR
then
    zip -qrm $DIR.zip $DIR/
else
    zip -qr $DIR.zip $DIR/
fi

mkdir -p $OUTPUT/windows
mv $DIR.zip $OUTPUT/windows

echo "Created a Windows package in $PACKAGES/windows/$DIR.zip"
