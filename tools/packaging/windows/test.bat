@echo off
set "SCRIPTDIR=%~dp0"
set "BINDIR=%SCRIPTDIR%REPLACE_BIN_DIR"

set "CWD=%cd%"
if "%CWD:~-1%"=="\" set "CWD=%CWD%."

REM The user is responsible for preaparing an appropriate runtime environment.
python "%SCRIPTDIR%run_tests.py" --css-file "%SCRIPTDIR%robot.css" --exclude "skip_windows" --exclude "skip_portable" --robot-framework-remote-server-full-directory "%BINDIR%" --robot-framework-remote-server-name=REPLACE_BIN_NAME -r "%CWD%" %*
