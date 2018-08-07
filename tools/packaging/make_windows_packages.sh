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

DIR=renode_$VERSION

SED_COMMAND="sed -i"
. common_copy_files.sh

PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES

### copy windows dependencies
cp "`which libgcc_s_seh-1.dll`" $DIR/bin
cp windows/mingw-license $DIR/licenses

mkdir -p $OUTPUT

MSBuild.exe /t:Clean,Build windows/RenodeSetup/SetupProject.wixproj /p:version=${VERSION%\+*} /p:workdir=$DIR

### create windows package
if $REMOVE_WORKDIR
then
    zip -qrm $DIR.zip $DIR/
else
    zip -qr $DIR.zip $DIR/
fi

mv $DIR.zip $OUTPUT
mv windows/RenodeSetup/bin/Release/RenodeSetup.msi $OUTPUT

echo "Created a Windows package in $PACKAGES/$DIR.zip"
echo "Created a Windows installer in $PACKAGES/RenodeSetup.msi "
