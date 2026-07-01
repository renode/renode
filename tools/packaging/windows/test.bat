@echo off
set "SCRIPTDIR=%~dp0"
set "BINDIR=%SCRIPTDIR%REPLACE_BIN_DIR"

set "CWD=%cd%"
if "%CWD:~-1%"=="\" set "CWD=%CWD%."

where py >nul 2>&1
if "%ERRORLEVEL%" == "0" (
    REM Before Python3.14 'py' standed for "Python launcher for Windows", which expects 'PY_PYTHON'.
    REM For Python3.14 and later 'py' stands for "Python install manager", which expects 'PYTHON_MANAGER_DEFAULT'.
    set "PYTHON_MANAGER_DEFAULT=3"
    set "PY_PYTHON=3"

    py "%SCRIPTDIR%run_tests.py" --css-file "%SCRIPTDIR%robot.css" --exclude "skip_windows" --exclude "skip_portable" --robot-framework-remote-server-full-directory "%BINDIR%" --robot-framework-remote-server-name=REPLACE_BIN_NAME -r "%CWD%" %*
) else (
    python3 "%SCRIPTDIR%run_tests.py" --css-file "%SCRIPTDIR%robot.css" --exclude "skip_windows" --exclude "skip_portable" --robot-framework-remote-server-full-directory "%BINDIR%" --robot-framework-remote-server-name=REPLACE_BIN_NAME -r "%CWD%" %*
)
