#!/usr/bin/env bash

set -u
set -e

export ROOT_PATH="$(cd $(dirname $0); echo $PWD)"
OUTPUT_DIRECTORY="$ROOT_PATH/output"
EXPORT_DIRECTORY=""

UPDATE_SUBMODULES=false
CONFIGURATION="Release"
BUILD_PLATFORM="Any CPU"
CLEAN=false
PACKAGES=false
NIGHTLY=false
PORTABLE=false
HEADLESS=false
SKIP_FETCH=false
TLIB_ONLY=false
TLIB_EXPORT_COMPILE_COMMANDS=false
TLIB_ARCH=""
NET=false
TFM="net8.0"
GENERATE_DOTNET_BUILD_TARGET=true
PARAMS=()
CUSTOM_PROP=
NET_FRAMEWORK_VER=
RID="linux-x64"
HOST_ARCH="i386"
# Common cmake flags
CMAKE_COMMON=""

function print_help() {
  echo "Usage: $0 [-cdvspnt] [-b properties-file.csproj] [--no-gui] [--skip-fetch] [--profile-build] [--tlib-only] [--tlib-export-compile-commands] [--tlib-arch <arch>] [--host-arch i386|aarch64] [-- <ARGS>]"
  echo
  echo "-c                                clean instead of building"
  echo "-d                                build Debug configuration"
  echo "-v                                verbose output"
  echo "-p                                create packages after building"
  echo "-n                                create nightly packages after building"
  echo "-t                                create a portable package (experimental, Linux only)"
  echo "-s                                update submodules"
  echo "-b                                custom build properties file"
  echo "-o                                custom output directory"
  echo "--skip-fetch                      skip fetching submodules and additional resources"
  echo "--no-gui                          build with GUI disabled"
  echo "--force-net-framework-version     build against different version of .NET Framework than specified in the solution"
  echo "--net                             build with dotnet"
  echo "-B                                bundle target runtime (default value: $RID, requires --net, -t)"
  echo "-F                                select the target framework for which Renode should be built (default value: $TFM)"
  echo "--profile-build                   build optimized for profiling"
  echo "--tlib-only                       only build tlib"
  echo "--tlib-arch                       build only single arch (implies --tlib-only)"
  echo "--tlib-export-compile-commands    build tlibs with 'compile_commands.json' (requires --tlib-arch)"
  echo "--host-arch                       build with a specific tcg host architecture (default: i386)"
  echo "--skip-dotnet-target-generation   don't generate 'Directory.Build.targets' file, useful when experimenting with different build settings"
  echo "<ARGS>                            arguments to pass to the build system"
}

while getopts "cdvpnstb:o:B:F:a:-:" opt
do
  case $opt in
    c)
      CLEAN=true
      ;;
    d)
      CONFIGURATION="Debug"
      ;;
    v)
      PARAMS+=(verbosity:detailed)
      ;;
    p)
      PACKAGES=true
      ;;
    n)
      NIGHTLY=true
      PACKAGES=true
      ;;
    t)
      PORTABLE=true
      ;;
    s)
      UPDATE_SUBMODULES=true
      ;;
    b)
      CUSTOM_PROP=$OPTARG
      ;;
    o)
      EXPORT_DIRECTORY=$OPTARG
      echo "Setting the output directory to $EXPORT_DIRECTORY"
      ;;
    B)
      RID=$OPTARG
      ;;
    F)
      if ! $NET; then
        echo "-F requires --net being set"
        exit 1
      fi
      TFM=$OPTARG
      ;;
    -)
      case $OPTARG in
        "no-gui")
          HEADLESS=true
          ;;
        "skip-fetch")
          SKIP_FETCH=true
          ;;
        "force-net-framework-version")
          shift $((OPTIND-1))
          NET_FRAMEWORK_VER=p:TargetFrameworkVersion=v$1
          PARAMS+=($NET_FRAMEWORK_VER)
          OPTIND=2
          ;;
        "net")
          NET=true
          PARAMS+=(p:NET=true)
          ;;
        "profile-build")
          CMAKE_COMMON="-DPROFILING_BUILD=ON"
          ;;
        "tlib-only")
          TLIB_ONLY=true
          ;;
        "tlib-arch")
          # This only makes sense with '--tlib-only' set; it might as well imply it
          TLIB_ONLY=true
          shift $((OPTIND-1))
          TLIB_ARCH=$1
          OPTIND=2
          ;;
        "tlib-export-compile-commands")
          if [ -z $TLIB_ARCH ]; then
              echo "--tlib-export-compile-commands requires --tlib-arch begin set"
              exit 1
          fi
          TLIB_EXPORT_COMPILE_COMMANDS=true
          ;;
        "host-arch")
          shift $((OPTIND-1))
          HOST_ARCH=$1
          OPTIND=2
          ;;
        "skip-dotnet-target-generation")
          GENERATE_DOTNET_BUILD_TARGET=false
          ;;
        *)
          print_help
          exit 1
          ;;
      esac
      ;;
    \?)
      print_help
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))"
PARAMS+=(
  # By default use CC as Compiler- and LinkerPath, and AR as ArPath
  ${CC:+"p:CompilerPath=$CC"}
  ${CC:+"p:LinkerPath=$CC"}
  ${AR:+"p:ArPath=$AR"}
  # But allow users to override it
  "$@"
)

if [ -n "${PLATFORM:-}" ]
then
    echo "PLATFORM environment variable is currently set to: >>$PLATFORM<<"
    echo "This might cause problems during the build."
    echo "Please clear it with:"
    echo ""
    echo "    unset PLATFORM"
    echo ""
    echo " and run the build script again."

    exit 1
fi

# We can only update parts of this repository if Renode is built from within the git tree
if [ ! -e .git ]
then
  SKIP_FETCH=true
  UPDATE_SUBMODULES=false
fi

if $SKIP_FETCH
then
  echo "Skipping init/update of submodules"
else
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
fi

. "${ROOT_PATH}/tools/common.sh"

if $SKIP_FETCH
then
  echo "Skipping library fetch"
else
  "${ROOT_PATH}"/tools/building/fetch_libraries.sh
fi

if $HEADLESS
then
    BUILD_TARGET=Headless
    PARAMS+=(p:GUI_DISABLED=true)
elif $ON_WINDOWS
then
    BUILD_TARGET=Windows
    TFM="$TFM-windows10.0.17763.0"
    RID="win-x64"
else
    BUILD_TARGET=Mono
fi

if [[ $GENERATE_DOTNET_BUILD_TARGET = true ]]; then
  if $ON_WINDOWS; then
    # CsWinRTAotOptimizerEnabled is disabled due to a bug in dotnet-sdk.
    # See: https://github.com/dotnet/sdk/issues/44026
    OS_SPECIFIC_TARGET_OPTS='<CsWinRTAotOptimizerEnabled>false</CsWinRTAotOptimizerEnabled>'
  fi

cat <<EOF > "$(get_path "$PWD/Directory.Build.targets")"
<Project>
  <PropertyGroup>
    <TargetFrameworks>$TFM</TargetFrameworks>
    ${OS_SPECIFIC_TARGET_OPTS:+${OS_SPECIFIC_TARGET_OPTS}}
  </PropertyGroup>
</Project>
EOF

fi

if $NET
then
  export DOTNET_CLI_TELEMETRY_OPTOUT=1
  CS_COMPILER="dotnet build"
  TARGET="`get_path \"$PWD/Renode_NET.sln\"`"
  BUILD_TYPE="dotnet"
else
  TARGET="`get_path \"$PWD/Renode.sln\"`"
  BUILD_TYPE="mono"
fi

OUT_BIN_DIR="$(get_path "output/bin/${CONFIGURATION}")"
BUILD_TYPE_FILE=$(get_path "${OUT_BIN_DIR}/build_type")

# Verify Mono and mcs version on Linux and macOS
if ! $ON_WINDOWS && ! $NET
then
    if ! [ -x "$(command -v mcs)" ]
    then
        MINIMUM_MONO=`get_min_mono_version`
        echo "mcs not found. Renode requires Mono $MINIMUM_MONO or newer. Please refer to documentation for installation instructions. Exiting!"
        exit 1
    fi

    verify_mono_version
fi

# Copy properties file according to the running OS
mkdir -p "$OUTPUT_DIRECTORY"
if [ -n "${CUSTOM_PROP}" ]; then
    PROP_FILE=$CUSTOM_PROP
else
    if $ON_OSX
    then
      PROP_FILE="${CURRENT_PATH:=.}/src/Infrastructure/src/Emulator/Cores/osx-properties.csproj"
    elif $ON_LINUX
    then
      PROP_FILE="${CURRENT_PATH:=.}/src/Infrastructure/src/Emulator/Cores/linux-properties.csproj"
    else
      PROP_FILE="${CURRENT_PATH:=.}/src/Infrastructure/src/Emulator/Cores/windows-properties.csproj"
    fi
fi
cp "$PROP_FILE" "$OUTPUT_DIRECTORY/properties.csproj"

if ! $NET
then
  # Assets files are not deleted during `dotnet clean`, as it would confuse intellisense per comment in https://github.com/NuGet/Home/issues/7368#issuecomment-457411014,
  # but we need to delete them to build Renode again for .NETFramework since `project.assets.json` doesn't play well if project files share the same directory.
  # If `Renode_NET.sln` is picked for OmniSharp, it will trigger reanalysis of the project after removing assets files.
  # We don't remove these files as part of `clean` target, because other intermediate files are well separated between .NET and .NETFramework
  # and enforcing `clean` every time before rebuilding would slow down the build process on both frameworks.
  find $ROOT_PATH -type f -name 'project.assets.json' -delete
fi

CORES_PATH="$ROOT_PATH/src/Infrastructure/src/Emulator/Cores"

# clean instead of building
if $CLEAN
then
    for project_dir in $(find "$(get_path "${ROOT_PATH}/src")" -iname '*.csproj' -exec dirname '{}' \;)
    do
      for dir in {bin,obj}/{Debug,Release}
      do
        output_dir="$(get_path "${project_dir}/${dir}")"
        if [[ -d "${output_dir}" ]]
        then
          echo "Removing: ${output_dir}"
          rm -rf "${output_dir}"
        fi
      done
    done

    # Manually clean the main output directory as it's location is non-standard
    main_output_dir="$(get_path "${OUTPUT_DIRECTORY}/bin")"
    if [[ -d "${main_output_dir}" ]]
    then
      echo "Removing: ${main_output_dir}"
      rm -rf "${main_output_dir}"
    fi
    exit 0
fi

# Check if a full rebuild is needed
if [[ -f "$BUILD_TYPE_FILE" ]]
then
  if [[ "$(cat "$BUILD_TYPE_FILE")" != "$BUILD_TYPE" ]]
  then
    echo "Attempted to build Renode in a different configuration than the previous build"
    echo "Please run '$0 -c' to clean the previous build before continuing"
    exit 1
  fi
fi

# check weak implementations of core libraries
pushd "$ROOT_PATH/tools/building" > /dev/null
./check_weak_implementations.sh
popd > /dev/null

PARAMS+=(p:Configuration=${CONFIGURATION}${BUILD_TARGET} p:GenerateFullPaths=true p:Platform="\"$BUILD_PLATFORM\"")

# Paths for tlib
CORES_BUILD_PATH="$CORES_PATH/obj/$CONFIGURATION"
CORES_BIN_PATH="$CORES_PATH/bin/$CONFIGURATION"

# Cmake generator, handled in their own variable since the names contain spaces
if $ON_WINDOWS
then
    CMAKE_GEN="-GMinGW Makefiles"
else
    CMAKE_GEN="-GUnix Makefiles"
fi

# Macos architecture flags, to make rosetta work properly
if $ON_OSX
then
  CMAKE_COMMON+=" -DCMAKE_OSX_ARCHITECTURES=x86_64"
  if [ $HOST_ARCH == "aarch64" ]; then
    CMAKE_COMMON+=" -DCMAKE_OSX_ARCHITECTURES=arm64"
  fi
fi

# This list contains all cores that will be built.
# If you are adding a new core or endianness add it here to have the correct tlib built
CORES=(arm.le arm.be arm64.le arm-m.le arm-m.be ppc.le ppc.be ppc64.le ppc64.be i386.le x86_64.le riscv.le riscv64.le sparc.le sparc.be xtensa.le)

# if '--tlib-arch' was used - pick the first matching one
if [[ ! -z $TLIB_ARCH ]]; then
  NONE_MATCHED=true
  for potential_match in "${CORES[@]}"; do
    if [[ $potential_match == "$TLIB_ARCH"* ]]; then
      CORES=($potential_match)
      echo "Compiling tlib for $potential_match"
      NONE_MATCHED=false
      break
    fi
  done
  if $NONE_MATCHED ; then
    echo "Failed to match any tlib arch"
    exit 1
  fi
fi

# build tlib
for core_config in "${CORES[@]}"
do
    CORE="$(echo $core_config | cut -d '.' -f 1)"
    ENDIAN="$(echo $core_config | cut -d '.' -f 2)"
    BITS=32
    # Check if core is 64-bit
    if [[ $CORE =~ "64" ]]; then
      BITS=64
    fi
    # Core specific flags to cmake
    CMAKE_CONF_FLAGS="-DTARGET_ARCH=$CORE -DTARGET_WORD_SIZE=$BITS -DCMAKE_BUILD_TYPE=$CONFIGURATION"
    CORE_DIR=$CORES_BUILD_PATH/$CORE/$ENDIAN
    mkdir -p $CORE_DIR
    pushd "$CORE_DIR" > /dev/null
    if [[ $ENDIAN == "be" ]]; then
        CMAKE_CONF_FLAGS+=" -DTARGET_BIG_ENDIAN=1"
    fi
    if [[ "$TLIB_EXPORT_COMPILE_COMMANDS" = true ]]; then
        CMAKE_CONF_FLAGS+=" -DCMAKE_EXPORT_COMPILE_COMMANDS=1"
    fi
    cmake "$CMAKE_GEN" $CMAKE_COMMON $CMAKE_CONF_FLAGS -DHOST_ARCH=$HOST_ARCH $CORES_PATH
    cmake --build . -j$(nproc)
    CORE_BIN_DIR=$CORES_BIN_PATH/lib
    mkdir -p $CORE_BIN_DIR
    if $ON_OSX; then
        # macos `cp` does not have the -u flag
        cp -v tlib/*.so $CORE_BIN_DIR/
    else
        cp -u -v tlib/*.so $CORE_BIN_DIR/
    fi
    # copy compile_commands.json to tlib directory
    if [[ "$TLIB_EXPORT_COMPILE_COMMANDS" = true ]]; then
       command cp -v -f $CORE_DIR/compile_commands.json $CORES_PATH/tlib/
    fi
    popd > /dev/null
done

if $TLIB_ONLY
then
    exit 0
fi

# build
eval "$CS_COMPILER $(build_args_helper "${PARAMS[@]}") $TARGET"
echo -n "$BUILD_TYPE" > "$BUILD_TYPE_FILE"

# copy llvm library
LLVM_LIB="libllvm-disas"
if [[ $HOST_ARCH == "aarch64" ]]; then
  # aarch64 host binaries have a different name
  LLVM_LIB="libllvm-disas-aarch64"
fi
if [[ "${DETECTED_OS}" == "windows" ]]; then
  LIB_EXT="dll"
elif [[ "${DETECTED_OS}" == "osx" ]]; then
  LIB_EXT="dylib"
else
  LIB_EXT="so"
fi
cp lib/resources/llvm/$LLVM_LIB.$LIB_EXT $OUT_BIN_DIR/libllvm-disas.$LIB_EXT

# build packages after successful compilation
params=""

if [ $CONFIGURATION == "Debug" ]
then
    params="$params -d"
fi

if [ -n "$EXPORT_DIRECTORY" ]
then
    if [ "${DETECTED_OS}" != "linux" ]
    then
        echo "Custom output directory is currently available on Linux only"
        exit 1
    fi

    $ROOT_PATH/tools/packaging/export_${DETECTED_OS}_workdir.sh $EXPORT_DIRECTORY $params
    echo "Renode built to $EXPORT_DIRECTORY"
fi

if $PACKAGES && $NIGHTLY
then
    params="$params -n"
fi

if $PACKAGES
then
    if $NET
    then
        # dotnet package on linux uses a separate script
        if $ON_LINUX
        then
            # maxcpucount:1 to avoid an error with multithreaded publish
            eval "dotnet publish -maxcpucount:1 -f $TFM --self-contained false $(build_args_helper "${PARAMS[@]}") $TARGET"
            export RID TFM
            $ROOT_PATH/tools/packaging/make_linux_dotnet_package.sh $params
            # Source package bundles nuget dependencies required for building the dotnet version of Renode
            # so it can only be built when using dotnet. The generated package can also be used with Mono/.NETFramework
            $ROOT_PATH/tools/packaging/make_source_package.sh $params
        elif $ON_WINDOWS && ! $PORTABLE
        then
            # No Non portable dotnet package on windows yet
            echo "Only portable dotnet packages are supported on windows. Rerun build.sh with -t flag to build portable"
            exit 1
        elif $ON_OSX
        then
            echo "dotnet packages not supported on ${DETECTED_OS}"
            exit 1
        fi
    else
        $ROOT_PATH/tools/packaging/make_${DETECTED_OS}_packages.sh $params
    fi
fi

if $PORTABLE
then
    PARAMS+=(p:PORTABLE=true)
    if $NET
    then
        # maxcpucount:1 to avoid an error with multithreaded publish
        eval "dotnet publish -maxcpucount:1 -r $RID -f $TFM --self-contained true $(build_args_helper "${PARAMS[@]}") $TARGET"
        export RID TFM
        $ROOT_PATH/tools/packaging/make_${DETECTED_OS}_portable_dotnet.sh $params
    else
        if $ON_LINUX
        then
            $ROOT_PATH/tools/packaging/make_linux_portable.sh $params
        else
            echo "Portable packages for Mono are only available on Linux. Exiting!"
            exit 1
        fi
    fi
fi
