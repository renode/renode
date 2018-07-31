UNAME=`uname -s`
if [ "$UNAME" == "Linux" ]
then
    DETECTED_OS="linux"
    ON_WINDOWS=false
    ON_OSX=false
    ON_LINUX=true
    CS_COMPILER=xbuild
    LAUNCHER="mono"
elif [ "$UNAME" == "Darwin" ]
then
    DETECTED_OS="osx"
    ON_WINDOWS=false
    ON_OSX=true
    ON_LINUX=false
    CS_COMPILER=xbuild
    LAUNCHER="mono64"
else
    DETECTED_OS="windows"
    ON_WINDOWS=true
    ON_OSX=false
    ON_LINUX=false
    CS_COMPILER=msbuild.exe
    LAUNCHER=""
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
