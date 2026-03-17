#!/usr/bin/env bash

set -u
set -e

USE_PARALLEL=false
if command -v env_parallel &> /dev/null
then
    # The env_parallel command stores ignored values in this variable
    # so it needs to be defined for the `set -u` flag to not error
    PARALLEL_IGNORED_NAMES=""
    # Source the env_parallel init script
    . env_parallel.bash
    # If the `--session` start fails it mean that the installed
    # version of GNU parallel is too old to have the features we need
    if env_parallel --session &> /dev/null
    then
        USE_PARALLEL=true
    fi
fi


ROOT_PATH="$(cd "$(dirname $0)"; echo $PWD)"
export ROOT_PATH
OUTPUT_DIRECTORY="$ROOT_PATH/output"

UPDATE_SUBMODULES=false
CONFIGURATION="Release"
BUILD_PLATFORM="Any CPU"
CLEAN=false
PACKAGES=false
NIGHTLY=false
PORTABLE=false
UI=false
SOURCE_PACKAGE=false
HEADLESS=false
SKIP_FETCH=false
EXTERNAL_LIB_ONLY=false
TLIB_EXPORT_COMPILE_COMMANDS=false
SHARED=false
EXTERNAL_LIB_ARCH=""
TFM="net8.0"
GENERATE_DOTNET_BUILD_TARGET=true
PARAMS=()
CUSTOM_PROP=
RID="linux-x64"
HOST_ARCH=
# Common cmake flags
CMAKE_COMMON="${RENODE_EXTRA_CMAKE_ARGS:-}"

function print_help() {
  echo "Usage: $0 [-cdvspnt] [-b properties-file.csproj] [--no-gui] [--skip-fetch] [--profile-build] [--external-lib-only] [--tlib-export-compile-commands] [--external-lib-arch <arch>] [--host-arch i386|aarch64] [--source-package] [--ui] [-- <ARGS>]"
  echo
  echo "-c                                clean instead of building"
  echo "-d                                build Debug configuration"
  echo "-v                                verbose output"
  echo "-p                                create packages after building"
  echo "-t                                create a portable package"
  echo "--source-package                  build a source package (dotnet on Linux only)"
  echo "-n                                tag built packages as nightly"
  echo "-s                                update submodules"
  echo "-b                                custom build properties file"
  echo "--skip-fetch                      skip fetching submodules and additional resources"
  echo "--no-gui                          build with GUI disabled"
  echo "-B                                bundle target runtime (default value: $RID, requires --net, -t)"
  echo "-F                                select the target framework for which Renode should be built (default value: $TFM)"
  echo "--profile-build                   build optimized for profiling"
  echo "--tlib-coverage                   build tlib with coverage reporting"
  echo "--external-lib-only               only build external libraries"
  echo "--external-lib-arch               build only single arch (implies --external-lib-only)"
  echo "--tlib-export-compile-commands    build tlibs with 'compile_commands.json' (requires --external-lib-arch)"
  echo "--host-arch                       build with a specific tcg host architecture (default: i386)"
  echo "--skip-dotnet-target-generation   don't generate 'Directory.Build.targets' file, useful when experimenting with different build settings"
  echo "--tcg-opcode-backtrace            collect a backtrace for each emitted TCG opcode, to track internal TCG errors (implies Debug configuration)"
  echo "--shared                          build the librenode native library"
  echo "--ui                              rebuild the web-based UI"
  echo "<ARGS>                            arguments to pass to the dotnet build system"
}

while getopts "cdvpnstb:B:F:-:" opt
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
    B)
      RID=$OPTARG
      ;;
    F)
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
        "net")
          echo "'--net' flag is a no-op and will be removed in the future" >&1
          ;;
        "source-package")
          SOURCE_PACKAGE=true
          ;;
        "profile-build")
          CMAKE_COMMON+=" -DPROFILING_BUILD=ON"
          ;;
        "external-lib-only")
          EXTERNAL_LIB_ONLY=true
          ;;
        "external-lib-arch")
          # This only makes sense with '--external-lib-only' set; it might as well imply it
          EXTERNAL_LIB_ONLY=true
          shift $((OPTIND-1))
          EXTERNAL_LIB_ARCH=$1
          OPTIND=2
          ;;
        "tlib-export-compile-commands")
          if [ -z $EXTERNAL_LIB_ARCH ]; then
              echo "--tlib-export-compile-commands requires --external-lib-arch being set"
              exit 1
          fi
          TLIB_EXPORT_COMPILE_COMMANDS=true
          ;;
        "tlib-coverage")
          CMAKE_COMMON+=" -DCOVERAGE_REPORTING=ON"
          ;;
        "host-arch")
          shift $((OPTIND-1))
          if [ $1 == "aarch64" ] || [ $1 == "arm64" ]; then
            HOST_ARCH="aarch64"
          elif [ $1 == "i386" ] || [ $1 == "x86" ] || [ $1 == "x86_64" ]; then
            HOST_ARCH="i386"
          else
            echo "host architecture $1 not supported. Supported architectures are i386 and aarch64"
            exit 1
          fi
          OPTIND=2
          ;;
        "skip-dotnet-target-generation")
          GENERATE_DOTNET_BUILD_TARGET=false
          ;;
        "tcg-opcode-backtrace")
          # Doesn't make sense without debug.
          CONFIGURATION="Debug"

          CMAKE_COMMON+=" -DTCG_OPCODE_BACKTRACE=ON"
          ;;
        "shared")
          SHARED=true
          ;;
        "ui")
          UI=true
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
else
    BUILD_TARGET=""
fi

if [[ -z "$HOST_ARCH" ]]; then
    HOST_ARCH="$DETECTED_ARCH"
fi

# Set correct RID
if $ON_LINUX; then
    RID="linux-x64"
    UI_RID="linux_x64"
    if [[ $HOST_ARCH == "aarch64" ]]; then
        RID="linux-arm64"
        UI_RID="linux_arm64"
    fi
elif $ON_OSX; then
    RID="osx-x64"
    UI_RID="mac_x64"
    if [[ $HOST_ARCH == "aarch64" ]]; then
        RID="osx-arm64"
        UI_RID="mac_arm64"
    fi
elif $ON_WINDOWS; then
    RID="win-x64"
    UI_RID="win_x64"
fi

if [[ $GENERATE_DOTNET_BUILD_TARGET = true ]]; then
  if $ON_WINDOWS; then
    # CsWinRTAotOptimizerEnabled is disabled due to a bug in dotnet-sdk.
    # See: https://github.com/dotnet/sdk/issues/44026
    OS_SPECIFIC_TARGET_OPTS='<CsWinRTAotOptimizerEnabled>false</CsWinRTAotOptimizerEnabled>'
  fi

  BUILD_TARGETS_FILE=$(mktemp)
  BUILD_TARGETS_PATH="$(get_path "$PWD/Directory.Build.targets")"
  cat <<EOF > "$BUILD_TARGETS_FILE"
<Project>
  <PropertyGroup>
    <TargetFrameworks>$TFM</TargetFrameworks>
    ${OS_SPECIFIC_TARGET_OPTS:+${OS_SPECIFIC_TARGET_OPTS}}
  </PropertyGroup>
</Project>
EOF

  if [ ! -f "$BUILD_TARGETS_PATH" ] || ! cmp -s "$BUILD_TARGETS_FILE" "$BUILD_TARGETS_PATH"; then
      mv "$BUILD_TARGETS_FILE" "$BUILD_TARGETS_PATH"
  else
      rm "$BUILD_TARGETS_FILE"
  fi
fi

export DOTNET_CLI_TELEMETRY_OPTOUT=1
TARGET="`get_path \"$PWD/Renode.sln\"`"
PARAMS+=(p:NET=true)

OUT_BIN_DIR="$(get_path "output/bin/${CONFIGURATION}")"

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

PROP_PATH="$OUTPUT_DIRECTORY/properties.csproj"
if [ ! -f "$PROP_PATH" ] || ! cmp -s "$PROP_FILE" "$PROP_PATH"; then
    cp "$PROP_FILE" "$PROP_PATH"
fi

CORES_PATH="$ROOT_PATH/src/Infrastructure/src/Emulator/Cores"
UI_PATH="$ROOT_PATH/src/UI"

# clean instead of building
if $CLEAN
then
  remove_dir() {
    output_dir="$(get_path "$1")"
    if [[ -d "${output_dir}" ]]
    then
      echo "Removing: ${output_dir}"
      rm -rf "${output_dir}"
    fi
  }
  for project_dir in $(find "$(get_path "${ROOT_PATH}/src")" -iname '*.csproj' -exec dirname '{}' \;)
  do
    for dir in {bin,obj}/{Debug,Release}
    do
      remove_dir "${project_dir}/${dir}"
    done
  done

  # Manually clean the main output directories as it's location is non-standard
  remove_dir "${OUTPUT_DIRECTORY}/bin"
  exit 0
fi

# check weak implementations of core libraries
pushd "$ROOT_PATH/tools/building" > /dev/null
./check_weak_implementations.sh
popd > /dev/null

PARAMS+=(p:Configuration="${CONFIGURATION}${BUILD_TARGET}" p:GenerateFullPaths=true p:Platform="\"$BUILD_PLATFORM\"" p:Architecture="$HOST_ARCH")

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

# if '--external-lib-arch' was used - pick the first matching one
if [[ ! -z $EXTERNAL_LIB_ARCH ]]; then
  NONE_MATCHED=true
  for potential_match in "${CORES[@]}"; do
    if [[ $potential_match == "$EXTERNAL_LIB_ARCH"* ]]; then
      CORES=("$potential_match")
      echo "Compiling external lib for $potential_match"
      NONE_MATCHED=false
      break
    fi
  done
  if $NONE_MATCHED ; then
    echo "Failed to match any external lib arch"
    exit 1
  fi
fi

# build KVM - currently it's supported only on Linux
if $ON_LINUX && [[ "$HOST_ARCH" == "i386" ]] && [[ -z $EXTERNAL_LIB_ARCH || "${CORES[@]}" == "i386kvm.le" ]]; then
    KVM_CORE_DIR="$CORES_BUILD_PATH/virt"
    mkdir -p $KVM_CORE_DIR
    pushd "$KVM_CORE_DIR" > /dev/null
    cmake "$CORES_PATH/virt"
    cmake --build . -j$(nproc)
    CORE_BIN_DIR=$CORES_BIN_PATH/lib
    mkdir -p $CORE_BIN_DIR
    cp -u -v *.so $CORE_BIN_DIR/
    popd > /dev/null
fi

build_core () {
    set -e
    core_config=$1
    if [[ $core_config == *"kvm"* ]]; then
        continue
    fi

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
        CMAKE_CONF_FLAGS+=" -DTARGET_WORDS_BIGENDIAN=1"
    fi
    if [[ "$TLIB_EXPORT_COMPILE_COMMANDS" = true ]]; then
        CMAKE_CONF_FLAGS+=" -DCMAKE_EXPORT_COMPILE_COMMANDS=1"
    fi
    cmake "$CMAKE_GEN" $CMAKE_COMMON $CMAKE_CONF_FLAGS -DHOST_ARCH=$HOST_ARCH $CORES_PATH
    cmake --build . -j"$(nproc)"
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
}

# build tlib
if $USE_PARALLEL
then
    echo "Starting parallel tlib build"
    env_parallel build_core ::: "${CORES[@]}"
    env_parallel --end-session
else
    for core_config in "${CORES[@]}"
    do
        build_core $core_config
    done
fi

if $EXTERNAL_LIB_ONLY
then
    exit 0
fi

# build
dotnet build "${PARAMS[@]/#/-}" $TARGET

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

# on arm64 macOS System.Drawing.Common can't find libgdiplus so we symlink it to the output directory
# this is only used for `FrameBufferTester`
if [[ $RID == "osx-arm64" ]]; then
  GDIPLUS_PATH="/opt/homebrew/lib/libgdiplus.dylib"
  if [ -e $GDIPLUS_PATH ]; then
    # For some reason System.Drawing.Common does not search the binary root when running from a source build
    # but does for a package, so just link it to both locations so the packaging scripts do not have to be updated
    mkdir -p $OUT_BIN_DIR/runtimes/unix/lib/netcoreapp3.0
    ln -s -f $GDIPLUS_PATH $OUT_BIN_DIR/runtimes/unix/lib/netcoreapp3.0/libgdiplus.dylib
    mkdir -p $OUT_BIN_DIR/unix/lib/netcoreapp3.0/
    ln -s -f $GDIPLUS_PATH $OUT_BIN_DIR/unix/lib/netcoreapp3.0/libgdiplus.dylib
  else
    echo "libgdiplus.dylib not found by build.sh, FrameBufferTester might not work"
  fi
fi

BIN_EXT=""
if [[ "$DETECTED_OS" == "windows" ]]; then
  BIN_EXT=".exe"
fi

UI_BIN="$OUT_BIN_DIR/renode-ui$BIN_EXT"

# `UI_BIN`'s base goes through `cygwin -aw` on Windows, so it's already absolute
# The path starts with a drive letter on Windows, so we have to special-case it
if [[ "$UI_BIN" != "/"* ]] && ! $ON_WINDOWS; then
  UI_BIN="$PWD/$UI_BIN"
fi

if $UI; then
  NO_COLOR=true "$UI_PATH/scripts/build_neutralino.sh"
  cp "$UI_PATH/neutralino/dist/renode-ui/renode-ui-$UI_RID$BIN_EXT" "$UI_BIN"
fi

if $SHARED
then
    if ! $ON_WINDOWS
    then
        echo "Building librenode..."
        eval "dotnet build '$(get_path "$ROOT_PATH/tools/NativeInterface/csharp/NativeInterface.csproj")' -c '$CONFIGURATION' -p:RenodeOutputDir='$(get_path "$ROOT_PATH/$OUT_BIN_DIR")'"
    else
        echo "librenode (--shared) can only be built on Linux or macOS. Exiting!"
        exit 1
    fi
fi

# build packages after successful compilation
params=""

if [ $CONFIGURATION == "Debug" ]
then
    params="$params -d"
fi

if $NIGHTLY
then
    params="$params -n"
fi

if $SOURCE_PACKAGE
then
    if $ON_LINUX
    then
        # Source package bundles nuget dependencies required for building Renode
        # Source packages are best built first, so it does not have to copy and then delete the packages from the `output` directory
        $ROOT_PATH/tools/packaging/make_source_package.sh $params
    else
        echo "Source package can only be built on Linux. Exiting!"
        exit 1
    fi
fi

if $PACKAGES
then
    export UI_BIN
    if $ON_LINUX
    then
        # maxcpucount:1 to avoid an error with multithreaded publish
        dotnet publish -maxcpucount:1 -f $TFM --self-contained false "${PARAMS[@]/#/-}" $TARGET
        export RID TFM
        $ROOT_PATH/tools/packaging/make_linux_package.sh $params
    elif $ON_WINDOWS
    then
        # No Non portable dotnet package on windows yet
        echo "Only portable dotnet packages are supported on windows. Rerun build.sh with -t flag to build portable"
        exit 1
    elif $ON_OSX
    then
        # No Non portable dotnet package on macOS
        echo "Only portable dotnet packages are supported on macOS. Rerun build.sh with -t flag to build portable"
        exit 1
    fi
fi

if $PORTABLE
then
    export UI_BIN
    PARAMS+=(p:PORTABLE=true)
    # maxcpucount:1 to avoid an error with multithreaded publish
    echo "RID = $RID"
    dotnet publish -maxcpucount:1 -r $RID -f $TFM --self-contained true "${PARAMS[@]/#/-}" $TARGET
    export RID TFM
    $ROOT_PATH/tools/packaging/make_${DETECTED_OS}_portable.sh $params
fi

