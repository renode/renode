#!/bin/bash

set -u
set -e

UPDATE_SUBMODULES=false

export ROOT_PATH="`dirname \"\`realpath "$0"\`\"`"
OUTPUT_DIRECTORY="$ROOT_PATH/output"

CONFIGURATION="Release"
CLEAN=false
PACKAGES=false
NIGHTLY=false
PARAMS=()
CUSTOM_PROP=

while getopts "cdvpnsb:" opt
do
  case $opt in
    c)
      CLEAN=true
      ;;
    d)
      CONFIGURATION="Debug"
      ;;
    v)
      PARAMS+=(/verbosity:detailed)
      ;;
    p)
      PACKAGES=true
      ;;
    n)
      NIGHTLY=true
      PACKAGES=true
      ;;
    s)
      UPDATE_SUBMODULES=true
      ;;
    b)
      CUSTOM_PROP=$OPTARG
      ;;
    \?)
      echo "Usage: $0 [-cdvspn] [-b properties-file.csproj]"
      echo ""
      echo "-c           clean instead of building"
      echo "-d           build Debug configuration"
      echo "-v           verbose output"
      echo "-p           create packages after building"
      echo "-n           create nightly packages after building"
      echo "-s           update submodules"
      echo "-b           custom build properties file"
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))"

# Update submodules if not initialized or if requested by the user
# Warn if not updating, but unclean
# Disabling -e to allow grep to fail
set +e
git submodule status --recursive | grep -q "^-"
SUBMODULES_NOT_INITED=$?

git submodule status --recursive | grep -q "^+"
SUBMODULES_NOT_CLEAN=$?
set -e

if $UPDATE_SUBMODULES || [ $SUBMODULES_NOT_INITED -eq 0 ]
then
    echo "Updating submodules..."
    git submodule update --init --recursive
elif [ $SUBMODULES_NOT_CLEAN -eq 0 ]
then
    echo "Submodules are not updated. Use -s to force update."
fi

. "${ROOT_PATH}/tools/common.sh"

"${ROOT_PATH}"/tools/building/fetch_libraries.sh

if $ON_WINDOWS
then
    TARGET="`get_path \"$PWD/Renode-Windows.sln\"`"
else
    TARGET="`get_path \"$PWD/Renode.sln\"`"
fi

# Update references to Xwt
TERMSHARP_PROJECT="${CURRENT_PATH:=.}/lib/termsharp/TermSharp.csproj"
if [ -e "$TERMSHARP_PROJECT" ]
then
    sed -i.bak 's/"xwt\\Xwt\\Xwt.csproj"/"..\\xwt\\Xwt\\Xwt.csproj"/' "$TERMSHARP_PROJECT"
    rm "$TERMSHARP_PROJECT.bak"
fi

# Verify Mono and mcs version on Linux and macOS
if ! $ON_WINDOWS
then
    MINIMUM_MONO=`cat tools/mono_version`

    if ! [ -x "$(command -v $LAUNCHER)" ]
    then
        echo "$LAUNCHER not found. Renode requires Mono $MINIMUM_MONO or newer. Please refer to documentation for installation instructions. Exiting!"
        exit 1
    fi

    if ! [ -x "$(command -v mcs)" ]
    then
        echo "mcs not found. Renode requries Mono $MINIMUM_MONO or newer. Please refer to documentation for installation instructions. Exiting!"
        exit 1
    fi

    # Check mono version
    MINIMUM_MONO_MAJOR=`echo $MINIMUM_MONO | cut -d'.' -f1`
    MINIMUM_MONO_MINOR=`echo $MINIMUM_MONO | cut -d'.' -f2`

    INSTALLED_MONO=`$LAUNCHER --version | head -n1 | cut -d' ' -f5`
    INSTALLED_MONO_MAJOR=`echo $INSTALLED_MONO | cut -d'.' -f1`
    INSTALLED_MONO_MINOR=`echo $INSTALLED_MONO | cut -d'.' -f2`

    if (( $INSTALLED_MONO_MAJOR < $MINIMUM_MONO_MAJOR || (($INSTALLED_MONO_MAJOR == $MINIMUM_MONO_MAJOR) && ($INSTALLED_MONO_MINOR < $MINIMUM_MONO_MINOR)) ))
    then
        echo "Wrong Mono version detected: $INSTALLED_MONO. Renode requires Mono $MINIMUM_MONO or newer. Please refer to documentation for installation instructions. Exiting!"
        exit 1
    fi
fi

# Copy properties file according to the running OS
mkdir -p "$OUTPUT_DIRECTORY"
if [ -n "${CUSTOM_PROP}" ]; then
    PROP_FILE=$CUSTOM_PROP
else
    if $ON_OSX
    then
      PROP_FILE="$CURRENT_PATH/src/Infrastructure/src/Emulator/Cores/osx-properties.csproj"
    elif $ON_LINUX
    then
      PROP_FILE="$CURRENT_PATH/src/Infrastructure/src/Emulator/Cores/linux-properties.csproj"
    else
      PROP_FILE="$CURRENT_PATH/src/Infrastructure/src/Emulator/Cores/windows-properties.csproj"
    fi
fi
cp "$PROP_FILE" "$OUTPUT_DIRECTORY/properties.csproj"

# Build CCTask in Release configuration
$CS_COMPILER /p:Configuration=Release "`get_path \"$ROOT_PATH/lib/cctask/CCTask.sln\"`" > /dev/null

# clean instead of building
if $CLEAN
then
    PARAMS+=(/t:Clean)
    for conf in Debug Release
    do
        $CS_COMPILER "${PARAMS[@]}" /p:Configuration=$conf "$TARGET"
        rm -fr $OUTPUT_DIRECTORY/bin/$conf
    done
    exit 0
fi

# check weak implementations of core libraries
pushd "$ROOT_PATH/tools/building" > /dev/null
./check_weak_implementations.sh
popd > /dev/null

PARAMS+=(/p:Configuration=$CONFIGURATION /p:GenerateFullPaths=true)

# build
$CS_COMPILER "${PARAMS[@]}" "$TARGET"

# copy llvm library
cp src/Infrastructure/src/Emulator/LLVMDisassembler/bin/$CONFIGURATION/libLLVM.* output/bin/$CONFIGURATION

# build packages after successful compilation
if $PACKAGES
then
    params=""
    if $NIGHTLY
    then
      params="$params -n"
    fi

    if [ $CONFIGURATION == "Debug" ]
    then
        params="$params -d"
    fi

    $ROOT_PATH/tools/packaging/make_${DETECTED_OS}_packages.sh $params

    if $ON_LINUX
    then
      $ROOT_PATH/tools/packaging/make_linux_portable.sh $params
    fi
fi
