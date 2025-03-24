#!/usr/bin/env bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

DIR=renode_$VERSION
ZIP=$DIR.zip
MSI=$DIR.msi

OS_NAME=windows
SED_COMMAND="sed -i"
. common_copy_files_package.sh

PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES

### prepare renode-test
cp -r $BASE/renode-test.bat $DIR/bin/renode-test.bat
sed -i 's/CONTEXT=source/CONTEXT=package/' $DIR/bin/renode-test.bat

mkdir -p $OUTPUT

MSBuild.exe -t:Clean,Build windows/RenodeSetup/SetupProject.wixproj -p:version=${VERSION%\+*} -p:installer_name=$DIR

### create windows package
# Absolute path to use the Windows builtin BSD tar instead of minGW tar
/c/Windows/SysWOW64/tar.exe -a -c -f $ZIP $DIR
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi

mv $ZIP $OUTPUT
mv windows/RenodeSetup/bin/Release/$MSI $OUTPUT

echo "Created a Windows package in $PACKAGES/$ZIP"
echo "Created a Windows installer in $PACKAGES/$MSI"
