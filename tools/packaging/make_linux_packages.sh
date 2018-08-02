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

SED_COMMAND="sed -i"
. common_copy_files.sh

cp -r $BASE/tests/{robot_tests_provider,run_tests,tests_engine}.py $DIR/tests
cp -r $BASE/test.sh $DIR/tests
cp -r $BASE/tools/common.sh $DIR/tests
sed -i '/nunit/d' $DIR/tests/run_tests.py
sed -i 's#tools/##' $DIR/tests/test.sh
sed -i 's#tests/run_tests.py#run_tests.py#' $DIR/tests/test.sh
sed -i 's#--properties-file.*#--robot-framework-remote-server-full-directory=/opt/renode/bin -r . "$@"#' $DIR/tests/test.sh
sed -i '/ROBOT_LOCATION/d' $DIR/tests/test.sh
sed -i '/TESTS_FILE/d' $DIR/tests/test.sh
sed -i '/TESTS_RESULTS/d' $DIR/tests/test.sh

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
    -d "mono-complete >= $MONOVERSION" -d gtk-sharp2 -d screen -d policykit-1 -d libc6-dev\
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
    -d mono -d gtk-sharp-2 -d screen -d polkit\
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
