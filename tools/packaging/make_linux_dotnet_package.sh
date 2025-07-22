#!/usr/bin/env bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

if ! is_dep_available gem
then
    echo "Missing GEM!"
    exit 1
fi

export PATH=`gem environment gemdir`/bin:$PATH

#expand this list if needed. bsdtar is required for arch packages.
if ! is_dep_available fpm ||\
    ! is_dep_available rpm ||\
    ! is_dep_available bsdtar
then
    echo "Missing FPM/RPM/BSDTAR!"
    exit 1
fi

DIR=renode_$VERSION--dotnet

# Contents of this variable should be pasted verbatim into renode-test script.
INSTALL_DIR=/opt/renode
PYTHONVERSION=3.8

OS_NAME=linux
SED_COMMAND="sed -i"
. common_copy_files_package.sh

COMMON_SCRIPT=$DIR/tests/common.sh
COMMAND_SCRIPT=linux/renode
TEST_SCRIPT=linux/renode-test
RUNNER=dotnet
copy_bash_tests_scripts $TEST_SCRIPT $COMMON_SCRIPT $RUNNER


PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES
mkdir -p ${OUTPUT}

GENERAL_FLAGS=(\
    -f -n renode -v $VERSION --license MIT\
    --category devel --provides renode -a native\
    -m 'Antmicro <renode@antmicro.com>'\
    --vendor 'Antmicro <renode@antmicro.com>'\
    --description 'The Renode Framework'\
    --url 'www.renode.io'\
    --after-install linux/update_icon_cache.sh\
    --after-remove linux/update_icon_cache.sh\
    --license MIT\
    $DIR/=$INSTALL_DIR\
    $TEST_SCRIPT=/usr/bin/renode-test\
    $COMMAND_SCRIPT=/usr/bin/renode\
    linux/Renode.desktop=/usr/share/applications/Renode.desktop\
    linux/icons/128x128/apps/renode.png=/usr/share/icons/hicolor/128x128/apps/renode.png
    linux/icons/16x16/apps/renode.png=/usr/share/icons/hicolor/16x16/apps/renode.png
    linux/icons/24x24/apps/renode.png=/usr/share/icons/hicolor/24x24/apps/renode.png
    linux/icons/32x32/apps/renode.png=/usr/share/icons/hicolor/32x32/apps/renode.png
    linux/icons/48x48/apps/renode.png=/usr/share/icons/hicolor/48x48/apps/renode.png
    linux/icons/64x64/apps/renode.png=/usr/share/icons/hicolor/64x64/apps/renode.png
    linux/icons/scalable/apps/renode.svg=/usr/share/icons/hicolor/scalable/apps/renode.svg
    )

cp $BASE/output/bin/$TARGET/libllvm-disas.so $BASE/output/bin/$TARGET/publish

# Override the TARGET variable.
# It is used to copy files into final package directory and all required files were moved there.
TARGET="$TARGET/publish"

# Remove RenodeTests because they are unused in the package
rm -rf $DIR/tests/unit-tests/RenodeTests

cp -r $BASE/output/bin/$TARGET/runtimes $DIR/bin
cp $BASE/output/bin/$TARGET/Renode.runtimeconfig.json $DIR/bin
cp $BASE/output/bin/$TARGET/Renode.deps.json $DIR/bin
cp $BASE/output/bin/$TARGET/*.so $DIR/bin

# Copy Lib directory which contains dependecies for IronPython
cp -r $BASE/output/bin/$TARGET/Lib $DIR/bin

COMMAND_SCRIPT=linux/renode
cat linux/renode-dotnet-template | head -n 10 > $COMMAND_SCRIPT
echo '$LAUNCHER /opt/renode/bin/Renode.dll "$@"' >> $COMMAND_SCRIPT
chmod +x $COMMAND_SCRIPT

### create debian package
fpm -s dir -t deb\
    -d "dotnet-runtime-8.0 >= $DOTNET_VERSION"\
    -d "python3 >= $PYTHONVERSION"\
    -d python3-pip\
    -d gtk-sharp2-gapi\
    -d libglade2.0-cil-dev\
    -d libglib2.0-cil-dev\
    -d libgtk2.0-cil-dev\
    -d screen\
    -d policykit-1\
    -d libc6-dev\
    -d gcc\
    --deb-no-default-config-files\
    "${GENERAL_FLAGS[@]}" 

deb=(renode*deb)
mv $deb $OUTPUT
echo "Created a Debian package in $PACKAGES/$deb"

### create rpm package
fpm -s dir -t rpm\
     -d "dotnet-runtime-8.0 >= $DOTNET_VERSION"\
     -d python3-pip\
     -d gcc\
     -d gtk-sharp2\
     -d screen\
     -d polkit\
     "${GENERAL_FLAGS[@]}" >/dev/null

rpm=(renode*rpm)
mv $rpm $OUTPUT
echo "Created a Fedora package in $PACKAGES/$rpm"
### create arch package
fpm -s dir -t pacman --pacman-compression xz \
    -d mono -d gtk-sharp-2 -d screen -d polkit -d gcc -d python3 -d python-pip \
    "${GENERAL_FLAGS[@]}" >/dev/null

arch=(renode*.pkg.tar.xz)
mv $arch $OUTPUT
echo "Created an Arch package in $PACKAGES/$arch"

### create portable package
PKG=renode-$VERSION.linux-dotnet.tar.gz

# Create tar
# Requires a separate scripts because we don't know it's location
INSTALL_DIR='$(cd $(dirname $(readlink -f $0 2>/dev/null || echo $0)); echo $PWD)'
rm ${COMMAND_SCRIPT}
cp linux/renode-dotnet-template $COMMAND_SCRIPT
copy_bash_tests_scripts $TEST_SCRIPT $COMMON_SCRIPT $RUNNER
mkdir -p $BASE/output/packages
cp $COMMAND_SCRIPT $DIR
cp $TEST_SCRIPT $DIR
tar -czf $BASE/output/packages/$PKG $DIR

echo "Created a dotnet package in output/packages/$PKG"

# Cleanup
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
