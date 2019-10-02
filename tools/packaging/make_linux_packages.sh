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
INSTALL_DIR=/opt/renode

SED_COMMAND="sed -i"
. common_copy_files.sh

cp -r $BASE/tests/{robot_tests_provider,run_tests,tests_engine}.py $DIR/tests
cp -r $BASE/test.sh $DIR/tests
cp -r $BASE/tools/common.sh $DIR/tests
cp -r $BASE/tests/platforms $DIR/tests/platforms
sed -i '/nunit/d' $DIR/tests/run_tests.py
sed -i 's#tools/##' $DIR/tests/test.sh
sed -i 's#tests/run_tests.py#run_tests.py#' $DIR/tests/test.sh
sed -i 's#--properties-file.*#--robot-framework-remote-server-full-directory='$INSTALL_DIR'/bin --css-file='$INSTALL_DIR'/tests/robot.css -r . "$@"#' $DIR/tests/test.sh
sed -i 's#^ROOT_PATH=".*#ROOT_PATH="'$INSTALL_DIR'/tests"#g' $DIR/tests/test.sh
sed -i '/TESTS_FILE/d' $DIR/tests/test.sh
sed -i '/TESTS_RESULTS/d' $DIR/tests/test.sh
sed -i 's#os\.path\.join(this_path, "\.\./src/Renode/RobotFrameworkEngine/renode-keywords\.robot")#os.path.join(this_path,"renode-keywords.robot")#g' $DIR/tests/robot_tests_provider.py

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
    $DIR/=$INSTALL_DIR\
    $DIR/tests/test.sh=/usr/bin/renode-test\
    linux/renode.sh=/usr/bin/renode\
    linux/Renode.desktop=/usr/share/applications/Renode.desktop\
    linux/icons/=/usr/share/icons/hicolor
    )

### create debian package
fpm -s dir -t deb\
    -d "mono-complete >= $MONOVERSION" -d gtk-sharp2 -d screen -d policykit-1 -d libc6-dev\
    --deb-no-default-config-files\
    "${GENERAL_FLAGS[@]}" >/dev/null

mkdir -p $OUTPUT
deb=(renode*deb)
mv $deb $OUTPUT
echo "Created a Debian package in $PACKAGES/$deb"
### create rpm package
fpm -s dir -t rpm\
    -d "mono-complete >= $MONOVERSION" -d gtk-sharp2 -d screen -d beesu\
    --rpm-dist $RPM_MIN_DIST\
    --rpm-auto-add-directories\
    "${GENERAL_FLAGS[@]}" >/dev/null

rpm=(renode*rpm)
mv $rpm $OUTPUT
echo "Created a Fedora package in $PACKAGES/$rpm"
### create arch package
fpm -s dir -t pacman\
    -d mono -d gtk-sharp-2 -d screen -d polkit\
    "${GENERAL_FLAGS[@]}" >/dev/null

arch=(renode*.pkg.tar.xz)
mv $arch $OUTPUT
echo "Created an Arch package in $PACKAGES/$arch"
#cleanup unless user requests otherwise
if $REMOVE_WORKDIR
then
    rm -rf $DIR
fi
