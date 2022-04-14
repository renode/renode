# For Bash on Windows (Cygwin / git bash / MSYS2).
RENODE_BIN_DIR="$(cygpath.exe $CONDA_PREFIX)/Library/renode/exec"
export PATH=$(python -c "print(\"$PATH\".replace(\"$RENODE_BIN_DIR\" + ':',''))")
