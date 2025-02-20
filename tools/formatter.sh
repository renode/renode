#!/usr/bin/env bash

RENODE_ROOT_PATH="$( cd -- "$( dirname -- "$( dirname -- "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd -P )"

function print_help() {
  echo "Usage: $0 [action] <files> [-h] [-r report-file.json]"
  echo
  echo "Actions"
  echo "format                            format files"
  echo "lint                              lint files"
  echo
  echo "Arguments"
  echo "<files>                           space separated list of files to format / lint,. If empty, all files will be included"
  echo
  echo "Options"
  echo "-h                                show this message"
  echo "-r                                generate report and save it to report-file.json"
}

function renode_format() {
  unset ACTION
  unset REPORT_FILE
  unset FILES
  unset COMMAND

  # Check if command is valid
  if [ -z ${1+x} ]
  then
    echo "Missing command"
    print_help
    return 1
  fi
  if [[ "$1" != "format" && "$1" != "lint" ]]
  then
    echo "Unrecognized command"
    print_help
    return 1
  fi
  ACTION=$1
  shift

  # Set files to format
  while [[ ! -z ${1+x} && $1 !=  -* ]]
  do
    FILES="${FILES+} $1"
    shift
  done

  # Parse options
  while getopts "hr:" opt
  do
    case $opt in
      h)
        print_help
        ;;
      r)
        REPORT_FILE="$OPTARG"
        ;;
    esac
  done

  # We don't want to format external libs, dotnet fromat expects relative paths
  LIB_RELATIVE_PATH="$(realpath -s --relative-to=$(pwd -P) "$RENODE_ROOT_PATH/lib")"

  COMMAND="dotnet format $RENODE_ROOT_PATH/Renode_NET.sln --exclude $LIB_RELATIVE_PATH"

  if [[ "$ACTION" == "lint" ]]
  then
    COMMAND="$COMMAND --verify-no-changes"
  fi

  if [[ ! -z ${REPORT_FILE+x} ]]
  then
    COMMAND="$COMMAND --report $REPORT_FILE"
  fi

  if [[ ! -z ${FILES+x} ]]
  then
    COMMAND="$COMMAND --include $FILES"
  fi

  return $(eval "$COMMAND")
}

# Execute formatting command only if file is not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]
then
    renode_format $@
fi

