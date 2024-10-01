@echo off

set SCRIPTDIR=%~dp0
set "BINDIR=%SCRIPTDIR%\..\output\bin\Release"
set "CONTEXT=package"

:args
if "%1" == "" goto args_done

if "%1" == "-d" (
    set "BINDIR=..\output\bin\Debug"
) else if "%1" == "--source" (
    set "CONTEXT=source"
)
shift
goto args
:args_done

if "%CONTEXT%" == "source" (
    py -3 "%SCRIPTDIR%\run_tests.py" --css-file "%SCRIPTDIR%\..\lib\resources\styles\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory  "%BINDIR%" -r %cd% %*
) else (
    py -3 "%SCRIPTDIR%\run_tests.py" --css-file "%SCRIPTDIR%\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory  "%SCRIPTDIR%\..\bin" -r %cd% %*
)
