#!/bin/bash

set -e
set -u

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

RPM_MIN_DIST="f23"

if ! is_dep_available gem
then
    exit
fi

export PATH=`gem environment gemdir`/bin:$PATH

#expand this list if needed. bsdtar is required for arch packages.
if ! is_dep_available fpm ||\
    ! is_dep_available rpm ||\
    ! is_dep_available bsdtar
then
    exit
fi

DIR=renode_$VERSION

. common_copy_files.sh

PACKAGES=output/renode_packages/$TARGET
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
    $DIR/=/opt/renode\
    linux/renode.sh=/usr/bin/renode\
    linux/Renode.desktop=/usr/share/applications/Renode.desktop\
    linux/icons/=/usr/share/icons/hicolor
    )

### create debian package
fpm -s dir -t deb\
    -d "mono-complete >= $MONOVERSION" -d gtk-sharp2 -d screen -d gksu\
    --deb-no-default-config-files\
    "${GENERAL_FLAGS[@]}" >/dev/null

mkdir -p $OUTPUT/deb
deb=renode*deb
echo -n "Created a Debian package in $PACKAGES/deb/"
echo $deb
mv $deb $OUTPUT/deb

### create rpm package
fpm -s dir -t rpm\
    -d "mono-complete >= $MONOVERSION" -d gtk-sharp2 -d screen -d beesu\
    --rpm-dist $RPM_MIN_DIST\
    --rpm-auto-add-directories\
    "${GENERAL_FLAGS[@]}" >/dev/null

mkdir -p $OUTPUT/rpm
rpm=renode*rpm
echo -n "Created a Fedora package in $PACKAGES/rpm/"
echo $rpm
mv $rpm $OUTPUT/rpm

### create arch package
fpm -s dir -t pacman\
    -d mono -d gtk-sharp-2 -d screen -d gksu\
    "${GENERAL_FLAGS[@]}" >/dev/null

mkdir -p $OUTPUT/arch
arch=renode*.pkg.tar.xz
echo -n "Created an Arch package in $PACKAGES/arch/"
echo $arch
mv $arch $OUTPUT/arch

#cleanup unless user requests otherwise
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
