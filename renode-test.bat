@echo off
REM We change the below line to "set CONTEXT=package" during package generation
set "CONTEXT=source"
set "test_script=%~dp0%tests\test.bat"
if "%CONTEXT%" == "package" (
    set "test_script=%~dp0%..\tests\test.bat"
)

:args
if "%1" == "" goto args_end
if "%1" == "-d" (
    set "DEBUG=1"
)
shift
goto args
:args_end

call "%test_script%" %*
