@echo off
set SCRIPTDIR=%~dp0
if "%CONTEXT%" == "" (
    set "CONTEXT=package"
)

if "%CONTEXT%" == "source" (
    set "BINDIR=%SCRIPTDIR%\..\output\bin\Release"
    if "%DEBUG%" == "1" (
        set "BINDIR=..\output\bin\Debug"
    )

    py -3 "%SCRIPTDIR%\run_tests.py" --css-file "%SCRIPTDIR%\..\lib\resources\styles\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory  "%BINDIR%" -r %cd% %*
) else (
    py -3 "%SCRIPTDIR%\run_tests.py" --css-file "%SCRIPTDIR%\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory  "%SCRIPTDIR%\..\bin" -r %cd% %*
)
