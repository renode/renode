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

REM The user is responsible for preaparing an appropriate runtime environment.
python "%SCRIPTDIR%\tests\run_tests.py" --css-file "%SCRIPTDIR%\lib\resources\styles\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory "%BINDIR%" -r "%CWD%" %*
