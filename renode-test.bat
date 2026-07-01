@echo off
set "SCRIPTDIR=%~dp0"

:args
if "%1" == "" goto args_end
if "%1" == "-d" (
    set "DEBUG=1"
)
shift
goto args
:args_end

set "CWD=%cd%"
if "%CWD:~-1%"=="\" set "CWD=%CWD%."

set "BINDIR=%SCRIPTDIR%\output\bin\Release"
if "%DEBUG%" == "1" (
    set "BINDIR=%SCRIPTDIR%\output\bin\Debug"
)

where py >nul 2>&1
if "%ERRORLEVEL%" == "0" (
    REM Before Python3.14 'py' standed for "Python launcher for Windows", which expects 'PY_PYTHON'.
    REM For Python3.14 and later 'py' stands for "Python install manager", which expects 'PYTHON_MANAGER_DEFAULT'.
    set "PYTHON_MANAGER_DEFAULT=3"
    set "PY_PYTHON=3"
    
    py "%SCRIPTDIR%\tests\run_tests.py" --css-file "%SCRIPTDIR%\lib\resources\styles\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory "%BINDIR%" -r "%CWD%" %*
) else (
    python3 "%SCRIPTDIR%\tests\run_tests.py" --css-file "%SCRIPTDIR%\lib\resources\styles\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory "%BINDIR%" -r "%CWD%" %*
)
