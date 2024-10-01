@echo off
:args
if "%1" == "" goto args_end
if "%1" == "-d" (
    set "DEBUG=1"
)
shift
goto args
:args_end

set "CONTEXT=source"
set "test_script=%~dp0%tests\test.bat"
call "%test_script%" %*
