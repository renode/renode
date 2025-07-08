MONOVERSION=`cat ../mono_version`
MONO_MAJOR=`echo $MONOVERSION | cut -d'.' -f1`
MONO_MINOR=`echo $MONOVERSION | cut -d'.' -f2`
DOTNET_VERSION="8.0"
TARGET="Release"
BASE=../..
REMOVE_WORKDIR=true
DATE=""
COMMIT=""

function help {
    echo "$0 [-d] [-n] [-l]"
    echo
    echo -e "-d\tuse Debug configuration"
    echo -e "-n\tcreate a nightly build with date and commit SHA"
    echo -e "-l\tdo not remove workdir after building"
}

function is_dep_available {
    if ! command -v $1 >/dev/null 2>&1
    then
        echo "$1 is missing. Install it to continue."
        return 1
    fi
    return 0
}

while getopts ":dnl" opt
do
    case $opt in
        d)
            TARGET="Debug"
            ;;
        n)
            DATE="+`date +%Y%m%d`"
            COMMIT="git`git rev-parse --short=9 HEAD`"
            ;;
        l)
            REMOVE_WORKDIR=false
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            help
            exit 1
            ;;
    esac
done

VERSION=`cat ../version`
VERSION="$VERSION$DATE$COMMIT"
