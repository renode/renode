@echo off
set "test_script=%~dp0%tests\test.bat --source"
call "%test_script%" %*
