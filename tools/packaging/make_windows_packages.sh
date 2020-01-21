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
ZIP=$DIR.zip
MSI=$DIR.msi

SED_COMMAND="sed -i"
. common_copy_files.sh

PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES

### copy licenses
cp windows/mingw-license $DIR/licenses
cp windows/winpthreads-license $DIR/licenses

mkdir -p $OUTPUT

MSBuild.exe /t:Clean,Build windows/RenodeSetup/SetupProject.wixproj /p:version=${VERSION%\+*} /p:installer_name=$DIR

### create windows package
if $REMOVE_WORKDIR
then
    zip -qrm $ZIP $DIR/
else
    zip -qr $ZIP $DIR/
fi

mv $ZIP $OUTPUT
mv windows/RenodeSetup/bin/Release/$MSI $OUTPUT

echo "Created a Windows package in $PACKAGES/$ZIP"
echo "Created a Windows installer in $PACKAGES/$MSI"
