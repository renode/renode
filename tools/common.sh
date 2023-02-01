UNAME=`uname -s`
if [ "$UNAME" == "Linux" ]
then
    DETECTED_OS="linux"
    ON_WINDOWS=false
    ON_OSX=false
    ON_LINUX=true
    CS_COMPILER=xbuild
    LAUNCHER="mono"
    PYTHON_RUNNER="python3"
elif [ "$UNAME" == "Darwin" ]
then
    DETECTED_OS="osx"
    ON_WINDOWS=false
    ON_OSX=true
    ON_LINUX=false
    CS_COMPILER=xbuild
    LAUNCHER="mono64"
    PYTHON_RUNNER="python3"
else
    DETECTED_OS="windows"
    ON_WINDOWS=true
    ON_OSX=false
    ON_LINUX=false
    CS_COMPILER=MSBuild.exe
    LAUNCHER=""
    PYTHON_RUNNER="py -3"
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

function get_min_mono_version {
    cat $ROOT_PATH/tools/mono_version
}

function verify_mono_version {
    MINIMUM_MONO=`get_min_mono_version`
    if ! [ -x "$(command -v $LAUNCHER)" ]
    then
        echo "$LAUNCHER not found. Renode requires Mono $MINIMUM_MONO or newer. Please refer to documentation for installation instructions. Exiting!"
        exit 1
    fi

    # Check mono version
    MINIMUM_MONO_MAJOR=`echo $MINIMUM_MONO | cut -d'.' -f1`
    MINIMUM_MONO_MINOR=`echo $MINIMUM_MONO | cut -d'.' -f2`

    INSTALLED_MONO=`$LAUNCHER --version | head -n1 | cut -d' ' -f5`
    INSTALLED_MONO_MAJOR=`echo $INSTALLED_MONO | cut -d'.' -f1`
    INSTALLED_MONO_MINOR=`echo $INSTALLED_MONO | cut -d'.' -f2`

    if [ $INSTALLED_MONO_MAJOR -lt $MINIMUM_MONO_MAJOR ] || [ $INSTALLED_MONO_MAJOR -eq $MINIMUM_MONO_MAJOR -a $INSTALLED_MONO_MINOR -lt $MINIMUM_MONO_MINOR ]
    then
        echo "Wrong Mono version detected: $INSTALLED_MONO. Renode requires Mono $MINIMUM_MONO or newer. Please refer to documentation for installation instructions. Exiting!"
        exit 1
    fi
}

# NOTE: if we switch to using msbuild on all platforms, we can get rid of this function and only use the '-' prefix
function build_args_helper() {
    local retStr=""
    for p in "$@" ; do
        if [ "$CS_COMPILER" = 'xbuild' ] ; then
            retStr="${retStr} /$p"
        else
            retStr="${retStr} -$p"
        fi
    done
    echo ${retStr}
}
