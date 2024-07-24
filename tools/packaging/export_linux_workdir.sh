#!/usr/bin/env bash

set -e
set -u

if [ $# -lt 1 ]
then
    echo "Usage: export_linux_workdir.sh OUTPUT_DIRECTORY [PARAMS]"
    exit 1
fi

DIR=$1
shift

#change dir to script location
cd "${0%/*}"
. common_make_packages.sh

OS_NAME=linux
SED_COMMAND="sed -i"
. common_copy_files_package.sh

TEST_SCRIPT=$DIR/renode-test

cp -r $BASE/tools/common.sh $DIR/tests/common.sh
cp -r $BASE/renode-test $TEST_SCRIPT

$SED_COMMAND 's#tools/#tests/#' $TEST_SCRIPT
$SED_COMMAND 's#--properties-file.*#--robot-framework-remote-server-full-directory=${ROOT_PATH}/bin --css-file=${ROOT_PATH}/tests/robot.css -r $(pwd) "$@"#' $TEST_SCRIPT
$SED_COMMAND '/TESTS_FILE/d' $TEST_SCRIPT
$SED_COMMAND '/TESTS_RESULTS/d' $TEST_SCRIPT

COMMAND_SCRIPT=$DIR/renode
echo "#!/bin/sh" > $COMMAND_SCRIPT
echo "MONOVERSION=$MONOVERSION" >> $COMMAND_SCRIPT
echo "REQUIRED_MAJOR=$MONO_MAJOR" >> $COMMAND_SCRIPT
echo "REQUIRED_MINOR=$MONO_MINOR" >> $COMMAND_SCRIPT
# skip the first line (with the hashbang)
tail -n +2 linux/renode-mono-template >> $COMMAND_SCRIPT
$SED_COMMAND "s|/opt/renode|$DIR|" $COMMAND_SCRIPT
chmod +x $COMMAND_SCRIPT

