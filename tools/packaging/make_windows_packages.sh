#!/usr/bin/env bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

if ! is_dep_available zip
then
    exit 1
fi

DIR=renode_$VERSION
ZIP=$DIR.zip
MSI=$DIR.msi

OS_NAME=windows
SED_COMMAND="sed -i"
. common_copy_files_package.sh

PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES

# Set up test wrappers that allow for running in CMD
cp -r $BASE/tests/test.bat $DIR/tests/test.bat
cat >> $DIR/bin/renode-test.bat << EOL
@echo off
set test_script=%~dp0%..\tests\test.bat
call "%test_script%" %*
EOL

mkdir -p $OUTPUT

MSBuild.exe -t:Clean,Build windows/RenodeSetup/SetupProject.wixproj -p:version=${VERSION%\+*} -p:installer_name=$DIR

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
