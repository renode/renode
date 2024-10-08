@echo off
REM We change the below line to "set CONTEXT=package" during package generation
set "CONTEXT=source"
set "SCRIPTDIR=%~dp0"

:args
if "%1" == "" goto args_end
if "%1" == "-d" (
    set "DEBUG=1"
)
shift
goto args
:args_end

set "BINDIR=%SCRIPTDIR%\output\bin\Release"
if "%DEBUG%" == "1" (
    set "BINDIR=%SCRIPTDIR%\output\bin\Debug"
)

if "%CONTEXT%" == "source" (
    py -3 "%SCRIPTDIR%\tests\run_tests.py" --css-file "%SCRIPTDIR%\lib\resources\styles\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory "%BINDIR%" -r %cd% %*
) else (
    py -3 "%SCRIPTDIR%\..\tests\run_tests.py" --css-file "%SCRIPTDIR%\..\tests\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory "%SCRIPTDIR%\" -r "%cd%" %*
)
