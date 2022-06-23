#!/usr/bin/env bash

set -ex


# MANUAL ADJUSTMENTS

# This variable will be used for testing if the target directory contains all the necessary licenses.
# The name of every 'lib/*' directory (except 'resources'), 'lib/resources/libraries/*' file
#   (except '*-license') and proper OS-specific licenses are added automatically.
REQUIRED_LICENSES=(
    libllvm-disas
    llvm
    nunit3
    renode
    RobotoMono-Regular
    socket-cpp
    tcg
    tlib
)

# Licenses for these directories and files won't be required.
REQUIRED_LICENSES_EXCLUDE=(
    # CCTask is only used during building.
    cctask

    # There is 'IronPython-license' for 'IronPython.dll'. That's enough.
    IronPython.Modules.dll
    IronPython.StdLib.dll

    # License is named 'libopenlibm-license' and is only required on Linux.
    libopenlibm-Linux.a

    # There is 'Sprache-license' for 'Sprache.dll'.
    Sprache.xml
)

# Custom names for the 'license*' files. It should be an associative array but macOSs use bash3...
CUSTOM_TARGET_NAME_KEYS=(
    lib/bc-csharp/crypto/License.html
    LICENSE
)
CUSTOM_TARGET_NAME_VALUES=(
    bc-csharp
    renode
)

# Use target names without the '-license' suffix, e.g., 'renode' instead of 'LICENSE'. The OSs order
#   has to be synced with the 'get_os_specific_licenses' function.
OS_SPECIFIC_LICENSES=(
    "libopenlibm"  # Linux
    "macos_run.command"  # macOS
    "mingw winpthreads"  # Windows
)


# HELPERS

function exit_invalid_args {
    exit_with_error \
      "Invalid arguments: $@" \
      "" \
      "Usage: $(basename $0) <DESTINATION_DIR> <linux/macos/windows>"
}

function exit_with_error {
    set +x
    echo "ERROR: License copying failed!"
    echo
    for message in "$@"; do
        echo $message
    done
    exit 1
}

function get_custom_target_name {
    path=$1
    i=0
    for key in ${CUSTOM_TARGET_NAME_KEYS[@]}; do
        if [ "$key" = "$path" ]; then
            echo "${CUSTOM_TARGET_NAME_VALUES[$i]}"
            return
        fi
        let i++
    done
}

function get_os_specific_licenses {
    if [ "$OS" = linux ]; then
        index=0
    elif [ "$OS" = macos ]; then
        index=1
    elif [ "$OS" = windows ]; then
        index=2
    fi
    echo "${OS_SPECIFIC_LICENSES[$index]}"
}


# CHECK ARGUMENTS

if [ $# -ne 2 ]; then
    exit_invalid_args $@
fi

BASE="$(dirname $0)/../.."
TARGET="$1"
OS="$2"

if [ "$OS" != linux ] && [ "$OS" != macos ] && [ "$OS" != windows ]; then
    exit_invalid_args $@
fi

_resources_dir="lib/resources/libraries"
if ! [ -d $BASE/$_resources_dir ]; then
    exit_with_error "No such directory: '$BASE/$_resources_dir'. Fetch 'renode-resources' first."
fi


# COPY LICENSES

function is_license_skipped {
    # Extract the license name core if the argument is a full path.
    filename=${1##*/}
    name_core=${filename%-licen*}

    # The extra spaces are necessary to only have exact matches.
    if [[ " ${OS_SPECIFIC_LICENSES[@]} " =~ " $name_core " ]]; then
        if [[ " $(get_os_specific_licenses) " =~ " $name_core " ]]; then
            return 1  # Don't skip.
        else
            return 0  # Skip.
        fi
    else
        return 1  # Don't skip.
    fi
}

# Copy licenses which include the library name. LicenCe is a correct spelling as well (BrE).
for license in $(find $BASE -type f -iname "*-licen[cs]e"); do
    if ! is_license_skipped $license; then
        cp $license $TARGET/
    fi
done

# Copy other licenses as '<parent-directory-name>-license' (see CUSTOM_TARGET_NAME* for exceptions).
# The pattern isn't a simple '-iname "licen[cs]e*"' to prevent matching many potential non-license
#   files, e.g., "license-script.sh".
for license in $(find $BASE -type f \( -iname "licen[cs]e" -or -iname "licen[cs]e.*" \)); do
    base_relative_path=${license#$BASE/}
    custom_name="$(get_custom_target_name $base_relative_path)"
    if [ -n "$custom_name" ]; then
        name="$custom_name"
    else
        full_dirname=${license%/*}
        parent_dirname=${full_dirname##*/}
        name=$parent_dirname
    fi

    if ! is_license_skipped $name; then
        cp $license $TARGET/$name-license
    fi
done

set +x


# LIST TARGET DIRECTORY

LICENSE_COUNT=$(ls $TARGET/*-license | wc -w)
echo
echo "The target directory for licenses ($TARGET) contains $LICENSE_COUNT license files:"
ls $TARGET
echo


# TEST

# There should be a license for every directory from 'lib' except 'resources' and for every file
#   from 'lib/resources/libraries' except the '*-license' files.
for name in $(ls $BASE/lib) $(ls $BASE/lib/resources/libraries/); do
    if [ "$name" != "resources" ] && ! [[ "$name" =~ "-license" ]]; then
        REQUIRED_LICENSES+=( $name )
    fi
done

# Don't use double quotes for the '$(get_os_specific_licenses)'. The value can contain multiple
#   names separated with spaces which should be checked separately.
for name in ${REQUIRED_LICENSES[@]} $(get_os_specific_licenses); do
    # Check if the license isn't excluded.
    if [[ " ${REQUIRED_LICENSES_EXCLUDE[@]} " =~ " $name " ]]; then
        continue
    fi

    # Strip possible '.a' and '.dll' extensions and add the '-license' suffix.
    license=${name%.a}
    license=${license%.dll}
    license="$license-license"
    if ! [ -f "$TARGET/$license" ]; then
        exit_with_error "Required file not found: '$license'. Provide it or exclude '$name'."
    fi
done
