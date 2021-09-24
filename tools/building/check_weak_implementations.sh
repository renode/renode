#!/bin/bash
set -u
set -e

function first()
{
  echo $1
}

function next()
{
  shift
  echo $*
}

pushd ../../src/Infrastructure/src/Emulator/Cores/ > /dev/null

WEAKS=weaks.tmp
IMPLEMENTATIONS=implementations.tmp
CALLBACKS_BIN=callbacks.tmp
PATHS_TO_BIN="renode/renode_callbacks.c renode/renode_memory.c"

ARCHS="arm ppc sparc"
PATHS_WEAK="tlib/callbacks.c tlib/arch/arm/arch_callbacks.c tlib/arch/ppc/arch_callbacks.c tlib/arch/sparc/arch_callbacks.c"
PATHS_IMPLEMENTATION="$CALLBACKS_BIN renode/arch/arm/renode_arm_callbacks.c renode/arch/ppc/renode_ppc_callbacks.c renode/arch/sparc/renode_sparc_callbacks.c"

RESULT=0

for PATH_TO_BIN in $PATHS_TO_BIN
do
    cat $PATH_TO_BIN >> $CALLBACKS_BIN
done

for PATH_WEAK in $PATHS_WEAK
do
  PATH_IMPLEMENTATION=`first $PATHS_IMPLEMENTATION`
  PATHS_IMPLEMENTATION=`next $PATHS_IMPLEMENTATION`
  ${CC:-gcc} -I tlib/include -E $PATH_WEAK | grep weak | grep -o tlib[_A-Za-z]* | sort | uniq > $WEAKS
  cat $PATH_IMPLEMENTATION | grep -o tlib[_A-Za-z]* | sort | uniq > $IMPLEMENTATIONS
  if grep -vwF -f $IMPLEMENTATIONS $WEAKS
  then
    echo $PATH_WEAK
    echo "-----------------------"
    RESULT=1
  fi
done

rm $WEAKS
rm $IMPLEMENTATIONS
rm $CALLBACKS_BIN

popd > /dev/null

exit $RESULT
