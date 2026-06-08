@echo off
set "SCRIPTDIR=%~dp0"
set "BINDIR=%SCRIPTDIR%REPLACE_BIN_DIR"
py -3 "%SCRIPTDIR%run_tests.py" --css-file "%SCRIPTDIR%robot.css" --exclude "skip_windows" --exclude "skip_portable" --robot-framework-remote-server-full-directory "%BINDIR%" --robot-framework-remote-server-name=REPLACE_BIN_NAME -r "%cd%" %*
