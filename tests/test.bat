@echo off
set SCRIPTDIR=%~dp0
py -3 "%SCRIPTDIR%\run_tests.py" --css-file "%SCRIPTDIR%\robot.css" --exclude "skip_windows" --robot-framework-remote-server-full-directory  "%SCRIPTDIR%\..\bin" -r %cd% %*
