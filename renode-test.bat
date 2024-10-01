@echo off
set "test_script=%~dp0%tests\test.bat"
call "%test_script%" --source %*
