UNAME=`uname -s`
if [ "$UNAME" == "Linux" ]
then
    DETECTED_OS="linux"
    ON_WINDOWS=false
    ON_OSX=false
    ON_LINUX=true
    PYTHON_RUNNER="python3"
elif [ "$UNAME" == "Darwin" ]
then
    DETECTED_OS="osx"
    ON_WINDOWS=false
    ON_OSX=true
    ON_LINUX=false
    PYTHON_RUNNER="python3"
else
    DETECTED_OS="windows"
    ON_WINDOWS=true
    ON_OSX=false
    ON_LINUX=false
    PYTHON_RUNNER="py -3"
fi

ARCH_UNAME=`uname -m`
# macOS and Linux uses different names for 64-bit Arm
if [ "$ARCH_UNAME" == "aarch64" ] || [ "$ARCH_UNAME" == "arm64" ]
then
    DETECTED_ARCH="aarch64"
else
    DETECTED_ARCH="i386"
fi
function get_path {
    if $ON_WINDOWS
    then
        var="`cygpath -aw "$1"`"
        echo -n ${var//\\/\\\\}
    else
        echo -n "$1"
    fi
}

function clone_if_necessary() {
    NAME="$1"
    REMOTE="$2"
    BRANCH="$3"
    TARGET_DIR="$4"
    GUARD="$5"
   
    if [ -e "$GUARD" ]
    then
        top_ref=`git ls-remote -h $REMOTE $BRANCH 2>/dev/null | cut -f1`
        if [ "$top_ref" == "" ]
        then
            echo "Could not access remote $REMOTE. Continuing without verification of the state of $NAME ."
            exit
        fi
        pushd "$TARGET_DIR" >/dev/null
        cur_ref=`git rev-parse HEAD`
        master_ref=`git rev-parse $BRANCH`
        if [ $master_ref != $cur_ref ]
        then
            echo "The $NAME repository is not on the local $BRANCH branch. This situation should be handled manually."
            exit
        fi
        popd >/dev/null
        if [ $top_ref == $cur_ref ]
        then
            echo "Required $NAME repository already downloaded. To repeat the process remove $GUARD file."
            exit
        fi
        echo "Required $NAME repository is available in a new version. It will be redownloaded..."
    fi

    rm -rf "$TARGET_DIR"
    git clone --depth=1 --single-branch --branch=$BRANCH $REMOTE $(get_path "$TARGET_DIR")
}

function add_path_property {
    sanitized_path=$(sed 's:\\:/:g' <<< `get_path "$3"`)
    sed -i.bak "s#</PropertyGroup>#  <$2>$sanitized_path</$2>"'\
</PropertyGroup>#' "$1"
}
