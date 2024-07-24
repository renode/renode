#!/usr/bin/env bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

if ! is_dep_available gem
then
    exit 1
fi

export PATH=`gem environment gemdir`/bin:$PATH

#expand this list if needed. bsdtar is required for arch packages.
if ! is_dep_available fpm ||\
    ! is_dep_available rpm ||\
    ! is_dep_available bsdtar
then
    exit 1
fi

DIR=renode_$VERSION
INSTALL_DIR=/opt/renode

OS_NAME=linux
SED_COMMAND="sed -i"
. common_copy_files_package.sh

PYTHONVERSION=3.8

COMMON_SCRIPT=$DIR/tests/common.sh
TEST_SCRIPT=linux/renode-test
RUNNER=mono
copy_bash_tests_scripts $TEST_SCRIPT $COMMON_SCRIPT $RUNNER

COMMAND_SCRIPT=linux/renode
echo "#!/bin/sh" > $COMMAND_SCRIPT
echo "MONOVERSION=$MONOVERSION" >> $COMMAND_SCRIPT
echo "REQUIRED_MAJOR=$MONO_MAJOR" >> $COMMAND_SCRIPT
echo "REQUIRED_MINOR=$MONO_MINOR" >> $COMMAND_SCRIPT
# skip the first line (with the hashbang)
tail -n +2 linux/renode-mono-template >> $COMMAND_SCRIPT
chmod +x $COMMAND_SCRIPT

PACKAGES=output/packages
OUTPUT=$BASE/$PACKAGES

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

### create debian package
fpm -s dir -t deb\
    -d "libmono-cil-dev >= $MONOVERSION"\
    -d "mono-runtime >= $MONOVERSION"\
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
    "${GENERAL_FLAGS[@]}" >/dev/null

mkdir -p $OUTPUT
deb=(renode*deb)
mv $deb $OUTPUT
echo "Created a Debian package in $PACKAGES/$deb"
### create rpm package
#redhat-rpm-config is apparently required for GCC to work in Docker images
fpm -s dir -t rpm\
     -d "mono-core >= $MONOVERSION"\
     -d python3-pip\
     -d gcc\
     -d redhat-rpm-config\
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
# Rationale:
# As a result of the following commit:
# https://github.com/jordansissel/fpm/commit/ca3477b67ba6bc9adc1cbe97e560061a739a12fc
# packages generated with `--pacman-compression xz` have an invalid extension: `.zst`
# instead of `.xz`. Versions from 1.12.0 to 1.14.1 (at the moment of writing this)
# are affected.
#
# This is a workaround - if the user will generate packages with an
# older fpm (<1.12.0), the file will remain unchanged. If an affected version of fpm
# will be used - it will be renamed to have the expected file extension.
ZST=(renode*.pkg.tar.zst)
if [ -f "$arch" ]
then
    mv $arch $OUTPUT
    echo "Created an Arch package in $PACKAGES/$arch"
elif [ -f "$ZST" ]
then
    file $ZST | grep "XZ compressed data" >> /dev/null
    if [ $? -eq 0 ]
    then
        mv "$ZST" "${ZST%.zst}.xz"
        arch=(renode*.pkg.tar.xz)
        mv $arch $OUTPUT
        echo "Warning: .zst file was detected during the process and was renamed to .xz manually. \
Please upgrade fpm above version 1.14.1, if possible."
        echo "Created an Arch package in $PACKAGES/$arch"
    else
        echo "Could not create Arch package"
    fi
fi
#cleanup unless user requests otherwise
if $REMOVE_WORKDIR
then
    rm -rf $DIR
    rm $COMMAND_SCRIPT
    rm $TEST_SCRIPT
fi
