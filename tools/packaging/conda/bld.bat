setlocal EnableDelayedExpansion
set PATH=C:\cygwin64\bin\;%PATH%
set PLATFORM=Any CPU
for /r %%i in (*.sh) do  CALL :convert_to_unix_newline %%i

call bash -lc build.sh
if %errorlevel% neq 0 exit /b %errorlevel%

REM Need to use call for all functions outside of script, otherwise label handling go crazy
call mkdir %LIBRARY_PREFIX%\renode\exec
call mkdir %LIBRARY_PREFIX%\renode\tests
call mkdir %LIBRARY_PREFIX%\renode\scripts
call mkdir %LIBRARY_PREFIX%\renode\platforms
call mkdir %LIBRARY_PREFIX%\renode\licenses
call robocopy output\bin\Release\ %LIBRARY_PREFIX%\renode\exec\ /njh /njs /ndl /S
call robocopy tests\ %LIBRARY_PREFIX%\renode\tests /njh /njs /ndl /S
call robocopy scripts\ %LIBRARY_PREFIX%\renode\scripts /njh /njs /ndl /S
call robocopy platforms\ %LIBRARY_PREFIX%\renode\platforms /njh /njs /ndl /S
call robocopy .\ %LIBRARY_PREFIX%\renode\ .renode-root
call robocopy .\ %LIBRARY_PREFIX%\renode\ LICENSE

REM Copy all licenses. LIBRARY_PREFIX has to be converted to the Unix format first.
FOR /F "delims=" %%i IN ('cygpath.exe -u "%LIBRARY_PREFIX%"') DO set "UNIX_LIBRARY_PREFIX=%%i"
call bash -lc "tools/packaging/common_copy_licenses.sh $UNIX_LIBRARY_PREFIX/renode/licenses windows"
if %errorlevel% neq 0 exit /b %errorlevel%


REM Add activation script to append renode dir to PATH
if not exist %PREFIX%\etc\conda\activate.d call mkdir %PREFIX%\etc\conda\activate.d
call copy %RECIPE_DIR%\activate.bat %PREFIX%\etc\conda\activate.d\%PKG_NAME%_activate.bat
call copy %RECIPE_DIR%\activate-win.sh %PREFIX%\etc\conda\activate.d\%PKG_NAME%_activate.sh

if not exist %PREFIX%\etc\conda\deactivate.d call mkdir %PREFIX%\etc\conda\deactivate.d
call copy %RECIPE_DIR%\deactivate-win.sh %PREFIX%\etc\conda\deactivate.d\%PKG_NAME%_deactivate.sh

REM PS1 scripts can't modify PATH so put a PowerShell script running Renode in PATH.
if not exist %PREFIX%\Library\bin call mkdir %PREFIX%\Library\bin
call copy %RECIPE_DIR%\Renode.ps1 %PREFIX%\Library\bin\Renode.ps1

EXIT /B 0

:convert_to_unix_newline
powershell -Command "(Get-Content %~1 -Raw).Replace(\"`r\",\"\") |Set-Content -NoNewLine %~1 -Force"
EXIT /B 0

