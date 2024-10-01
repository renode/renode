@echo off
set SCRIPTDIR=%~dp0
set "BINDIR=%SCRIPTDIR%..\output\bin\Release"
if "%DEBUG%" == "1" (
    set "BINDIR=%SCRIPTDIR%..\output\bin\Debug"
)

if "%CONTEXT%" == "source" (
    py -3 "%SCRIPTDIR%\run_tests.py" --css-file "%SCRIPTDIR%\..\lib\resources\styles\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory "%BINDIR%" -r %cd% %*
) else (
    py -3 "%SCRIPTDIR%\run_tests.py" --css-file "%SCRIPTDIR%\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory "%SCRIPTDIR%\..\bin" -r %cd% %*
)
