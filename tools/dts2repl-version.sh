#!/usr/bin/env bash

# Get absolute path of Renode directory.
#
# To make it run from any place in the system (possibly different git repository)
# we have to get full path of the script and then find the git repository that
# contains it (it will be the Renode repository).
RENODE_DIR="$(cd $(dirname $(realpath $0)); git rev-parse --show-toplevel)"

# Read dts2repl commit cached in the Renode repository
#
# NOTE: The output of the 'git submodule status' command is:
#       " a53f2f01039a462bdd7322d1fb315edd95033b6d tools/dts2repl (heads/main)"
#       We are looking for the commit SHA-1 (40 hexadecimal digits) followed
#       by the "tools/dts2repl" string.
#       It could be done in a single grep command:
#         grep -oP "[a-f0-9]{40}(?=\s+tools/dts2repl)")
#       however, the -P option isn't available on all supported platforms, so
#       it has to be split into two separate commands.
DTS2REPL_VERSION=$( \
  cd $RENODE_DIR; \
  git submodule status --cached tools/dts2repl | \
  grep -Eo "[a-f0-9]{40}\s+tools/dts2repl" | \
  grep -Eo "[a-f0-9]{40}" \
)

if [ $? -ne 0 ] ; then
  echo "Failed to determine dts2repl version."
  exit 1
fi

# In packages the DTS2REPL_VERSION variable will be set to specific dts2repl version.
# The bottom part of this script will be copied directly to the package, but the
# upper part will contain a single line:
#   DTS2REPL_VERSION=<commit-sha>
#
# To make it easy to cut the head of this script we leave the marker here:
# END OF VERSION CHECK

case $1 in
  "--commit"|"")
    echo "$DTS2REPL_VERSION"
    ;;

  "--url")
    echo "https://github.com/antmicro/dts2repl/tree/$DTS2REPL_VERSION"
    ;;

  "--pip"|"--pipx")
    echo "git+https://github.com/antmicro/dts2repl@$DTS2REPL_VERSION"
    ;;

  "--help"|"-h")
    echo "usage: $(basename $0) [-h] [--commit] [--pip] [--pipx] [--url]"
    echo ""
    echo "Display version of dts2repl supported by this version of Renode in specified format."
    echo ""
    echo "options:"
    echo "  --commit        git commit SHA (default)"
    echo "  --pip           url that can be passed to pip to install dts2repl"
    echo "  --pipx          url that can be passed to pipx to install dts2repl"
    echo "  --url           url to the specific commit on GitHub"
    echo "  -h, --help      show this help message and exit"
    ;;

  *)
    >&2 echo "Unrecognized argument '$1'"
    exit 1
    ;;
esac
