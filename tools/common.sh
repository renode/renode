UNAME=`uname -s`
if [ "$UNAME" == "Linux" ]
then
    DETECTED_OS="linux"
    ON_WINDOWS=false
    ON_OSX=false
    ON_LINUX=true
    CS_COMPILER=xbuild
    LAUNCHER="mono"
    PYTHON_RUNNER="python2"
elif [ "$UNAME" == "Darwin" ]
then
    DETECTED_OS="osx"
    ON_WINDOWS=false
    ON_OSX=true
    ON_LINUX=false
    CS_COMPILER=xbuild
    LAUNCHER="mono64"
    PYTHON_RUNNER="python2"
else
    DETECTED_OS="windows"
    ON_WINDOWS=true
    ON_OSX=false
    ON_LINUX=false
    CS_COMPILER=msbuild.exe
    LAUNCHER=""
    PYTHON_RUNNER="python"
fi

function get_path {
    if $ON_WINDOWS
    then
        echo -n "`cygpath -aw "$1"`"
    else
        echo -n "$1"
    fi
}

# $1 = Renode
# $2 = $REMOTE
# $3 = $LIBRARIES_DIR
# $4 = $GUARD
# $5 = $PWD
function clone_if_necessary() {
    if [ -e "$4" ]
    then
        top_ref=`git ls-remote -h $2 master 2>/dev/null | cut -f1`
        if [ "$top_ref" == "" ]
        then
            echo "Could not access remote $2. Continuing without verification of required libraries."
            exit
        fi
        pushd "$3" >/dev/null
        cur_ref=`git rev-parse HEAD`
        master_ref=`git rev-parse master`
        if [ $master_ref != $cur_ref ]
        then
            echo "The $1 libraries repository is not on the local master branch. This situation should be handled manually."
            exit
        fi
        popd >/dev/null
        if [ $top_ref == $cur_ref ]
        then
            echo "Required $1 libraries already downloaded. To repeat the process remove $4 file."
            exit
        fi
        echo "Required $1 libraries are available in a new version. The libraries will be redownloaded..."
    fi

    rm -rf "$3"
    git clone $2 "`realpath --relative-to="$5" "$3"`"
}

function add_path_property {
    sanitized_path=$(sed 's:\\:/:g' <<< `get_path "$3"`)
    sed -i.bak "s#</PropertyGroup>#  <$2>$sanitized_path</$2>"'\
</PropertyGroup>#' "$1"
}

function verify_mono_version {
    MINIMUM_MONO=`cat $ROOT_PATH/tools/mono_version`

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
